import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_hbb/mobile/flurry/flurry_mascot_overlay.dart';
import 'package:flutter_hbb/mobile/flurry/flurry_strings.dart';
import 'package:flutter_hbb/mobile/flurry/flurry_theme.dart';
import 'package:flutter_hbb/mobile/flurry/flurry_todesk_mouse_core.dart';

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

  testWidgets('ToDesk FloatingMouse dispatches stationary trackpad move, clicks, lock, and +1/-1 scroll',
      (WidgetTester tester) async {
    final moves = <(double, double)>[];
    final buttons = <(FlurryMouseButton, bool)>[];
    final scrolls = <int>[];
    Rect? reportedRect;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 400,
            height: 800,
            child: Stack(
              children: [
                FlurryToDeskMouseCore(
                  onRectChanged: (r) => reportedRect = r,
                  onTrackpadDelta: (dx, dy) => moves.add((dx, dy)),
                  onButtonAction: (btn, down) => buttons.add((btn, down)),
                  onScrollNotch: (delta) => scrolls.add(delta),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(reportedRect, isNotNull);
    // Verify stationary widget initial position
    final initialTopLeft = tester.getTopLeft(find.byType(FlurryToDeskMouseCore));

    // 1. Pan on trackpad: dispatches movement without moving widget!
    final trackpadHint = find.textContaining('触控移光标');
    expect(trackpadHint, findsOneWidget);
    await tester.drag(trackpadHint, const Offset(30, -20));
    await tester.pump();
    expect(moves, isNotEmpty);
    expect(tester.getTopLeft(find.byType(FlurryToDeskMouseCore)), equals(initialTopLeft));

    // 2. Tap Left & Right buttons
    await tester.tap(find.text('左键'));
    await tester.pump();
    expect(buttons, containsAllInOrder([(FlurryMouseButton.left, true), (FlurryMouseButton.left, false)]));

    buttons.clear();
    await tester.tap(find.text('右键'));
    await tester.pump();
    expect(buttons, containsAllInOrder([(FlurryMouseButton.right, true), (FlurryMouseButton.right, false)]));

    // 3. Drag-Lock toggle via lock icon
    buttons.clear();
    await tester.tap(find.byIcon(Icons.lock_open_rounded));
    await tester.pump();
    expect(find.text('锁定中'), findsOneWidget);
    expect(buttons, equals([(FlurryMouseButton.left, true)]));

    // Tap left button to release lock
    await tester.tap(find.text('锁定中'));
    await tester.pump();
    expect(find.text('左键'), findsOneWidget);
    expect(buttons.last, equals((FlurryMouseButton.left, false)));

    // 4. Scroll wheel notches (+1 / -1)
    await tester.tap(find.byIcon(Icons.keyboard_arrow_up_rounded));
    await tester.pump();
    expect(scrolls, contains(1));

    await tester.tap(find.byIcon(Icons.keyboard_arrow_down_rounded));
    await tester.pump();
    expect(scrolls, contains(-1));

    // 5. Collapse to Flurry orb and expand back
    await tester.tap(find.byIcon(Icons.close_fullscreen_rounded));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('左键'), findsNothing);

    await tester.tap(find.byIcon(Icons.mouse_rounded));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('左键'), findsOneWidget);
  });
}
