import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:core/core.dart';

class CustomerPushService {
  static final instance = CustomerPushService._();
  CustomerPushService._();
  final navigatorKey = GlobalKey<NavigatorState>();
  String? _pendingSession;
  bool _opening = false;
  String? _readyUid;
  final List<SessionAlarm> _foregroundAlerts = [];
  bool _showingAlert = false;

  Future<void> _showForegroundAlert(SessionAlarm alert) async {
    if (WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed)
      return;
    _foregroundAlerts.add(alert);
    if (_showingAlert) return;
    _showingAlert = true;
    try {
      while (_foregroundAlerts.isNotEmpty) {
        final next = _foregroundAlerts.removeAt(0);
        final uid = FirebaseAuth.instance.currentUser?.uid;
        if (uid == null) continue;
        final session = await FirebaseFirestore.instance
            .doc('sessions/${next.sessionId}')
            .get();
        final context = navigatorKey.currentContext;
        if (session.data()?['customerId'] != uid ||
            FirebaseAuth.instance.currentUser?.uid != uid ||
            context == null ||
            !context.mounted ||
            WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed)
          continue;
        final open = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
                  title: Text(next.title),
                  content: Text(next.body),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        child: const Text('Đã hiểu')),
                    FilledButton(
                        onPressed: () => Navigator.of(context).pop(true),
                        child: const Text('Xem phiên bàn')),
                  ],
                ));
        if (open == true) openSession(next.sessionId);
      }
    } catch (error) {
      debugPrint('Cannot display foreground alert: $error');
    } finally {
      _showingAlert = false;
    }
  }

  Future<void> accountReady(String uid) async {
    if (_readyUid == uid) return;
    _readyUid = uid;
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null && FirebaseAuth.instance.currentUser?.uid == uid) {
        await _saveToken(token);
      }
    } catch (error) {
      _readyUid = null;
      debugPrint('Push registration failed: $error');
    }
  }

  Future<void> init() async {
    AlarmService.instance.alerts
        .listen((alert) => unawaited(_showForegroundAlert(alert)));
    await FirebaseMessaging.instance.requestPermission();
    FirebaseMessaging.onMessageOpenedApp.listen(_openMessage);
    FirebaseMessaging.onMessage.listen((message) {
      if (message.data['customerId'] != FirebaseAuth.instance.currentUser?.uid)
        return;
      final sessionId = message.data['sessionId'];
      if (sessionId != null) {
        unawaited(AlarmService.instance.triggerDirectAlert(
          sessionId: sessionId,
          title: message.notification?.title ?? 'Yêu cầu nhả bàn',
          body: message.notification?.body ?? '',
          alertId: message.data['requestId'],
        ));
      }
    });
    await AlarmService.instance.init(onSelectNotification: openSession);
    FirebaseMessaging.instance.onTokenRefresh.listen(_saveToken);
    FirebaseAuth.instance.authStateChanges().asyncMap((user) async {
      try {
        if (user == null) {
          _readyUid = null;
          _pendingSession = null;
          await FirebaseMessaging.instance.deleteToken();
          return;
        }
        final token = await FirebaseMessaging.instance.getToken();
        if (token != null &&
            FirebaseAuth.instance.currentUser?.uid == user.uid) {
          await _saveToken(token);
        }
      } catch (error) {
        debugPrint('Push registration failed: $error');
      }
    }).listen((_) {});
    final initial = await FirebaseMessaging.instance.getInitialMessage();
    if (initial != null) _openMessage(initial);
  }

  Future<void> _saveToken(String token) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      await FirebaseFirestore.instance.doc('users/$uid').update({
        'fcmTokens': FieldValue.arrayUnion([token]),
      });
    } catch (error) {
      debugPrint('Push token save failed: $error');
    }
  }

  void _openMessage(RemoteMessage message) =>
      openSession(message.data['sessionId']);

  void openSession(String? sessionId) {
    _pendingSession = sessionId;
    unawaited(openPending());
  }

  Future<void> openPending() async {
    final sessionId = _pendingSession;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final navigator = navigatorKey.currentState;
    if (_opening || sessionId == null || uid == null || navigator == null)
      return;
    _opening = true;
    try {
      final doc =
          await FirebaseFirestore.instance.doc('sessions/$sessionId').get();
      if (FirebaseAuth.instance.currentUser?.uid != uid) return;
      _pendingSession = null;
      if (doc.data()?['customerId'] == uid && navigator.mounted) {
        navigator.pushNamed('/session', arguments: sessionId);
      }
    } catch (error) {
      debugPrint('Cannot open notification session: $error');
    } finally {
      _opening = false;
    }
  }
}
