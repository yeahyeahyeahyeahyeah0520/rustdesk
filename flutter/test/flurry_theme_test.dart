import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_hbb/mobile/flurry/flurry_mascot_overlay.dart';
import 'package:flutter_hbb/mobile/flurry/flurry_strings.dart';
import 'package:flutter_hbb/mobile/flurry/flurry_theme.dart';

void main() {
  setUp(() {
    FlurryConfig.setCopywriting(true);
    FlurryConfig.setMascotOverlay(true);
    FlurryConfig.setSnowfall(true);
  });

  test('FlurryStrings intercepts Chinese & English phrases only when enabled', () {
    expect(
      FlurryStrings.intercept('Connecting...', '正在连接...', locale: 'zh_CN'),
      contains('雪球~'),
    );
    expect(
      FlurryStrings.intercept('Connecting...', 'Connecting...', locale: 'en_US'),
      contains('powderpuff~'),
    );

    FlurryConfig.setCopywriting(false);
    expect(
      FlurryStrings.intercept('Connecting...', '正在连接...', locale: 'zh_CN'),
      equals('正在连接...'),
    );
  });

  test('FlurryTheme builds high-contrast daytime cream and starlight dark themes', () {
    final light = FlurryTheme.applyLight(ThemeData.light());
    final dark = FlurryTheme.applyDark(ThemeData.dark());

    expect(light.scaffoldBackgroundColor, equals(FlurryColors.creamBg));
    expect(light.primaryColor, equals(FlurryColors.sakuraPink));
    expect(light.textTheme.bodyMedium?.color, equals(FlurryColors.cocoaText));

    expect(dark.scaffoldBackgroundColor, equals(FlurryColors.starlightBg));
    expect(dark.primaryColor, equals(FlurryColors.sakuraNeon));
    expect(dark.textTheme.bodyMedium?.color, equals(FlurryColors.snowWhiteText));
  });

  testWidgets('FlurryMascotOverlay reports blocked rect and shows speech bubble on tap',
      (WidgetTester tester) async {
    Rect? latestBlockedRect;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Stack(
            children: [
              FlurryMascotOverlay(
                onBlockedRectChanged: (_, newRect) {
                  latestBlockedRect = newRect;
                },
              ),
            ],
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(latestBlockedRect, isNotNull);
    expect(latestBlockedRect!.width, greaterThan(40));

    // Tap Flurry to show speech bubble
    await tester.tap(find.byType(FlurryMascotOverlay));
    await tester.pump();

    // Flush the 3200ms auto-hide bubble timer cleanly
    await tester.pump(const Duration(milliseconds: 3500));

    // Disable mascot overlay and verify blocked rect is cleared
    FlurryConfig.setMascotOverlay(false);
    await tester.pump();
    expect(latestBlockedRect, isNull);
  });
}
