// Production FFI adapter connecting FlurryToDeskMouseCore to RustDesk's
// CursorModel, InputModel, and VirtualMouseMode across both Mouse Mode and Touch Mode.

import 'package:flutter/material.dart';
import 'package:flutter_hbb/mobile/flurry/flurry_todesk_mouse_core.dart';
import 'package:flutter_hbb/models/input_model.dart';
import 'package:flutter_hbb/models/model.dart';

class FloatingMouse extends StatefulWidget {
  final FFI? ffi;
  final Function(int dx, int dy)? onTrackpadMove;
  final Function(MouseButtons button, bool down)? onButtonAction;
  final Function(int delta)? onScrollAction;

  const FloatingMouse({
    super.key,
    this.ffi,
    this.onTrackpadMove,
    this.onButtonAction,
    this.onScrollAction,
  });

  @override
  State<FloatingMouse> createState() => _FloatingMouseState();
}

class _FloatingMouseState extends State<FloatingMouse> {
  Rect? _lastBlockedRect;
  bool _pointerGuarded = false;

  InputModel? get _inputModel => widget.ffi?.inputModel;
  CursorModel? get _cursorModel => widget.ffi?.cursorModel;
  VirtualMouseMode? _virtualMouseMode;

  double _accumulatedDx = 0.0;
  double _accumulatedDy = 0.0;

  @override
  void initState() {
    super.initState();
    if (widget.ffi != null) {
      _virtualMouseMode = widget.ffi!.ffiModel.virtualMouseMode;
      _virtualMouseMode?.addListener(_onVirtualMouseModeChanged);
      _cursorModel?.blockEvents = false;
    }
  }

  void _onVirtualMouseModeChanged() {
    if (!mounted) return;
    if (_virtualMouseMode?.showVirtualMouse == false) {
      _clearBlockedRect();
      _cursorModel?.blockEvents = false;
    }
    setState(() {});
  }

  void _updateBlockedRect(Rect newRect) {
    if (_virtualMouseMode != null && !_virtualMouseMode!.showVirtualMouse) {
      _clearBlockedRect();
      return;
    }
    if (_lastBlockedRect != null) {
      _cursorModel?.removeBlockedRect(_lastBlockedRect!);
    }
    _cursorModel?.addBlockedRect(newRect);
    _lastBlockedRect = newRect;
  }

  void _clearBlockedRect() {
    if (_lastBlockedRect != null) {
      _cursorModel?.removeBlockedRect(_lastBlockedRect!);
      _lastBlockedRect = null;
    }
  }

  @override
  void dispose() {
    _clearBlockedRect();
    _virtualMouseMode?.removeListener(_onVirtualMouseModeChanged);
    _cursorModel?.blockEvents = false;
    super.dispose();
  }

  void _ensureCursorInVisibleRect() {
    final cm = _cursorModel;
    if (cm == null) return;
    final visible = cm.getVisibleRect().inflate(1);
    if (!visible.contains(cm.offset)) {
      final size = MediaQuery.of(context).size;
      cm.blockEvents = false;
      if (_lastBlockedRect != null) {
        cm.removeBlockedRect(_lastBlockedRect!);
      }
      cm.move(size.width / 2, size.height / 2);
      if (_lastBlockedRect != null) {
        cm.addBlockedRect(_lastBlockedRect!);
      }
      cm.blockEvents = _pointerGuarded;
    }
  }

  MouseButtons _mapButton(FlurryMouseButton btn) {
    switch (btn) {
      case FlurryMouseButton.left:
        return MouseButtons.left;
      case FlurryMouseButton.right:
        return MouseButtons.right;
      case FlurryMouseButton.wheel:
        return MouseButtons.wheel;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_virtualMouseMode != null && !_virtualMouseMode!.showVirtualMouse) {
      return const Offstage();
    }

    return FlurryToDeskMouseCore(
      scale: _virtualMouseMode?.virtualMouseScale ?? 1.0,
      onRectChanged: _updateBlockedRect,
      onPointerGuardChanged: (active) {
        _pointerGuarded = active;
        _cursorModel?.blockEvents = active;
      },
      onPanStart: _ensureCursorInVisibleRect,
      onTrackpadDelta: (dx, dy) {
        _accumulatedDx += dx;
        _accumulatedDy += dy;
        final int sendX = _accumulatedDx.truncate();
        final int sendY = _accumulatedDy.truncate();
        if (sendX != 0 || sendY != 0) {
          _accumulatedDx -= sendX;
          _accumulatedDy -= sendY;
          widget.onTrackpadMove?.call(sendX, sendY);
        }

        if (widget.ffi != null) {
          if (_inputModel!.relativeMouseMode.value) {
            _inputModel!.sendMobileRelativeMouseMove(dx * 2.4, dy * 2.4);
          } else {
            _cursorModel!.updatePan(Offset(dx, dy), Offset.zero, false);
          }
        }
      },
      onButtonAction: (flurryBtn, down) async {
        final mb = _mapButton(flurryBtn);
        widget.onButtonAction?.call(mb, down);
        if (down) {
          await _cursorModel?.syncCursorPosition();
          await _inputModel?.tapDown(mb);
        } else {
          await _inputModel?.tapUp(mb);
        }
      },
      onScrollNotch: (notchDelta) {
        widget.onScrollAction?.call(notchDelta);
        _inputModel?.scroll(notchDelta);
      },
    );
  }
}
