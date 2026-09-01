import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/widgets.dart';

import '../../models/gmail_sync.dart';
import '../../models/student.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import '../constants/app_constants.dart';
import 'session_status.dart';

class SessionController extends ChangeNotifier {
  SessionController({
    AuthService? authService,
    FirestoreService? firestoreService,
  }) : _authService = authService ?? AuthService(),
       _firestoreService = firestoreService ?? FirestoreService() {
    _authSubscription = _authService.idTokenChanges().listen(_handleUserChanged);
  }

  final AuthService _authService;
  final FirestoreService _firestoreService;

  StreamSubscription<User?>? _authSubscription;
  StreamSubscription<Student?>? _studentSubscription;

  SessionStatus _status = SessionStatus.loading;
  User? _user;
  Student? _student;
  bool _isAdmin = false;

  SessionStatus get status => _status;
  User? get user => _user;
  Student? get student => _student;
  bool get isAdmin => _isAdmin;

  GmailSync get gmailSync => _student?.gmailSync ?? const GmailSync();

  Future<void> _handleUserChanged(User? user) async {
    await _studentSubscription?.cancel();
    _studentSubscription = null;

    if (user == null) {
      _user = null;
      _student = null;
      _isAdmin = false;
      _setStatus(SessionStatus.signedOut);
      return;
    }

    if (!AppConstants.isAllowedEmail(user.email)) {
      await _authService.signOut();
      return;
    }

    _user = user;
    _isAdmin = await _authService.hasAdminClaim();

    _studentSubscription = _firestoreService
        .watchStudent(user.uid)
        .listen(_handleStudentChanged, onError: _handleStudentError);
  }

  void _handleStudentChanged(Student? student) {
    _student = student;
    _setStatus(
      resolveSessionStatus(
        signedIn: _user != null,
        hasProfile: student != null,
        gmailStatus: student?.gmailSync.status ?? GmailConnectionStatus.none,
      ),
    );
  }

  void _handleStudentError(Object error) {
    _student = null;
    _setStatus(
      _user == null ? SessionStatus.signedOut : SessionStatus.needsOnboarding,
    );
  }

  void _setStatus(SessionStatus status) {
    _status = status;
    notifyListeners();
  }

  Future<void> refreshAdminClaim() async {
    _isAdmin = await _authService.hasAdminClaim(forceRefresh: true);
    notifyListeners();
  }

  Future<void> signOut() => _authService.signOut();

  @override
  void dispose() {
    _authSubscription?.cancel();
    _studentSubscription?.cancel();
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
