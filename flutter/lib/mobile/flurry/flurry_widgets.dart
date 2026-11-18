import 'package:flutter/material.dart';
import 'flurry_theme.dart';

/// AppBar title badge featuring Flurry's icon and cozy branding.
class FlurryAppBarTitle extends StatelessWidget {
  final String title;

  const FlurryAppBarTitle({
    super.key,
    this.title = '雪美远控',
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 28,
          height: 28,
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: FlurryColors.sakuraSoft.withOpacity(0.45),
            border: Border.all(
              color: FlurryColors.sakuraPink.withOpacity(0.65),
              width: 1.2,
            ),
          ),
          child: ClipOval(
            child: Image.asset(
              'assets/flurry_options/flurry_icon.png',
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const Icon(
                Icons.pets_rounded,
                size: 16,
                color: FlurryColors.sakuraPink,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
        ),
        const SizedBox(width: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: FlurryColors.sakuraPink.withOpacity(0.16),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Text(
            '雪球~',
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: FlurryColors.sakuraPink,
            ),
          ),
        ),
      ],
    );
  }
}

/// Cozy Animal Crossing welcome banner placed above the Remote ID input box on mobile.
class FlurryWorkbenchBanner extends StatelessWidget {
  const FlurryWorkbenchBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgGradient = isDark
        ? const LinearGradient(
            colors: [Color(0xFF21293C), Color(0xFF2B2338)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          )
        : const LinearGradient(
            colors: [Color(0xFFFFF0F5), Color(0xFFEFFBFB)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          );
    final borderColor = isDark
        ? FlurryColors.sakuraNeon.withOpacity(0.32)
        : FlurryColors.sakuraPink.withOpacity(0.35);
    final titleColor = isDark ? FlurryColors.snowWhiteText : FlurryColors.cocoaText;
    final subColor = isDark ? FlurryColors.starlightSubtext : FlurryColors.cocoaSubtext;

    return Container(
      margin: const EdgeInsets.only(top: 8, bottom: 4, left: 2, right: 2),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: bgGradient,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: FlurryColors.sakuraPink.withOpacity(isDark ? 0.12 : 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: FlurryColors.daisyRed,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '雪美的远控工作台',
                      style: TextStyle(
                        color: titleColor,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                ValueListenableBuilder<bool>(
                  valueListenable: FlurryConfig.copywritingNotifier,
                  builder: (context, cuteMode, _) {
                    return Text(
                      cuteMode
                          ? '输入下方电脑门牌号，雪美带你一键登岛操控，雪球~'
                          : '输入远端电脑 ID 即可发起低延迟远程桌面控制',
                      style: TextStyle(
                        color: subColor,
                        fontSize: 12,
                        height: 1.35,
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 58,
            height: 62,
            child: Image.asset(
              'assets/flurry_render.png',
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => const Icon(
                Icons.pets_rounded,
                size: 38,
                color: FlurryColors.sakuraPink,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Animal Crossing villager-photo polaroid card shown when a peer list tab is empty.
class FlurryPolaroidEmptyState extends StatelessWidget {
  final String message;

  const FlurryPolaroidEmptyState({
    super.key,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final frameBg = isDark ? const Color(0xFF242D40) : Colors.white;
    final textColor = isDark ? FlurryColors.starlightSubtext : FlurryColors.cocoaSubtext;

    return Center(
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Transform.rotate(
                angle: -0.035,
                child: Container(
                  width: 124,
                  padding: const EdgeInsets.fromLTRB(8, 8, 8, 16),
                  decoration: BoxDecoration(
                    color: frameBg,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: FlurryColors.sakuraPink.withOpacity(0.35),
                      width: 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(isDark ? 0.3 : 0.08),
                        blurRadius: 14,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(9),
                        child: Image.asset(
                          'assets/flurry_photo.png',
                          width: 106,
                          height: 106,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const SizedBox(
                            width: 106,
                            height: 106,
                            child: Icon(
                              Icons.pets_rounded,
                              size: 44,
                              color: FlurryColors.sakuraPink,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Flurry · 雪美',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: FlurryColors.sakuraPink,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: textColor,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w500,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
