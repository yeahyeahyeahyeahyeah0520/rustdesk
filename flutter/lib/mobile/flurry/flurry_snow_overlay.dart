import 'dart:math';
import 'package:flutter/material.dart';
import 'flurry_theme.dart';

/// Ultra-lightweight, touch-transparent snowfall atmosphere layer.
/// Automatically stops its animation ticker when [FlurryConfig.enableSnowfall] is false.
class FlurrySnowOverlay extends StatefulWidget {
  final int flakeCount;

  const FlurrySnowOverlay({
    super.key,
    this.flakeCount = 18,
  });

  @override
  State<FlurrySnowOverlay> createState() => _FlurrySnowOverlayState();
}

class _FlurrySnowOverlayState extends State<FlurrySnowOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final List<_SnowFlake> _flakes;

  @override
  void initState() {
    super.initState();
    final rng = Random(42);
    _flakes = List.generate(widget.flakeCount, (index) {
      return _SnowFlake(
        xFraction: rng.nextDouble(),
        yFraction: rng.nextDouble(),
        radius: 1.8 + rng.nextDouble() * 2.4,
        speed: 0.08 + rng.nextDouble() * 0.14,
        swayAmp: 0.012 + rng.nextDouble() * 0.018,
        phase: rng.nextDouble() * pi * 2,
        isSakuraTint: index % 5 == 0,
      );
    });

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    );
    FlurryConfig.snowfallNotifier.addListener(_syncTicker);
    _syncTicker();
  }

  void _syncTicker() {
    if (!mounted) return;
    if (FlurryConfig.enableSnowfall) {
      if (!_controller.isAnimating) _controller.repeat();
    } else {
      _controller.stop();
    }
    setState(() {});
  }

  @override
  void dispose() {
    FlurryConfig.snowfallNotifier.removeListener(_syncTicker);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!FlurryConfig.enableSnowfall) {
      return const Offstage();
    }
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Positioned.fill(
      child: IgnorePointer(
        child: RepaintBoundary(
          child: CustomPaint(
            painter: _SnowPainter(
              animation: _controller,
              flakes: _flakes,
              isDark: isDark,
            ),
          ),
        ),
      ),
    );
  }
}

class _SnowFlake {
  final double xFraction;
  final double yFraction;
  final double radius;
  final double speed;
  final double swayAmp;
  final double phase;
  final bool isSakuraTint;

  const _SnowFlake({
    required this.xFraction,
    required this.yFraction,
    required this.radius,
    required this.speed,
    required this.swayAmp,
    required this.phase,
    required this.isSakuraTint,
  });
}

class _SnowPainter extends CustomPainter {
  final Animation<double> animation;
  final List<_SnowFlake> flakes;
  final bool isDark;

  _SnowPainter({
    required this.animation,
    required this.flakes,
    required this.isDark,
  }) : super(repaint: animation);

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final snowPaint = Paint()..style = PaintingStyle.fill;
    final progress = animation.value;

    for (final f in flakes) {
      final yNorm = (f.yFraction + progress * (1.0 + f.speed * 4.0)) % 1.0;
      final xNorm = (f.xFraction + sin(progress * pi * 2 + f.phase) * f.swayAmp)
          .clamp(0.0, 1.0);

      if (f.isSakuraTint) {
        snowPaint.color = FlurryColors.sakuraNeon.withOpacity(isDark ? 0.36 : 0.42);
      } else {
        snowPaint.color = isDark
            ? Colors.white.withOpacity(0.32)
            : FlurryColors.iceMint.withOpacity(0.24);
      }
      canvas.drawCircle(
        Offset(xNorm * size.width, yNorm * size.height),
        f.radius,
        snowPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _SnowPainter oldDelegate) =>
      oldDelegate.isDark != isDark;
}
