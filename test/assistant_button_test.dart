import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit/core/theme/app_theme.dart';
import 'package:orbit/core/theme/app_tokens.dart';
import 'package:orbit/features/assistant/presentation/assistant_button.dart';
import 'package:orbit/services/assistant_service.dart';

class _SlowService extends AssistantService {
  _SlowService(this.answer);

  final String answer;

  @override
  Future<AssistantAnswer> ask({String? presetId, String? text}) async {
    return AssistantAnswer(question: 'What am I missing right now?', answer: answer);
  }
}

const Key navBarKey = Key('nav-bar');

Widget harness({double navBarHeight = 64, AssistantService? service}) {
  return MaterialApp(
    theme: AppTheme.light,
    builder: (context, child) => OrbitTheme(
      colors: OrbitColors.light,
      child: child ?? const SizedBox.shrink(),
    ),
    home: Scaffold(
      body: const SizedBox.expand(),
      floatingActionButton: AssistantButton(service: service),
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

  testWidgets('every preset is reachable in the chip row', (tester) async {
    await tester.pumpWidget(harness());
    await tester.tap(find.byType(AssistantButton));
    await tester.pumpAndSettle();

    expect(assistantPresets.length, 5);
    for (final preset in assistantPresets) {
      await tester.scrollUntilVisible(
        find.text(preset.label),
        120,
        scrollable: find.descendant(
          of: find.byKey(assistantChipsKey),
          matching: find.byType(Scrollable),
        ),
      );
      expect(find.text(preset.label), findsOneWidget);
    }
  });

  testWidgets('a long answer scrolls while the chips and input stay put', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 480);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final longAnswer = List.generate(
      60,
      (i) => 'Line $i of an answer that is far too long for a small screen.',
    ).join(' ');

    await tester.pumpWidget(harness(service: _SlowService(longAnswer)));
    await tester.tap(find.byType(AssistantButton));
    await tester.pumpAndSettle();

    await tester.tap(find.text(assistantPresets.first.label).first);
    await tester.pumpAndSettle();

    expect(find.byKey(assistantMessagesKey), findsOneWidget);
    expect(find.byKey(assistantChipsKey), findsOneWidget);
    expect(find.byKey(assistantInputKey), findsOneWidget);

    final scrollable = find.descendant(
      of: find.byKey(assistantMessagesKey),
      matching: find.byType(Scrollable),
    );
    final position = tester.state<ScrollableState>(scrollable).position;
    expect(
      position.maxScrollExtent,
      greaterThan(0),
      reason: 'the answer must actually overflow for this test to mean anything',
    );

    final chipsBefore = tester.getRect(find.byKey(assistantChipsKey));
    final inputBefore = tester.getRect(find.byKey(assistantInputKey));

    position.jumpTo(position.maxScrollExtent);
    await tester.pumpAndSettle();

    expect(tester.getRect(find.byKey(assistantChipsKey)), chipsBefore);
    expect(tester.getRect(find.byKey(assistantInputKey)), inputBefore);
  });

  testWidgets('the panel never exceeds the screen on a 320x480 device', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 480);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final longAnswer = List.generate(
      60,
      (i) => 'Line $i of a very long answer indeed.',
    ).join(' ');

    await tester.pumpWidget(harness(service: _SlowService(longAnswer)));
    await tester.tap(find.byType(AssistantButton));
    await tester.pumpAndSettle();
    await tester.tap(find.text(assistantPresets.first.label).first);
    await tester.pumpAndSettle();

    final input = tester.getRect(find.byKey(assistantInputKey));
    expect(input.bottom, lessThanOrEqualTo(480));
    expect(input.top, greaterThanOrEqualTo(0));
  });
}
