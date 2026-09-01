import 'package:firebase_core/firebase_core.dart';

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    throw UnsupportedError(
      'Firebase is not configured yet. Run "flutterfire configure" from the '
      'project root to generate lib/firebase_options.dart, which replaces '
      'this placeholder.',
    );
  }
}
