// Pure Flutter UI & Gesture Core for the ToDesk-style Flurry (雪美) Virtual Mouse.
// Decoupled from FFI/generated_bridge so it can be unit-tested and previewed standalone,
// while FloatingMouse connects it to RustDesk's CursorModel / InputModel in production.

import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'flurry_theme.dart';

enum FlurryMouseButton { left, right, wheel }

class FlurryToDeskMouseCore extends StatefulWidget {
  final double scale;
  final void Function(Rect rect)? onRectChanged;
  final void Function(bool active)? onPointerGuardChanged;
  final VoidCallback? onPanStart;
  final void Function(double dx, double dy)? onTrackpadDelta;
  final FutureOr<void> Function(FlurryMouseButton button, bool down)? onButtonAction;
  final void Function(int notchDelta)? onScrollNotch;

  const FlurryToDeskMouseCore({
    super.key,
    this.scale = 1.0,
    this.onRectChanged,
    this.onPointerGuardChanged,
    this.onPanStart,
    this.onTrackpadDelta,
    this.onButtonAction,
    this.onScrollNotch,
  });

  @override
  State<FlurryToDeskMouseCore> createState() => _FlurryToDeskMouseCoreState();
}

class _FlurryToDeskMouseCoreState extends State<FlurryToDeskMouseCore> {
  int _activePointers = 0;

  static const double _baseWidth = 148.0;
  static const double _baseHeight = 232.0;
  static const double _basePuckSize = 50.0;

  Offset _position = Offset.zero;
  bool _isInitialized = false;
  bool _isCollapsed = false;

  double get _scale => widget.scale.clamp(0.8, 1.8);
  double get _currentWidth => (_isCollapsed ? _basePuckSize : _baseWidth) * _scale;
  double get _currentHeight => (_isCollapsed ? _basePuckSize : _baseHeight) * _scale;

  bool _leftDown = false;
  bool _rightDown = false;
  bool _midDown = false;
  bool _dragLocked = false;
  bool _upScrollDown = false;
  bool _downScrollDown = false;

  Timer? _scrollTimer;
  double _scrollDragAccumulator = 0.0;
  double _sensitivity = 1.3; // 0.8x, 1.3x, 2.0x, 2.8x

  Orientation? _previousOrientation;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _initPosition();
    });
  }

  @override
  void didUpdateWidget(covariant FlurryToDeskMouseCore oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.scale != widget.scale) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _clampPosition();
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final currentOrientation = MediaQuery.of(context).orientation;
    if (_previousOrientation != null && _previousOrientation != currentOrientation) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _clampPosition();
      });
    }
    _previousOrientation = currentOrientation;
  }

  Size _availableBoundsSize() {
    final renderObj = context.findRenderObject();
    final parentObj = renderObj?.parent;
    if (parentObj is RenderBox && parentObj.hasSize) {
      return parentObj.size;
    }
    final mq = MediaQuery.of(context);
    return Size(
      max(200.0, mq.size.width - mq.padding.horizontal),
      max(260.0, mq.size.height - mq.padding.vertical),
    );
  }

  void _initPosition() {
    final size = _availableBoundsSize();
    final w = _currentWidth;
    final h = _currentHeight;
    final double defaultX = size.width - w - 14.0;
    final double defaultY = size.height - h - 24.0;

    setState(() {
      _position = Offset(
        defaultX.clamp(8.0, max(8.0, size.width - w - 8.0)),
        defaultY.clamp(12.0, max(12.0, size.height - h - 12.0)),
      );
      _isInitialized = true;
    });
    _reportRect();
  }

  void _clampPosition() {
    final size = _availableBoundsSize();
    final w = _currentWidth;
    final h = _currentHeight;

    setState(() {
      _position = Offset(
        _position.dx.clamp(8.0, max(8.0, size.width - w - 8.0)),
        _position.dy.clamp(12.0, max(12.0, size.height - h - 12.0)),
      );
    });
    _reportRect();
  }

  void _reportRect() {
    widget.onRectChanged?.call(
      Rect.fromLTWH(_position.dx, _position.dy, _currentWidth, _currentHeight),
    );
  }

  @override
  void dispose() {
    _scrollTimer?.cancel();
    widget.onPointerGuardChanged?.call(false);

    if (_dragLocked || _leftDown) {
      widget.onButtonAction?.call(FlurryMouseButton.left, false);
    }
    if (_rightDown) {
      widget.onButtonAction?.call(FlurryMouseButton.right, false);
    }
    if (_midDown) {
      widget.onButtonAction?.call(FlurryMouseButton.wheel, false);
    }
    super.dispose();
  }

  void _onRootPointerDown(PointerDownEvent _) {
    _activePointers++;
    widget.onPointerGuardChanged?.call(true);
  }

  void _onRootPointerUpOrCancel() {
    _activePointers = max(0, _activePointers - 1);
    if (_activePointers == 0) {
      widget.onPointerGuardChanged?.call(false);
    }
  }

  void _onTrackpadPanStart(DragStartDetails _) {
    widget.onPanStart?.call();
  }

  void _onTrackpadPanUpdate(DragUpdateDetails details) {
    final double dx = details.delta.dx * _sensitivity;
    final double dy = details.delta.dy * _sensitivity;
    if (dx != 0 || dy != 0) {
      widget.onTrackpadDelta?.call(dx, dy);
    }
  }

  Future<void> _onTrackpadTap() async {
    HapticFeedback.lightImpact();
    widget.onPanStart?.call();

    if (_dragLocked) {
      _toggleDragLock();
      return;
    }

    setState(() => _leftDown = true);
    await widget.onButtonAction?.call(FlurryMouseButton.left, true);

    await Future.delayed(const Duration(milliseconds: 45));
    if (!mounted) return;
    if (!_dragLocked) {
      setState(() => _leftDown = false);
      await widget.onButtonAction?.call(FlurryMouseButton.left, false);
    }
  }

  void _toggleDragLock() {
    HapticFeedback.mediumImpact();
    widget.onPanStart?.call();
    setState(() {
      _dragLocked = !_dragLocked;
      if (_dragLocked) {
        _leftDown = true;
        widget.onButtonAction?.call(FlurryMouseButton.left, true);
      } else {
        _leftDown = false;
        widget.onButtonAction?.call(FlurryMouseButton.left, false);
      }
    });
  }

  void _startContinuousScroll(int notchDelta) {
    HapticFeedback.selectionClick();
    widget.onScrollNotch?.call(notchDelta);

    _scrollTimer?.cancel();
    _scrollTimer = Timer.periodic(const Duration(milliseconds: 95), (_) {
      widget.onScrollNotch?.call(notchDelta);
    });
  }

  void _stopContinuousScroll() {
    _scrollTimer?.cancel();
    _scrollTimer = null;
  }

  void _onWheelVerticalDrag(DragUpdateDetails details) {
    _scrollDragAccumulator += -details.delta.dy;
    const double stepThreshold = 14.0;
    if (_scrollDragAccumulator.abs() >= stepThreshold) {
      final int steps = (_scrollDragAccumulator / stepThreshold).truncate();
      _scrollDragAccumulator -= steps * stepThreshold;
      widget.onScrollNotch?.call(steps);
    }
  }

  void _cycleSensitivity() {
    HapticFeedback.selectionClick();
    setState(() {
      if (_sensitivity < 1.0) {
        _sensitivity = 1.3;
      } else if (_sensitivity < 1.6) {
        _sensitivity = 2.0;
      } else if (_sensitivity < 2.4) {
        _sensitivity = 2.8;
      } else {
        _sensitivity = 0.8;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return const Positioned(
        left: 0,
        top: 0,
        child: SizedBox.shrink(),
      );
    }

    return Positioned(
      left: _position.dx,
      top: _position.dy,
      child: RepaintBoundary(
        child: Listener(
          behavior: HitTestBehavior.opaque,
          onPointerDown: _onRootPointerDown,
          onPointerUp: (_) => _onRootPointerUpOrCancel(),
          onPointerCancel: (_) => _onRootPointerUpOrCancel(),
          child: _isCollapsed ? _buildCollapsedPuck() : _buildFullMouseWidget(),
        ),
      ),
    );
  }

  Widget _buildCollapsedPuck() {
    final puckSize = _currentWidth;
    return GestureDetector(
      onPanUpdate: (details) {
        final size = _availableBoundsSize();
        setState(() {
          _position = Offset(
            (_position.dx + details.delta.dx).clamp(8.0, max(8.0, size.width - puckSize - 8.0)),
            (_position.dy + details.delta.dy).clamp(12.0, max(12.0, size.height - puckSize - 12.0)),
          );
        });
        _reportRect();
      },
      onTap: () {
        HapticFeedback.mediumImpact();
        setState(() {
          _isCollapsed = false;
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _clampPosition();
        });
      },
      child: Container(
        width: puckSize,
        height: puckSize,
        decoration: BoxDecoration(
          color: FlurryColors.starlightHud,
          shape: BoxShape.circle,
          border: Border.all(
            color: FlurryColors.sakuraNeon.withOpacity(0.75),
            width: 2.0,
          ),
          boxShadow: [
            BoxShadow(
              color: FlurryColors.sakuraPink.withOpacity(0.42),
              blurRadius: 12,
              spreadRadius: 1,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: ClipOval(
                child: Image.asset(
                  'assets/flurry_avatar.png',
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Image.asset(
                    'assets/custom_mouse_avatar.jpg',
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const Center(
                      child: Icon(Icons.mouse_rounded, color: Colors.white, size: 24),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                width: 16 * _scale,
                height: 16 * _scale,
                decoration: BoxDecoration(
                  color: FlurryColors.sakuraPink,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 1.2),
                ),
                child: Icon(
                  Icons.mouse_rounded,
                  color: Colors.white,
                  size: 10 * _scale,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFullMouseWidget() {
    final s = _scale;
    final Color borderColor = _dragLocked
        ? FlurryColors.iceMint
        : FlurryColors.sakuraNeon.withOpacity(0.38);

    return Container(
      width: _currentWidth,
      height: _currentHeight,
      decoration: BoxDecoration(
        color: FlurryColors.starlightHud,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(30 * s),
          bottom: Radius.circular(38 * s),
        ),
        border: Border.all(
          color: borderColor,
          width: _dragLocked ? 2.0 : 1.3,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.48),
            blurRadius: 16,
            spreadRadius: 1,
            offset: const Offset(0, 6),
          ),
          if (_dragLocked)
            BoxShadow(
              color: FlurryColors.iceMint.withOpacity(0.38),
              blurRadius: 14,
              spreadRadius: 2,
            ),
        ],
      ),
      child: Column(
        children: [
          _buildTopBar(s),
          SizedBox(height: 4 * s),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 7 * s),
            child: SizedBox(
              height: 74 * s,
              child: Row(
                children: [
                  Expanded(child: _buildLeftButton(s)),
                  SizedBox(width: 5 * s),
                  _buildWheelCapsule(s),
                  SizedBox(width: 5 * s),
                  Expanded(child: _buildRightButton(s)),
                ],
              ),
            ),
          ),
          SizedBox(height: 6 * s),
          Expanded(
            child: _buildTrackpadArea(s),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar(double s) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onPanUpdate: (details) {
        final size = _availableBoundsSize();
        setState(() {
          _position = Offset(
            (_position.dx + details.delta.dx).clamp(8.0, max(8.0, size.width - _currentWidth - 8.0)),
            (_position.dy + details.delta.dy).clamp(12.0, max(12.0, size.height - _currentHeight - 12.0)),
          );
        });
        _reportRect();
      },
      child: Container(
        height: 30 * s,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.08),
          borderRadius: BorderRadius.vertical(top: Radius.circular(28 * s)),
        ),
        padding: EdgeInsets.symmetric(horizontal: 8 * s),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.open_with_rounded,
                  color: Colors.white.withOpacity(0.65),
                  size: 13 * s,
                ),
                SizedBox(width: 3 * s),
                Container(
                  width: 17 * s,
                  height: 17 * s,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: FlurryColors.sakuraNeon.withOpacity(0.75),
                      width: 1,
                    ),
                  ),
                  child: ClipOval(
                    child: Image.asset(
                      'assets/flurry_avatar.png',
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const SizedBox(),
                    ),
                  ),
                ),
              ],
            ),

            GestureDetector(
              onTap: _toggleDragLock,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 5 * s, vertical: 2 * s),
                decoration: BoxDecoration(
                  color: _dragLocked
                      ? FlurryColors.iceMint.withOpacity(0.85)
                      : Colors.black.withOpacity(0.32),
                  borderRadius: BorderRadius.circular(7 * s),
                  border: Border.all(
                    color: _dragLocked
                        ? Colors.white
                        : Colors.white.withOpacity(0.16),
                    width: 0.8,
                  ),
                ),
                child: Icon(
                  _dragLocked ? Icons.lock_rounded : Icons.lock_open_rounded,
                  color: Colors.white,
                  size: 11 * s,
                ),
              ),
            ),

            GestureDetector(
              onTap: _cycleSensitivity,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 5 * s, vertical: 2 * s),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.35),
                  borderRadius: BorderRadius.circular(7 * s),
                  border: Border.all(
                    color: FlurryColors.sakuraSoft.withOpacity(0.28),
                    width: 0.8,
                  ),
                ),
                child: Text(
                  '${_sensitivity.toStringAsFixed(1)}x',
                  style: TextStyle(
                    color: FlurryColors.sakuraSoft,
                    fontSize: 9.5 * s,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),

            GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                setState(() {
                  _isCollapsed = true;
                });
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) _clampPosition();
                });
              },
              child: Padding(
                padding: EdgeInsets.all(2 * s),
                child: Icon(
                  Icons.close_fullscreen_rounded,
                  color: Colors.white.withOpacity(0.78),
                  size: 14 * s,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLeftButton(double s) {
    final bool isHighlighted = _leftDown || _dragLocked;

    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: (_) {
        HapticFeedback.lightImpact();
        widget.onPanStart?.call();
        if (_dragLocked) {
          _toggleDragLock();
          return;
        }
        setState(() => _leftDown = true);
        widget.onButtonAction?.call(FlurryMouseButton.left, true);
      },
      onPointerUp: (_) {
        if (!_dragLocked && _leftDown) {
          setState(() => _leftDown = false);
          widget.onButtonAction?.call(FlurryMouseButton.left, false);
        }
      },
      onPointerCancel: (_) {
        if (!_dragLocked && _leftDown) {
          setState(() => _leftDown = false);
          widget.onButtonAction?.call(FlurryMouseButton.left, false);
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 80),
        decoration: BoxDecoration(
          color: _dragLocked
              ? FlurryColors.iceMint.withOpacity(0.85)
              : (isHighlighted
                  ? FlurryColors.sakuraPink.withOpacity(0.88)
                  : Colors.white.withOpacity(0.14)),
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20 * s),
            topRight: Radius.circular(6 * s),
            bottomLeft: Radius.circular(10 * s),
            bottomRight: Radius.circular(8 * s),
          ),
          border: Border.all(
            color: isHighlighted
                ? Colors.white
                : Colors.white.withOpacity(0.16),
            width: 1.0,
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                _dragLocked ? Icons.lock_rounded : Icons.ads_click_rounded,
                color: Colors.white,
                size: 17 * s,
              ),
              SizedBox(height: 2 * s),
              Text(
                _dragLocked ? '锁定中' : '左键',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 10.5 * s,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRightButton(double s) {
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: (_) {
        HapticFeedback.lightImpact();
        widget.onPanStart?.call();
        setState(() => _rightDown = true);
        widget.onButtonAction?.call(FlurryMouseButton.right, true);
      },
      onPointerUp: (_) {
        if (_rightDown) {
          setState(() => _rightDown = false);
          widget.onButtonAction?.call(FlurryMouseButton.right, false);
        }
      },
      onPointerCancel: (_) {
        if (_rightDown) {
          setState(() => _rightDown = false);
          widget.onButtonAction?.call(FlurryMouseButton.right, false);
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 80),
        decoration: BoxDecoration(
          color: _rightDown
              ? FlurryColors.sakuraPink.withOpacity(0.88)
              : Colors.white.withOpacity(0.14),
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(6 * s),
            topRight: Radius.circular(20 * s),
            bottomLeft: Radius.circular(8 * s),
            bottomRight: Radius.circular(10 * s),
          ),
          border: Border.all(
            color: _rightDown ? Colors.white : Colors.white.withOpacity(0.16),
            width: 1.0,
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.menu_open_rounded,
                color: Colors.white,
                size: 17 * s,
              ),
              SizedBox(height: 2 * s),
              Text(
                '右键',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 10.5 * s,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWheelCapsule(double s) {
    return GestureDetector(
      onVerticalDragUpdate: _onWheelVerticalDrag,
      child: Container(
        width: 32 * s,
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.38),
          borderRadius: BorderRadius.circular(16 * s),
          border: Border.all(
            color: FlurryColors.sakuraSoft.withOpacity(0.28),
            width: 1.0,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            Listener(
              behavior: HitTestBehavior.opaque,
              onPointerDown: (_) {
                setState(() => _upScrollDown = true);
                _startContinuousScroll(1);
              },
              onPointerUp: (_) {
                setState(() => _upScrollDown = false);
                _stopContinuousScroll();
              },
              onPointerCancel: (_) {
                setState(() => _upScrollDown = false);
                _stopContinuousScroll();
              },
              child: Container(
                width: 28 * s,
                height: 22 * s,
                alignment: Alignment.center,
                child: Icon(
                  Icons.keyboard_arrow_up_rounded,
                  color: _upScrollDown ? FlurryColors.sakuraNeon : Colors.white,
                  size: 19 * s,
                ),
              ),
            ),

            Listener(
              behavior: HitTestBehavior.opaque,
              onPointerDown: (_) {
                HapticFeedback.lightImpact();
                widget.onPanStart?.call();
                setState(() => _midDown = true);
                widget.onButtonAction?.call(FlurryMouseButton.wheel, true);
              },
              onPointerUp: (_) {
                if (_midDown) {
                  setState(() => _midDown = false);
                  widget.onButtonAction?.call(FlurryMouseButton.wheel, false);
                }
              },
              onPointerCancel: (_) {
                if (_midDown) {
                  setState(() => _midDown = false);
                  widget.onButtonAction?.call(FlurryMouseButton.wheel, false);
                }
              },
              child: Container(
                width: 22 * s,
                height: 16 * s,
                decoration: BoxDecoration(
                  color: _midDown
                      ? FlurryColors.sakuraPink
                      : Colors.white.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(5 * s),
                ),
                child: Center(
                  child: Container(
                    width: 10 * s,
                    height: 2 * s,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(1 * s),
                    ),
                  ),
                ),
              ),
            ),

            Listener(
              behavior: HitTestBehavior.opaque,
              onPointerDown: (_) {
                setState(() => _downScrollDown = true);
                _startContinuousScroll(-1);
              },
              onPointerUp: (_) {
                setState(() => _downScrollDown = false);
                _stopContinuousScroll();
              },
              onPointerCancel: (_) {
                setState(() => _downScrollDown = false);
                _stopContinuousScroll();
              },
              child: Container(
                width: 28 * s,
                height: 22 * s,
                alignment: Alignment.center,
                child: Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: _downScrollDown ? FlurryColors.sakuraNeon : Colors.white,
                  size: 19 * s,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTrackpadArea(double s) {
    return Padding(
      padding: EdgeInsets.fromLTRB(7 * s, 0, 7 * s, 7 * s),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanStart: _onTrackpadPanStart,
        onPanUpdate: _onTrackpadPanUpdate,
        onTap: _onTrackpadTap,
        onLongPress: _toggleDragLock,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.10),
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(14 * s),
              bottom: Radius.circular(30 * s),
            ),
            border: Border.all(
              color: _dragLocked
                  ? FlurryColors.iceMint.withOpacity(0.55)
                  : Colors.white.withOpacity(0.12),
            ),
          ),
          child: Stack(
            children: [
              Center(
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 140),
                  opacity: (_leftDown || _dragLocked) ? 0.48 : 0.25,
                  child: Container(
                    width: 68 * s,
                    height: 68 * s,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: FlurryColors.sakuraSoft.withOpacity(0.28),
                        width: 1.4,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: FlurryColors.sakuraPink.withOpacity(0.18),
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

              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildDot(s),
                        _buildDot(s),
                        _buildDot(s),
                      ],
                    ),
                    SizedBox(height: 5 * s),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildDot(s),
                        _buildDot(s),
                        _buildDot(s),
                      ],
                    ),
                  ],
                ),
              ),

              Positioned(
                bottom: 6 * s,
                left: 4 * s,
                right: 4 * s,
                child: Text(
                  _dragLocked ? '拖拽锁定中 · 轻点解锁' : '触控移光标 · 长按锁左键',
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: _dragLocked
                        ? FlurryColors.frostCyan
                        : Colors.white.withOpacity(0.45),
                    fontSize: 8.5 * s,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDot(double s) {
    return Container(
      width: 3.8 * s,
      height: 3.8 * s,
      margin: EdgeInsets.symmetric(horizontal: 3 * s),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.42),
        shape: BoxShape.circle,
      ),
    );
  }
}
