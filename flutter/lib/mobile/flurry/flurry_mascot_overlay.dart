import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'flurry_theme.dart';

typedef BlockedRectCallback = void Function(Rect? previousRect, Rect? currentRect);

/// Draggable, edge-collapsible Flurry companion widget for the mobile remote session.
/// Isolated with [RepaintBoundary] for zero video FPS impact and reports its exact screen
/// bounds via [onBlockedRectChanged] so touches never leak through to the remote computer.
class FlurryMascotOverlay extends StatefulWidget {
  final BlockedRectCallback? onBlockedRectChanged;

  const FlurryMascotOverlay({
    super.key,
    this.onBlockedRectChanged,
  });

  @override
  State<FlurryMascotOverlay> createState() => _FlurryMascotOverlayState();
}

class _FlurryMascotOverlayState extends State<FlurryMascotOverlay>
    with SingleTickerProviderStateMixin {
  final GlobalKey _mascotKey = GlobalKey();
  Rect? _reportedRect;

  Offset _pos = const Offset(12, 84);
  bool _initialized = false;
  bool _dockedEdge = false;
  bool _dockRight = false;

  int _quoteIndex = 0;
  bool _showBubble = false;
  Timer? _bubbleTimer;
  late final AnimationController _breathController;

  static const List<String> _quotes = [
    '连线稳稳哒！今天也要开心哦，雪球~',
    '小贴士：双击虚拟触控板可锁定左键框选或拖窗口哦，雪球~',
    '点我身旁的小箭头，我就会贴边藏好不挡屏幕啦，雪球~',
    '累了记得眨眨眼睛休息一下呀，雪球~',
    '点右上角小雪花可以开关冬日飘雪氛围哦，雪球~',
  ];

  @override
  void initState() {
    super.initState();
    _breathController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);
    FlurryConfig.mascotNotifier.addListener(_onVisibilityChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final size = MediaQuery.of(context).size;
      setState(() {
        _pos = Offset(12.0, (size.height * 0.16).clamp(56.0, 220.0));
        _initialized = true;
      });
      _scheduleRectSync();
    });
  }

  void _onVisibilityChanged() {
    if (!mounted) return;
    setState(() {});
    if (!FlurryConfig.enableMascotOverlay) {
      _clearBlockedRect();
    } else {
      _scheduleRectSync();
    }
  }

  void _scheduleRectSync() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!FlurryConfig.enableMascotOverlay) {
        _clearBlockedRect();
        return;
      }
      final ctx = _mascotKey.currentContext;
      final box = ctx?.findRenderObject() as RenderBox?;
      if (box == null || !box.attached) return;
      final rect = box.localToGlobal(Offset.zero) & box.size;
      widget.onBlockedRectChanged?.call(_reportedRect, rect);
      _reportedRect = rect;
    });
  }

  void _clearBlockedRect() {
    if (_reportedRect != null) {
      widget.onBlockedRectChanged?.call(_reportedRect, null);
      _reportedRect = null;
    }
  }

  @override
  void dispose() {
    _bubbleTimer?.cancel();
    _breathController.dispose();
    FlurryConfig.mascotNotifier.removeListener(_onVisibilityChanged);
    _clearBlockedRect();
    super.dispose();
  }

  void _onTapMascot() {
    HapticFeedback.lightImpact();
    _bubbleTimer?.cancel();
    setState(() {
      _quoteIndex = (_quoteIndex + 1) % _quotes.length;
      _showBubble = true;
    });
    _scheduleRectSync();
    _bubbleTimer = Timer(const Duration(milliseconds: 3200), () {
      if (!mounted) return;
      setState(() => _showBubble = false);
      _scheduleRectSync();
    });
  }

  void _toggleDock() {
    HapticFeedback.selectionClick();
    final size = MediaQuery.of(context).size;
    setState(() {
      _showBubble = false;
      _dockedEdge = !_dockedEdge;
      _dockRight = _pos.dx > size.width / 2;
      if (_dockedEdge) {
        _pos = Offset(_dockRight ? size.width - 28.0 : 0.0, _pos.dy);
      } else {
        _pos = Offset(
          _dockRight ? max(8.0, size.width - 78.0) : 12.0,
          _pos.dy,
        );
      }
    });
    _scheduleRectSync();
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized || !FlurryConfig.enableMascotOverlay) {
      return const Offstage();
    }

    final size = MediaQuery.of(context).size;
    final double clampedX = (_dockedEdge
            ? (_dockRight ? max(0.0, size.width - 28.0) : 0.0)
            : _pos.dx.clamp(4.0, max(4.0, size.width - 72.0)))
        .toDouble();
    final double clampedY =
        _pos.dy.clamp(36.0, max(36.0, size.height - 96.0)).toDouble();

    return Positioned(
      left: clampedX,
      top: clampedY,
      child: RepaintBoundary(
        child: GestureDetector(
          key: _mascotKey,
          behavior: HitTestBehavior.opaque,
          onPanUpdate: (details) {
            setState(() {
              _dockedEdge = false;
              _pos = Offset(
                (_pos.dx + details.delta.dx).clamp(4.0, max(4.0, size.width - 72.0)),
                (_pos.dy + details.delta.dy).clamp(36.0, max(36.0, size.height - 96.0)),
              );
            });
            _scheduleRectSync();
          },
          onPanEnd: (_) {
            final snapRight = _pos.dx > size.width * 0.5;
            setState(() {
              _dockRight = snapRight;
            });
            _scheduleRectSync();
          },
          child: _dockedEdge ? _buildDockedTab() : _buildExpandedCompanion(),
        ),
      ),
    );
  }

  Widget _buildDockedTab() {
    return GestureDetector(
      onTap: _toggleDock,
      child: Container(
        width: 28,
        height: 54,
        decoration: BoxDecoration(
          color: FlurryColors.starlightHud,
          borderRadius: BorderRadius.horizontal(
            left: _dockRight ? const Radius.circular(16) : Radius.zero,
            right: _dockRight ? Radius.zero : const Radius.circular(16),
          ),
          border: Border.all(
            color: FlurryColors.sakuraNeon.withOpacity(0.65),
            width: 1.4,
          ),
          boxShadow: [
            BoxShadow(
              color: FlurryColors.sakuraNeon.withOpacity(0.28),
              blurRadius: 8,
            ),
          ],
        ),
        padding: const EdgeInsets.all(3),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ClipOval(
              child: Image.asset(
                'assets/flurry_options/flurry_icon.png',
                width: 20,
                height: 20,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const Icon(
                  Icons.pets_rounded,
                  size: 14,
                  color: FlurryColors.sakuraNeon,
                ),
              ),
            ),
            Icon(
              _dockRight ? Icons.chevron_left_rounded : Icons.chevron_right_rounded,
              size: 16,
              color: FlurryColors.sakuraSoft,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExpandedCompanion() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_dockRight && _showBubble) _buildSpeechBubble(),
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Top mini action pill: Snow toggle + Edge fold
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                color: FlurryColors.starlightHud,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withOpacity(0.16)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ValueListenableBuilder<bool>(
                    valueListenable: FlurryConfig.snowfallNotifier,
                    builder: (context, snowOn, _) {
                      return GestureDetector(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          FlurryConfig.setSnowfall(!snowOn);
                        },
                        child: Icon(
                          Icons.ac_unit_rounded,
                          size: 13,
                          color: snowOn ? FlurryColors.frostCyan : Colors.white38,
                        ),
                      );
                    },
                  ),
                  const SizedBox(width: 6),
                  GestureDetector(
                    onTap: _toggleDock,
                    child: Icon(
                      _dockRight
                          ? Icons.keyboard_double_arrow_right_rounded
                          : Icons.keyboard_double_arrow_left_rounded,
                      size: 14,
                      color: FlurryColors.sakuraNeon,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 3),
            // Breathing Flurry character sprite
            GestureDetector(
              onTap: _onTapMascot,
              child: AnimatedBuilder(
                animation: _breathController,
                builder: (context, child) {
                  final dy = -2.5 * _breathController.value;
                  return Transform.translate(offset: Offset(0, dy), child: child);
                },
                child: Container(
                  width: 56,
                  height: 62,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: FlurryColors.sakuraNeon.withOpacity(0.24),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Image.asset(
                    'assets/flurry_render.png',
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => Image.asset(
                      'assets/flurry_avatar.png',
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        if (!_dockRight && _showBubble) _buildSpeechBubble(),
      ],
    );
  }

  Widget _buildSpeechBubble() {
    return Container(
      constraints: const BoxConstraints(maxWidth: 176),
      margin: const EdgeInsets.only(left: 6, right: 6, top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: FlurryColors.creamSurface.withOpacity(0.95),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: FlurryColors.sakuraPink, width: 1.3),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.25),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Text(
        _quotes[_quoteIndex],
        style: const TextStyle(
          color: FlurryColors.cocoaText,
          fontSize: 11.5,
          fontWeight: FontWeight.w600,
          height: 1.3,
          decoration: TextDecoration.none,
        ),
      ),
    );
  }
}
