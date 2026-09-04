import 'package:flutter_test/flutter_test.dart';
import 'package:orbit/services/assistant_service.dart';

void main() {
  group('assistant failure messages', () {
    test('a server outage never shows a raw code', () {
      for (final code in ['internal', 'unavailable', 'deadline-exceeded', 'unknown']) {
        final message = describeAssistantFailure(code, 'INTERNAL');
        expect(message, contains('cannot reach the server'));
        expect(message, isNot(contains('INTERNAL')));
      }
    });

    test('the rate limit says what to do', () {
      expect(
        describeAssistantFailure('resource-exhausted', 'RESOURCE_EXHAUSTED'),
        contains('questions for today'),
      );
    });

    test('an auth failure asks for sign in', () {
      expect(describeAssistantFailure('unauthenticated', null), contains('Sign in'));
    });

    test('a bare uppercase code is never surfaced', () {
      expect(describeAssistantFailure('something-new', 'NOT_FOUND'), isNot(contains('NOT_FOUND')));
      expect(describeAssistantFailure('something-new', null), contains('could not answer'));
      expect(describeAssistantFailure('something-new', ''), contains('could not answer'));
    });

    test('a genuine human sentence from the server is kept', () {
      expect(
        describeAssistantFailure('failed-precondition', 'Finish onboarding first.'),
        'Finish onboarding first.',
      );
      expect(
        describeAssistantFailure('something-new', 'The drive you asked about is gone.'),
        'The drive you asked about is gone.',
      );
    });
  });
}
