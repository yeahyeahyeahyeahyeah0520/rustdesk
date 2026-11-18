import 'dart:math';
import 'package:flutter/material.dart';
import 'flurry_theme.dart';

/// Animated Animal Crossing Flurry dialog body shown while connecting to a remote PC.
class FlurryLoadingContent extends StatefulWidget {
  final String text;
  final bool showCancel;
  final String cancelLabel;
  final VoidCallback? onCancel;

  const FlurryLoadingContent({
    super.key,
    required this.text,
    this.showCancel = true,
    this.cancelLabel = '取消',
    this.onCancel,
  });

  @override
  State<FlurryLoadingContent> createState() => _FlurryLoadingContentState();
}

class _FlurryLoadingContentState extends State<FlurryLoadingContent>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final subColor = isDark ? FlurryColors.starlightSubtext : FlurryColors.cocoaSubtext;

    return Container(
      constraints: const BoxConstraints(maxWidth: 268),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              final t = Curves.easeInOut.transform(_controller.value);
              final dy = -8.0 * sin(t * pi);
              final tilt = 0.05 * sin((t - 0.5) * pi);
              return Transform.translate(
                offset: Offset(0, dy),
                child: Transform.rotate(
                  angle: tilt,
                  child: child,
                ),
              );
            },
            child: Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    FlurryColors.sakuraNeon.withOpacity(0.28),
                    FlurryColors.frostCyan.withOpacity(0.08),
                    Colors.transparent,
                  ],
                ),
              ),
              padding: const EdgeInsets.all(6),
              child: Image.asset(
                'assets/flurry_options/flurry_render2.png',
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => Image.asset(
                  'assets/flurry_avatar.png',
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const Icon(
                    Icons.pets_rounded,
                    size: 48,
                    color: FlurryColors.sakuraPink,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: const SizedBox(
              width: 140,
              height: 6,
              child: LinearProgressIndicator(
                backgroundColor: FlurryColors.sakuraSoft,
                valueColor: AlwaysStoppedAnimation<Color>(FlurryColors.sakuraPink),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            widget.text,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w600,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '❄️ 正在铺设通往远端电脑的雪地小径…',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11.5, color: subColor),
          ),
          if (widget.showCancel) ...[
            const SizedBox(height: 16),
            TextButton(
              onPressed: widget.onCancel,
              style: TextButton.styleFrom(
                foregroundColor: FlurryColors.sakuraPink,
                padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                  side: BorderSide(color: FlurryColors.sakuraPink.withOpacity(0.45)),
                ),
              ),
              child: Text(
                widget.cancelLabel,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Starlight transition curtain displayed in `remote_page.dart` before the first video frame arrives.
class FlurryCanvasSplash extends StatelessWidget {
  final Color backgroundColor;

  const FlurryCanvasSplash({
    super.key,
    this.backgroundColor = FlurryColors.starlightBg,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: backgroundColor,
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: FlurryColors.starlightCard,
              border: Border.all(
                color: FlurryColors.sakuraNeon.withOpacity(0.5),
                width: 1.8,
              ),
              boxShadow: [
                BoxShadow(
                  color: FlurryColors.sakuraNeon.withOpacity(0.22),
                  blurRadius: 18,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Image.asset(
              'assets/flurry_options/flurry_icon.png',
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => const Icon(
                Icons.desktop_windows_rounded,
                color: FlurryColors.sakuraNeon,
                size: 34,
              ),
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            '正在展开远端电脑桌面画布，雪球~',
            style: TextStyle(
              color: FlurryColors.snowWhiteText,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              decoration: TextDecoration.none,
            ),
          ),
        ],
      ),
    );
  }
}
