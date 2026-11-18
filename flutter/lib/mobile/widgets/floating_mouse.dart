// ToDesk-style ergonomic floating virtual mouse widget for RustDesk mobile.
// Provides a stationary floating remote controller with:
// 1. Separate relative trackpad (swiping moves cursor without moving widget)
// 2. Physical Left / Right buttons + Drag-Lock mode for text selection / window dragging
// 3. Ergonomic vertical scroll wheel capsule (tap, hold, or vertical drag to scroll)
// 4. Position drag handle & one-tap minimize to floating orb
// 5. Sensitivity quick switch (1.0x / 1.4x / 2.0x)

import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hbb/models/input_model.dart';
import 'package:flutter_hbb/models/model.dart';
import 'package:flutter_hbb/models/platform_model.dart';

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

class _FloatingMouseState extends State<FloatingMouse> with SingleTickerProviderStateMixin {
  final GlobalKey _widgetKey = GlobalKey();
  Rect? _lastBlockedRect;

  // Widget dimensions
  static const double _baseWidth = 142.0;
  static const double _baseHeight = 224.0;
  static const double _puckSize = 48.0;

  // Widget positioning
  Offset _position = Offset.zero;
  bool _isInitialized = false;
  bool _isCollapsed = false;

  // Input & model references
  InputModel? get _inputModel => widget.ffi?.inputModel;
  CursorModel? get _cursorModel => widget.ffi?.cursorModel;
  VirtualMouseMode? _virtualMouseMode;

  // Mouse State
  bool _leftDown = false;
  bool _rightDown = false;
  bool _midDown = false;
  bool _dragLocked = false; // Drag & drop text selection lock

  // Scroll wheel
  Timer? _scrollTimer;
  double _scrollDragAccumulator = 0.0;

  // Trackpad movement
  double _accumulatedDx = 0.0;
  double _accumulatedDy = 0.0;
  double _sensitivity = 1.3; // 1.0, 1.4, 2.0
  DateTime? _lastTrackpadTapTime;

  // Orientation tracking
  Orientation? _previousOrientation;

  @override
  void initState() {
    super.initState();
    if (widget.ffi != null) {
      _virtualMouseMode = widget.ffi!.ffiModel.virtualMouseMode;
      _virtualMouseMode?.addListener(_onVirtualMouseModeChanged);
      _cursorModel?.blockEvents = false;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initPosition();
    });
  }

  void _onVirtualMouseModeChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final currentOrientation = MediaQuery.of(context).orientation;
    if (_previousOrientation != null && _previousOrientation != currentOrientation) {
      _clampPosition();
    }
    _previousOrientation = currentOrientation;
  }

  void _initPosition() {
    final size = MediaQuery.of(context).size;
    // Default position: bottom right corner, comfortable for right thumb
    final double defaultX = size.width - _baseWidth - 16;
    final double defaultY = size.height - _baseHeight - 32;

    setState(() {
      _position = Offset(
        defaultX.clamp(16.0, max(16.0, size.width - _baseWidth - 16)),
        defaultY.clamp(32.0, max(32.0, size.height - _baseHeight - 32)),
      );
      _isInitialized = true;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _updateBlockedRect();
    });
  }

  void _clampPosition() {
    final size = MediaQuery.of(context).size;
    final currentW = _isCollapsed ? _puckSize : _baseWidth;
    final currentH = _isCollapsed ? _puckSize : _baseHeight;

    setState(() {
      _position = Offset(
        _position.dx.clamp(8.0, max(8.0, size.width - currentW - 8.0)),
        _position.dy.clamp(24.0, max(24.0, size.height - currentH - 24.0)),
      );
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _updateBlockedRect();
    });
  }

  void _updateBlockedRect() {
    final ctx = _widgetKey.currentContext;
    if (ctx == null) return;
    final renderBox = ctx.findRenderObject() as RenderBox?;
    if (renderBox == null || !renderBox.attached) return;

    final newRect = renderBox.localToGlobal(Offset.zero) & renderBox.size;
    if (_lastBlockedRect != null) {
      _cursorModel?.removeBlockedRect(_lastBlockedRect!);
    }
    _cursorModel?.addBlockedRect(newRect);
    _lastBlockedRect = newRect;
  }

  @override
  void dispose() {
    _scrollTimer?.cancel();
    if (_lastBlockedRect != null) {
      _cursorModel?.removeBlockedRect(_lastBlockedRect!);
    }
    _virtualMouseMode?.removeListener(_onVirtualMouseModeChanged);
    _cursorModel?.blockEvents = false;

    // Release mouse button if locked
    if (_dragLocked) {
      _inputModel?.tapUp(MouseButtons.left);
      widget.onButtonAction?.call(MouseButtons.left, false);
    }
    super.dispose();
  }

  // --- Trackpad Relative Movement ---
  void _onTrackpadPanUpdate(DragUpdateDetails details) {
    _accumulatedDx += details.delta.dx * _sensitivity;
    _accumulatedDy += details.delta.dy * _sensitivity;

    final int sendX = _accumulatedDx.truncate();
    final int sendY = _accumulatedDy.truncate();

    if (sendX != 0 || sendY != 0) {
      _accumulatedDx -= sendX;
      _accumulatedDy -= sendY;

      widget.onTrackpadMove?.call(sendX, sendY);

      if (widget.ffi != null) {
        bind.sessionSendMouse(
          sessionId: widget.ffi!.sessionId,
          msg: '{"type": "trackpad", "x": "$sendX", "y": "$sendY"}',
        );
      }
    }
  }

  void _onTrackpadTap() {
    HapticFeedback.lightImpact();
    final now = DateTime.now();

    // Double tap triggers lock/drag mode
    if (_lastTrackpadTapTime != null &&
        now.difference(_lastTrackpadTapTime!).inMilliseconds < 280) {
      _toggleDragLock();
      _lastTrackpadTapTime = null;
      return;
    }
    _lastTrackpadTapTime = now;

    // Single tap on trackpad acts like left click
    _leftDown = true;
    _inputModel?.tapDown(MouseButtons.left);
    widget.onButtonAction?.call(MouseButtons.left, true);

    Future.delayed(const Duration(milliseconds: 40), () {
      if (!_dragLocked) {
        _leftDown = false;
        _inputModel?.tapUp(MouseButtons.left);
        widget.onButtonAction?.call(MouseButtons.left, false);
      }
    });
  }

  // --- Drag Lock Toggle ---
  void _toggleDragLock() {
    HapticFeedback.mediumImpact();
    setState(() {
      _dragLocked = !_dragLocked;
      if (_dragLocked) {
        _leftDown = true;
        _inputModel?.tapDown(MouseButtons.left);
        widget.onButtonAction?.call(MouseButtons.left, true);
      } else {
        _leftDown = false;
        _inputModel?.tapUp(MouseButtons.left);
        widget.onButtonAction?.call(MouseButtons.left, false);
      }
    });
  }

  // --- Scroll Wheel Actions ---
  void _startContinuousScroll(int delta) {
    HapticFeedback.selectionClick();
    _inputModel?.scroll(delta);
    widget.onScrollAction?.call(delta);

    _scrollTimer?.cancel();
    _scrollTimer = Timer.periodic(const Duration(milliseconds: 80), (_) {
      _inputModel?.scroll(delta);
      widget.onScrollAction?.call(delta);
    });
  }

  void _stopContinuousScroll() {
    _scrollTimer?.cancel();
    _scrollTimer = null;
  }

  void _onWheelVerticalDrag(DragUpdateDetails details) {
    _scrollDragAccumulator += details.delta.dy * -1.5;
    if (_scrollDragAccumulator.abs() >= 8.0) {
      final int steps = (_scrollDragAccumulator / 8.0).truncate();
      _scrollDragAccumulator -= steps * 8.0;
      final int delta = steps * 100;
      _inputModel?.scroll(delta);
      widget.onScrollAction?.call(delta);
    }
  }

  // --- Sensitivity Toggle ---
  void _cycleSensitivity() {
    HapticFeedback.selectionClick();
    setState(() {
      if (_sensitivity == 1.0) {
        _sensitivity = 1.4;
      } else if (_sensitivity == 1.4) {
        _sensitivity = 2.0;
      } else {
        _sensitivity = 1.0;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return const Offstage();
    }
    if (_virtualMouseMode != null && !_virtualMouseMode!.showVirtualMouse) {
      return const Offstage();
    }

    return Stack(
      children: [
        Positioned(
          left: _position.dx,
          top: _position.dy,
          child: _isCollapsed ? _buildCollapsedPuck() : _buildFullMouseWidget(),
        ),
      ],
    );
  }

  // --- Collapsed State (Floating Orb with Character Avatar) ---
  Widget _buildCollapsedPuck() {
    return GestureDetector(
      key: _widgetKey,
      onPanUpdate: (details) {
        setState(() {
          final size = MediaQuery.of(context).size;
          _position = Offset(
            (_position.dx + details.delta.dx).clamp(8.0, size.width - _puckSize - 8.0),
            (_position.dy + details.delta.dy).clamp(24.0, size.height - _puckSize - 24.0),
          );
        });
        _updateBlockedRect();
      },
      onTap: () {
        HapticFeedback.mediumImpact();
        setState(() {
          _isCollapsed = false;
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _clampPosition();
        });
      },
      child: Container(
        width: _puckSize,
        height: _puckSize,
        decoration: BoxDecoration(
          color: const Color(0xE61F232A),
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFFFF80AB).withOpacity(0.6), width: 2.0),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFF80AB).withOpacity(0.35),
              blurRadius: 12,
              spreadRadius: 1,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: ClipOval(
          child: Image.asset(
            'assets/flurry_avatar.png',
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Image.asset(
              'assets/custom_mouse_avatar.jpg',
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const Center(
                child: Icon(
                  Icons.pets_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // --- Full ToDesk-Style Mouse Widget ---
  Widget _buildFullMouseWidget() {
    final Color surfaceColor = const Color(0xEB1A2130);
    final Color buttonColor = const Color(0x30FFFFFF);
    final Color activeColor = const Color(0xFFFF6F9C);

    return Container(
      key: _widgetKey,
      width: _baseWidth,
      height: _baseHeight,
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(
          color: _dragLocked ? activeColor : Colors.white.withOpacity(0.18),
          width: _dragLocked ? 2.0 : 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.45),
            blurRadius: 16,
            spreadRadius: 1,
            offset: const Offset(0, 6),
          ),
          if (_dragLocked)
            BoxShadow(
              color: activeColor.withOpacity(0.35),
              blurRadius: 12,
              spreadRadius: 2,
            ),
        ],
      ),
      child: Column(
        children: [
          // 1. Top Bar: Move Handle + Sensitivity + Minimize
          _buildTopBar(),

          // 2. Upper Body: Left Button, Wheel Capsule, Right Button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: SizedBox(
              height: 72,
              child: Row(
                children: [
                  // Left Mouse Button
                  Expanded(
                    child: _buildLeftButton(buttonColor, activeColor),
                  ),

                  const SizedBox(width: 6),

                  // Center Scroll Wheel Capsule
                  _buildWheelCapsule(),

                  const SizedBox(width: 6),

                  // Right Mouse Button
                  Expanded(
                    child: _buildRightButton(buttonColor, activeColor),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 8),

          // 3. Lower Body: Relative Trackpad Area
          Expanded(
            child: _buildTrackpadArea(),
          ),
        ],
      ),
    );
  }

  // --- Header / Drag Handle & Tool Buttons ---
  Widget _buildTopBar() {
    return GestureDetector(
      onPanUpdate: (details) {
        setState(() {
          final size = MediaQuery.of(context).size;
          _position = Offset(
            (_position.dx + details.delta.dx).clamp(8.0, size.width - _baseWidth - 8.0),
            (_position.dy + details.delta.dy).clamp(24.0, size.height - _baseHeight - 24.0),
          );
        });
        _updateBlockedRect();
      },
      child: Container(
        height: 28,
        decoration: const BoxDecoration(
          color: Color(0x1AFFFFFF),
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Move Handle Icon + Character Mini Badge
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.drag_indicator_rounded,
                  color: Colors.white.withOpacity(0.5),
                  size: 16,
                ),
                const SizedBox(width: 4),
                Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFFFF80AB).withOpacity(0.6), width: 1),
                  ),
                  child: ClipOval(
                    child: Image.asset(
                      'assets/custom_mouse_avatar.jpg',
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const SizedBox(),
                    ),
                  ),
                ),
              ],
            ),

            // Sensitivity Toggle Badge
            GestureDetector(
              onTap: _cycleSensitivity,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.35),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white.withOpacity(0.15)),
                ),
                child: Text(
                  '${_sensitivity.toStringAsFixed(1)}x',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),

            // Minimize Button
            GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                setState(() {
                  _isCollapsed = true;
                });
                _updateBlockedRect();
              },
              child: Icon(
                Icons.remove_rounded,
                color: Colors.white.withOpacity(0.7),
                size: 18,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- Left Mouse Button ---
  Widget _buildLeftButton(Color normalColor, Color activeColor) {
    final bool isHighlighted = _leftDown || _dragLocked;

    return GestureDetector(
      onTapDown: (_) {
        HapticFeedback.lightImpact();
        if (!_dragLocked) {
          setState(() => _leftDown = true);
          _inputModel?.tapDown(MouseButtons.left);
          widget.onButtonAction?.call(MouseButtons.left, true);
        }
      },
      onTapUp: (_) {
        if (!_dragLocked) {
          setState(() => _leftDown = false);
          _inputModel?.tapUp(MouseButtons.left);
          widget.onButtonAction?.call(MouseButtons.left, false);
        }
      },
      onTapCancel: () {
        if (!_dragLocked) {
          setState(() => _leftDown = false);
          _inputModel?.tapUp(MouseButtons.left);
          widget.onButtonAction?.call(MouseButtons.left, false);
        }
      },
      onLongPress: _toggleDragLock,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        decoration: BoxDecoration(
          color: isHighlighted ? activeColor : normalColor,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(16),
            bottomLeft: Radius.circular(10),
          ),
          border: Border.all(
            color: isHighlighted ? Colors.white : Colors.white.withOpacity(0.12),
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                _dragLocked ? Icons.lock_rounded : Icons.touch_app_rounded,
                color: Colors.white,
                size: 18,
              ),
              const SizedBox(height: 2),
              Text(
                _dragLocked ? '锁定中' : '左键',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- Right Mouse Button ---
  Widget _buildRightButton(Color normalColor, Color activeColor) {
    return GestureDetector(
      onTapDown: (_) {
        HapticFeedback.lightImpact();
        setState(() => _rightDown = true);
        _inputModel?.tapDown(MouseButtons.right);
        widget.onButtonAction?.call(MouseButtons.right, true);
      },
      onTapUp: (_) {
        setState(() => _rightDown = false);
        _inputModel?.tapUp(MouseButtons.right);
        widget.onButtonAction?.call(MouseButtons.right, false);
      },
      onTapCancel: () {
        setState(() => _rightDown = false);
        _inputModel?.tapUp(MouseButtons.right);
        widget.onButtonAction?.call(MouseButtons.right, false);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        decoration: BoxDecoration(
          color: _rightDown ? activeColor : normalColor,
          borderRadius: const BorderRadius.only(
            topRight: Radius.circular(16),
            bottomRight: Radius.circular(10),
          ),
          border: Border.all(
            color: _rightDown ? Colors.white : Colors.white.withOpacity(0.12),
          ),
        ),
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.menu_rounded,
                color: Colors.white,
                size: 18,
              ),
              SizedBox(height: 2),
              Text(
                '右键',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- Scroll Wheel Capsule ---
  Widget _buildWheelCapsule() {
    return GestureDetector(
      onVerticalDragUpdate: _onWheelVerticalDrag,
      child: Container(
        width: 32,
        decoration: BoxDecoration(
          color: const Color(0x40000000),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.2)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            // Scroll Up Button
            GestureDetector(
              onTapDown: (_) => _startContinuousScroll(120),
              onTapUp: (_) => _stopContinuousScroll(),
              onTapCancel: _stopContinuousScroll,
              child: Container(
                width: 28,
                height: 20,
                color: Colors.transparent,
                child: const Icon(Icons.arrow_drop_up_rounded, color: Colors.white, size: 20),
              ),
            ),

            // Middle Click Button
            GestureDetector(
              onTapDown: (_) {
                HapticFeedback.lightImpact();
                setState(() => _midDown = true);
                _inputModel?.tapDown(MouseButtons.wheel);
                widget.onButtonAction?.call(MouseButtons.wheel, true);
              },
              onTapUp: (_) {
                setState(() => _midDown = false);
                _inputModel?.tapUp(MouseButtons.wheel);
                widget.onButtonAction?.call(MouseButtons.wheel, false);
              },
              onTapCancel: () {
                setState(() => _midDown = false);
                _inputModel?.tapUp(MouseButtons.wheel);
                widget.onButtonAction?.call(MouseButtons.wheel, false);
              },
              child: Container(
                width: 20,
                height: 16,
                decoration: BoxDecoration(
                  color: _midDown ? const Color(0xFF64DFDF) : Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Center(
                  child: Container(
                    width: 10,
                    height: 2,
                    color: Colors.white,
                  ),
                ),
              ),
            ),

            // Scroll Down Button
            GestureDetector(
              onTapDown: (_) => _startContinuousScroll(-120),
              onTapUp: (_) => _stopContinuousScroll(),
              onTapCancel: _stopContinuousScroll,
              child: Container(
                width: 28,
                height: 20,
                color: Colors.transparent,
                child: const Icon(Icons.arrow_drop_down_rounded, color: Colors.white, size: 20),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- Lower Body: Relative Touchpad ---
  Widget _buildTrackpadArea() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
      child: GestureDetector(
        onPanUpdate: _onTrackpadPanUpdate,
        onTap: _onTrackpadTap,
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0x24FFFFFF),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: Stack(
            children: [
              // Character watermark avatar in center of trackpad
              Center(
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 150),
                  opacity: _leftDown ? 0.45 : 0.22,
                  child: Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withOpacity(0.18),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFF80AB).withOpacity(0.15),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                    child: ClipOval(
                      child: Image.asset(
                        'assets/flurry_avatar.png',
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Image.asset(
                          'assets/custom_mouse_avatar.jpg',
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const SizedBox(),
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // Center tactile dot grip texture over watermark
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildDot(),
                        _buildDot(),
                        _buildDot(),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildDot(),
                        _buildDot(),
                        _buildDot(),
                      ],
                    ),
                  ],
                ),
              ),

              // Bottom hint
              Positioned(
                bottom: 6,
                left: 0,
                right: 0,
                child: Text(
                  _dragLocked ? '拖拽锁定中 (滑动框选/移动)' : '滑动移动光标 · 轻点左键',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _dragLocked ? const Color(0xFF82B1FF) : Colors.white.withOpacity(0.35),
                    fontSize: 8.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDot() {
    return Container(
      width: 4,
      height: 4,
      margin: const EdgeInsets.symmetric(horizontal: 3),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.35),
        shape: BoxShape.circle,
      ),
    );
  }
}
