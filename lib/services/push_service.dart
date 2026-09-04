import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../features/companies/presentation/widget_feed.dart';
import '../firebase_options.dart';
import '../models/company.dart';
import '../models/student_company_status.dart';
import 'home_widget_service.dart';
import 'notification_route.dart';
export 'notification_route.dart' show refreshWidgetAction;

@pragma('vm:entry-point')
Future<void> orbitBackgroundMessageHandler(RemoteMessage message) async {
  if (message.data['orbitAction'] != refreshWidgetAction) {
    return;
  }
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    await republishWidget();
  } on Object catch (error) {
    debugPrint('background widget refresh skipped: $error');
  }
}

Future<void> republishWidget() async {
  const homeWidget = HomeWidgetService();
  if (!homeWidget.isSupported) {
    return;
  }

  final studentId = FirebaseAuth.instance.currentUser?.uid;
  if (studentId == null) {
    return;
  }

  final firestore = FirebaseFirestore.instance;
  final companies = await firestore.collection('companies').get();
  final statuses = await firestore
      .collection('studentCompanyStatus')
      .where('studentId', isEqualTo: studentId)
      .get();

  final byCompany = <String, StudentCompanyStatus>{};
  for (final doc in statuses.docs) {
    final status = StudentCompanyStatus.fromFirestore(doc);
    byCompany[status.companyId] = status;
  }

  await homeWidget.publish(
    buildWidgetFeed(
      companies: companies.docs.map(Company.fromFirestore).toList(),
      statusesByCompanyId: byCompany,
    ),
  );
}

const AndroidNotificationChannel orbitUpdatesChannel = AndroidNotificationChannel(
  'orbit_updates',
  'Drive updates',
  description: 'Round results, new rounds, and drives that need a step from you.',
  importance: Importance.defaultImportance,
);

const AndroidNotificationChannel orbitDeadlinesChannel =
    AndroidNotificationChannel(
      'orbit_deadlines',
      'Closing within the hour',
      description: 'A drive you have not finished closes in under an hour.',
      importance: Importance.max,
    );

class PushService {
  PushService({FirebaseFirestore? firestore, FirebaseMessaging? messaging})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _messaging = messaging ?? FirebaseMessaging.instance;

  final FirebaseFirestore _firestore;
  final FirebaseMessaging _messaging;
  final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();

  StreamSubscription<String>? _refreshSubscription;
  StreamSubscription<RemoteMessage>? _openedSubscription;
  String? _studentId;

  Future<void> start(String studentId) async {
    if (_studentId == studentId) {
      return;
    }
    _studentId = studentId;

    try {
      await _createChannels();

      FirebaseMessaging.onBackgroundMessage(orbitBackgroundMessageHandler);
      FirebaseMessaging.onMessage.listen((message) {
        if (message.data['orbitAction'] == refreshWidgetAction) {
          republishWidget();
        }
      });

      await _openedSubscription?.cancel();
      _openedSubscription = FirebaseMessaging.onMessageOpenedApp.listen(
        (message) => rememberTappedCompany(message.data),
      );

      final launchedBy = await _messaging.getInitialMessage();
      if (launchedBy != null) {
        rememberTappedCompany(launchedBy.data);
      }

      final settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        return;
      }

      final token = await _messaging.getToken();
      if (token != null) {
        await _saveToken(studentId, token);
      }

      await _refreshSubscription?.cancel();
      _refreshSubscription = _messaging.onTokenRefresh.listen((next) {
        _saveToken(studentId, next);
      });
    } on Object catch (error) {
      debugPrint('push registration skipped: $error');
    }
  }

  Future<void> stop() async {
    await _refreshSubscription?.cancel();
    _refreshSubscription = null;
    await _openedSubscription?.cancel();
    _openedSubscription = null;
    final studentId = _studentId;
    _studentId = null;
    if (studentId == null) {
      return;
    }
    try {
      final token = await _messaging.getToken();
      if (token != null) {
        await _firestore.collection('students').doc(studentId).update({
          'fcmTokens': FieldValue.arrayRemove(<String>[token]),
        });
      }
      await _messaging.deleteToken();
    } on Object catch (error) {
      debugPrint('push teardown skipped: $error');
    }
  }

  Future<void> _createChannels() async {
    final android = _local
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (android == null) {
      return;
    }
    await android.createNotificationChannel(orbitUpdatesChannel);
    await android.createNotificationChannel(orbitDeadlinesChannel);
  }

  Future<void> _saveToken(String studentId, String token) async {
    try {
      await _firestore.collection('students').doc(studentId).update({
        'fcmTokens': FieldValue.arrayUnion(<String>[token]),
      });
    } on Object catch (error) {
      debugPrint('token save skipped: $error');
    }
  }
}
