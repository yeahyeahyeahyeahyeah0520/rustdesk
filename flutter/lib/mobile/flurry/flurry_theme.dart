import 'package:flutter/material.dart';

typedef FlurryOptionReader = String Function(String key);
typedef FlurryOptionWriter = void Function(String key, String value);

/// Color tokens inspired by Flurry (雪美) from Animal Crossing: New Horizons:
/// Fluffy snow-white fur, sakura-pink inner ears, ice-mint eyebrows/paws, and red daisy sweater.
class FlurryColors {
  FlurryColors._();

  // Signature character accents
  static const Color sakuraPink = Color(0xFFFF6F9C);
  static const Color sakuraNeon = Color(0xFFFF80AB);
  static const Color sakuraSoft = Color(0xFFFFD6E4);
  static const Color iceMint = Color(0xFF2AB7CA);
  static const Color frostCyan = Color(0xFF64DFDF);
  static const Color daisyRed = Color(0xFFE04848);
  static const Color daisyGold = Color(0xFFFFCA58);

  // Daytime: Animal Crossing Cream (Light Mode)
  static const Color creamBg = Color(0xFFFFFDF9);
  static const Color creamCard = Color(0xFFFFF4F7);
  static const Color creamSurface = Color(0xFFFFFFFF);
  static const Color creamBorder = Color(0xFFFFDAE6);
  static const Color cocoaText = Color(0xFF4A3B3E);
  static const Color cocoaSubtext = Color(0xFF8C757B);

  // Nighttime & Remote HUD: Winter Starlight (Dark Mode)
  static const Color starlightBg = Color(0xFF141923);
  static const Color starlightCard = Color(0xFF1E2534);
  static const Color starlightHud = Color(0xEB1A2130);
  static const Color starlightBorder = Color(0xFF34405A);
  static const Color snowWhiteText = Color(0xFFF5F7FC);
  static const Color starlightSubtext = Color(0xFFA3B1CC);
}

/// Persistent and reactive configuration for Flurry customization features.
class FlurryConfig {
  FlurryConfig._();

  static const String kKeyCopywriting = 'flurry-copywriting';
  static const String kKeyMascot = 'flurry-mascot';
  static const String kKeySnowfall = 'flurry-snowfall';

  static FlurryOptionReader? _reader;
  static FlurryOptionWriter? _writer;
  static bool _storageBound = false;

  static final ValueNotifier<bool> copywritingNotifier = ValueNotifier<bool>(true);
  static final ValueNotifier<bool> mascotNotifier = ValueNotifier<bool>(true);
  static final ValueNotifier<bool> snowfallNotifier = ValueNotifier<bool>(true);

  static bool get enableCopywriting => copywritingNotifier.value;
  static bool get enableMascotOverlay => mascotNotifier.value;
  static bool get enableSnowfall => snowfallNotifier.value;

  /// Connects persistent RustDesk local options when FFI is ready.
  static void bindStorage({
    required FlurryOptionReader reader,
    required FlurryOptionWriter writer,
  }) {
    _reader = reader;
    _writer = writer;
    if (!_storageBound) {
      _storageBound = true;
      copywritingNotifier.value = _readBool(kKeyCopywriting, defaultValue: true);
      mascotNotifier.value = _readBool(kKeyMascot, defaultValue: true);
      snowfallNotifier.value = _readBool(kKeySnowfall, defaultValue: true);
    }
  }

  static bool _readBool(String key, {required bool defaultValue}) {
    try {
      final raw = _reader?.call(key) ?? '';
      if (raw.isEmpty) return defaultValue;
      return raw != 'N' && raw != 'false';
    } catch (_) {
      return defaultValue;
    }
  }

  static void setCopywriting(bool enabled) {
    copywritingNotifier.value = enabled;
    _writeBool(kKeyCopywriting, enabled);
  }

  static void setMascotOverlay(bool enabled) {
    mascotNotifier.value = enabled;
    _writeBool(kKeyMascot, enabled);
  }

  static void setSnowfall(bool enabled) {
    snowfallNotifier.value = enabled;
    _writeBool(kKeySnowfall, enabled);
  }

  static void _writeBool(String key, bool enabled) {
    try {
      _writer?.call(key, enabled ? 'Y' : 'N');
    } catch (_) {}
  }
}

/// Applies Flurry's cozy Animal Crossing palettes onto mobile ThemeData.
class FlurryTheme {
  FlurryTheme._();

  static ThemeData applyLight(ThemeData base) {
    final textTheme = base.textTheme.apply(
      bodyColor: FlurryColors.cocoaText,
      displayColor: FlurryColors.cocoaText,
    );
    return base.copyWith(
      primaryColor: FlurryColors.sakuraPink,
      scaffoldBackgroundColor: FlurryColors.creamBg,
      dialogBackgroundColor: FlurryColors.creamSurface,
      cardColor: FlurryColors.creamCard,
      canvasColor: FlurryColors.creamSurface,
      dividerColor: FlurryColors.creamBorder,
      hintColor: FlurryColors.cocoaSubtext,
      textTheme: textTheme,
      appBarTheme: base.appBarTheme.copyWith(
        backgroundColor: FlurryColors.creamSurface,
        foregroundColor: FlurryColors.cocoaText,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: FlurryColors.sakuraPink),
        titleTextStyle: const TextStyle(
          color: FlurryColors.cocoaText,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: FlurryColors.creamSurface,
        selectedItemColor: FlurryColors.sakuraPink,
        unselectedItemColor: FlurryColors.cocoaSubtext,
        elevation: 8,
      ),
      cardTheme: CardTheme(
        color: FlurryColors.creamCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: FlurryColors.creamBorder, width: 1.2),
        ),
      ),
      dialogTheme: DialogTheme(
        backgroundColor: FlurryColors.creamSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: FlurryColors.sakuraPink,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: FlurryColors.sakuraPink,
        foregroundColor: Colors.white,
      ),
      colorScheme: base.colorScheme.copyWith(
        primary: FlurryColors.sakuraPink,
        secondary: FlurryColors.iceMint,
        surface: FlurryColors.creamSurface,
        onPrimary: Colors.white,
        onSurface: FlurryColors.cocoaText,
      ),
    );
  }

  static ThemeData applyDark(ThemeData base) {
    final textTheme = base.textTheme.apply(
      bodyColor: FlurryColors.snowWhiteText,
      displayColor: FlurryColors.snowWhiteText,
    );
    return base.copyWith(
      primaryColor: FlurryColors.sakuraNeon,
      scaffoldBackgroundColor: FlurryColors.starlightBg,
      dialogBackgroundColor: FlurryColors.starlightCard,
      cardColor: FlurryColors.starlightCard,
      canvasColor: FlurryColors.starlightCard,
      dividerColor: FlurryColors.starlightBorder,
      hintColor: FlurryColors.starlightSubtext,
      textTheme: textTheme,
      appBarTheme: base.appBarTheme.copyWith(
        backgroundColor: FlurryColors.starlightCard,
        foregroundColor: FlurryColors.snowWhiteText,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: FlurryColors.sakuraNeon),
        titleTextStyle: const TextStyle(
          color: FlurryColors.snowWhiteText,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: FlurryColors.starlightCard,
        selectedItemColor: FlurryColors.sakuraNeon,
        unselectedItemColor: FlurryColors.starlightSubtext,
        elevation: 8,
      ),
      cardTheme: CardTheme(
        color: FlurryColors.starlightCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: FlurryColors.starlightBorder, width: 1.2),
        ),
      ),
      dialogTheme: DialogTheme(
        backgroundColor: FlurryColors.starlightCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: FlurryColors.sakuraNeon,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: FlurryColors.sakuraNeon,
        foregroundColor: Colors.white,
      ),
      colorScheme: base.colorScheme.copyWith(
        primary: FlurryColors.sakuraNeon,
        secondary: FlurryColors.frostCyan,
        surface: FlurryColors.starlightCard,
        onPrimary: Colors.white,
        onSurface: FlurryColors.snowWhiteText,
      ),
    );
  }
}
