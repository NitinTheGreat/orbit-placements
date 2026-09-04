import 'package:cloud_functions/cloud_functions.dart';

import 'callable_failure.dart';

class AssistantPreset {
  const AssistantPreset(this.id, this.label);

  final String id;
  final String label;
}

const List<AssistantPreset> assistantPresets = <AssistantPreset>[
  AssistantPreset('due_24h', "What's due in the next 24 hours?"),
  AssistantPreset('missing_now', "What am I missing right now?"),
  AssistantPreset('changed_since_yesterday', "What's changed since yesterday?"),
  AssistantPreset('active_drives', 'Which drives am I actively in?'),
  AssistantPreset('new_unreviewed', "New companies I haven't reviewed"),
];

String describeAssistantFailure(String code, String? message) {
  if (code == 'resource-exhausted') {
    return 'You have used up your questions for today. Try again tomorrow.';
  }
  if (code == 'unauthenticated') {
    return 'Sign in again to ask Orbit.';
  }
  if (code == 'permission-denied') {
    return 'Ask Orbit is only available to VIT student accounts.';
  }
  return plainCallableFailure(code, message) ??
      'Orbit could not answer that right now. Please try again.';
}

class AssistantException implements Exception {
  const AssistantException(this.message, {this.rateLimited = false});

  final String message;
  final bool rateLimited;

  @override
  String toString() => message;
}

class AssistantAnswer {
  const AssistantAnswer({required this.question, required this.answer});

  final String question;
  final String answer;
}

class AssistantService {
  AssistantService({FirebaseFunctions? functions}) : _injected = functions;

  final FirebaseFunctions? _injected;

  FirebaseFunctions get _functions => _injected ?? FirebaseFunctions.instance;

  Future<AssistantAnswer> ask({String? presetId, String? text}) async {
    try {
      final result = await _functions
          .httpsCallable('askOrbit')
          .call<Map<String, dynamic>>(<String, dynamic>{
            'presetId': ?presetId,
            if (text != null && text.trim().isNotEmpty) 'text': text.trim(),
          });

      final data = result.data;
      return AssistantAnswer(
        question: data['question'] as String? ?? '',
        answer: data['answer'] as String? ?? '',
      );
    } on FirebaseFunctionsException catch (error) {
      throw AssistantException(
        describeAssistantFailure(error.code, error.message),
        rateLimited: error.code == 'resource-exhausted',
      );
    }
  }
}
