import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit/core/theme/app_theme.dart';
import 'package:orbit/core/theme/app_tokens.dart';
import 'package:orbit/features/assistant/presentation/assistant_button.dart';
import 'package:orbit/services/assistant_service.dart';

const Key navBarKey = Key('nav-bar');

Widget harness({double navBarHeight = 64}) {
  return MaterialApp(
    theme: AppTheme.light,
    builder: (context, child) => OrbitTheme(
      colors: OrbitColors.light,
      child: child ?? const SizedBox.shrink(),
    ),
    home: Scaffold(
      body: const SizedBox.expand(),
      floatingActionButton: const AssistantButton(),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      bottomNavigationBar: SizedBox(
        key: navBarKey,
        height: navBarHeight,
        child: const ColoredBox(color: Color(0xFFEEEEEE)),
      ),
    ),
  );
}

void main() {
  testWidgets('the button clears the bottom nav bar on a 320x480 screen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 480);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(harness());
    await tester.pump();

    final button = tester.getRect(find.byType(AssistantButton));
    final navBar = tester.getRect(find.byKey(navBarKey));

    expect(
      button.overlaps(navBar),
      isFalse,
      reason: 'button $button must not overlap nav bar $navBar',
    );
    expect(button.bottom, lessThanOrEqualTo(navBar.top));
  });

  testWidgets('the button stays on screen on a 320x480 screen', (tester) async {
    tester.view.physicalSize = const Size(320, 480);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(harness());
    await tester.pump();

    final button = tester.getRect(find.byType(AssistantButton));
    expect(button.left, greaterThanOrEqualTo(0));
    expect(button.right, lessThanOrEqualTo(320));
    expect(button.top, greaterThanOrEqualTo(0));
  });

  testWidgets('it still clears a taller nav bar', (tester) async {
    tester.view.physicalSize = const Size(320, 480);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(harness(navBarHeight: 96));
    await tester.pump();

    final button = tester.getRect(find.byType(AssistantButton));
    final navBar = tester.getRect(find.byKey(navBarKey));
    expect(button.overlaps(navBar), isFalse);
  });

  testWidgets('tapping it opens a panel, not a full screen', (tester) async {
    await tester.pumpWidget(harness());
    await tester.tap(find.byType(AssistantButton));
    await tester.pumpAndSettle();

    expect(find.text('Ask Orbit'), findsOneWidget);
    expect(
      find.text('Orbit answers from your own drives only.'),
      findsOneWidget,
    );

    final panel = tester.getRect(find.text('Ask Orbit'));
    expect(panel.top, greaterThan(0));
  });

  testWidgets('every preset is offered as a chip', (tester) async {
    await tester.pumpWidget(harness());
    await tester.tap(find.byType(AssistantButton));
    await tester.pumpAndSettle();

    for (final preset in assistantPresets) {
      expect(find.text(preset.label), findsOneWidget);
    }
    expect(assistantPresets.length, 5);
  });
}
