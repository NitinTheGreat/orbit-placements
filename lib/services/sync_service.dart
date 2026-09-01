import 'package:cloud_functions/cloud_functions.dart';

class SyncException implements Exception {
  const SyncException(this.message);

  final String message;

  @override
  String toString() => message;
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
      throw SyncException(
        error.message ?? 'Could not check your mail right now.',
      );
    }
  }
}
