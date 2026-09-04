import 'package:cloud_functions/cloud_functions.dart';

import 'callable_failure.dart';

class SyncException implements Exception {
  const SyncException(this.message);

  final String message;

  @override
  String toString() => message;
}

String describeSyncFailure(String code, String? message) {
  return plainCallableFailure(code, message) ??
      'Could not check your mail right now. Pull down to try again.';
}

class SyncService {
  SyncService({FirebaseFunctions? functions})
    : _functions = functions ?? FirebaseFunctions.instance;

  final FirebaseFunctions _functions;

  Future<int> syncNow() async {
    try {
      final result = await _functions
          .httpsCallable('syncNow')
          .call<Map<String, dynamic>>(<String, dynamic>{});
      return (result.data['written'] as num?)?.toInt() ?? 0;
    } on FirebaseFunctionsException catch (error) {
      throw SyncException(describeSyncFailure(error.code, error.message));
    }
  }
}
