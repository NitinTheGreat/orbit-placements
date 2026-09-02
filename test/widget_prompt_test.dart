import 'package:flutter_test/flutter_test.dart';
import 'package:orbit/features/home/presentation/widget_prompt.dart';

void main() {
  group('prompt frequency', () {
    test('shows on every third open while not installed', () {
      final shown = <int>[];
      var promptsShown = 0;
      for (var opens = 1; opens <= 20; opens++) {
        final state = WidgetPromptState(
          opens: opens,
          promptsShown: promptsShown,
        );
        if (shouldPromptForWidget(state)) {
          shown.add(opens);
          promptsShown += 1;
        }
      }
      expect(shown, [3, 6, 9, 12, 15]);
    });

    test('stops permanently after five prompts', () {
      expect(
        shouldPromptForWidget(
          const WidgetPromptState(opens: 18, promptsShown: maxWidgetPrompts),
        ),
        isFalse,
      );
      expect(
        shouldPromptForWidget(
          const WidgetPromptState(opens: 300, promptsShown: 9),
        ),
        isFalse,
      );
    });

    test('never shows on a non-multiple open', () {
      for (final opens in [1, 2, 4, 5, 7, 8]) {
        expect(
          shouldPromptForWidget(WidgetPromptState(opens: opens)),
          isFalse,
          reason: 'open $opens should be quiet',
        );
      }
    });

    test('the very first open is quiet', () {
      expect(shouldPromptForWidget(const WidgetPromptState()), isFalse);
      expect(
        shouldPromptForWidget(const WidgetPromptState(opens: 0)),
        isFalse,
      );
    });
  });

  group('stopping conditions', () {
    test('installing stops it immediately, even on a third open', () {
      expect(
        shouldPromptForWidget(
          const WidgetPromptState(opens: 3, installed: true),
        ),
        isFalse,
      );
    });

    test('installing wins over any prompt count', () {
      expect(
        promptingIsFinished(
          const WidgetPromptState(opens: 3, promptsShown: 1, installed: true),
        ),
        isTrue,
      );
    });

    test('asking to stop is honoured forever', () {
      expect(
        shouldPromptForWidget(
          const WidgetPromptState(opens: 9, dismissedForever: true),
        ),
        isFalse,
      );
      expect(
        promptingIsFinished(
          const WidgetPromptState(dismissedForever: true),
        ),
        isTrue,
      );
    });

    test('an unfinished state is not treated as finished', () {
      expect(
        promptingIsFinished(const WidgetPromptState(opens: 3, promptsShown: 1)),
        isFalse,
      );
    });

    test('the cap is exactly five, not four or six', () {
      expect(
        shouldPromptForWidget(
          const WidgetPromptState(opens: 15, promptsShown: 4),
        ),
        isTrue,
      );
      expect(
        shouldPromptForWidget(
          const WidgetPromptState(opens: 18, promptsShown: 5),
        ),
        isFalse,
      );
    });
  });
}
