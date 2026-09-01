import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/widgets.dart';

import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import '../constants/app_constants.dart';

enum SessionStatus { loading, signedOut, needsOnboarding, ready }

class SessionController extends ChangeNotifier {
  SessionController({
    AuthService? authService,
    FirestoreService? firestoreService,
  }) : _authService = authService ?? AuthService(),
       _firestoreService = firestoreService ?? FirestoreService() {
    _subscription = _authService.idTokenChanges().listen(_handleUserChanged);
  }

  final AuthService _authService;
  final FirestoreService _firestoreService;

  StreamSubscription<User?>? _subscription;
  int _resolutionId = 0;

  SessionStatus _status = SessionStatus.loading;
  User? _user;
  bool _isAdmin = false;

  SessionStatus get status => _status;
  User? get user => _user;
  bool get isAdmin => _isAdmin;

  Future<void> _handleUserChanged(User? user) async {
    final resolutionId = ++_resolutionId;

    if (user == null) {
      _apply(resolutionId, SessionStatus.signedOut, user: null, isAdmin: false);
      return;
    }

    if (!AppConstants.isAllowedEmail(user.email)) {
      await _authService.signOut();
      return;
    }

    _user = user;

    try {
      final exists = await _firestoreService.studentExists(user.uid);
      final isAdmin = await _authService.hasAdminClaim();
      _apply(
        resolutionId,
        exists ? SessionStatus.ready : SessionStatus.needsOnboarding,
        user: user,
        isAdmin: isAdmin,
      );
    } catch (_) {
      _apply(
        resolutionId,
        SessionStatus.needsOnboarding,
        user: user,
        isAdmin: false,
      );
    }
  }

  void _apply(
    int resolutionId,
    SessionStatus status, {
    required User? user,
    required bool isAdmin,
  }) {
    if (resolutionId != _resolutionId) {
      return;
    }
    _status = status;
    _user = user;
    _isAdmin = isAdmin;
    notifyListeners();
  }

  Future<void> refresh() async {
    await _handleUserChanged(_authService.currentUser);
  }

  Future<void> signOut() => _authService.signOut();

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}

class SessionScope extends InheritedNotifier<SessionController> {
  const SessionScope({
    super.key,
    required SessionController controller,
    required super.child,
  }) : super(notifier: controller);

  static SessionController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<SessionScope>();
    assert(scope?.notifier != null, 'No SessionScope found in context');
    return scope!.notifier!;
  }
}
