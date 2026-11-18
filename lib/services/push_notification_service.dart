import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../core/utils/app_error_logger.dart';
import '../core/utils/platform_actions.dart';
import '../presentation/alerts/pages/alert_management_page.dart';
import '../presentation/threat_monitoring/pages/threat_monitoring_page.dart';

class PushNotificationService {
  static const _webVapidKey =
      'BKMKQoSLh4K_hx3qn85GpalLGy6dUNg-eDkpnVTBP8QT0pVS3A2uq8XyXSn-3Q_5eHLXUEF1FSsknglBjSOgG-I';
  static const _networkAdminRole = 'role_network_admin';
  static const _systemAdminRole = 'role_system_admin';
  static const _networkAlertType = 'network_alert';
  static const _threatAlertType = 'threat_alert';

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final FirebaseMessaging _messaging;

  GlobalKey<NavigatorState>? _navigatorKey;
  GlobalKey<ScaffoldMessengerState>? _scaffoldMessengerKey;
  StreamSubscription<User?>? _authSubscription;
  StreamSubscription<String>? _tokenRefreshSubscription;
  StreamSubscription<RemoteMessage>? _foregroundMessageSubscription;
  StreamSubscription<RemoteMessage>? _openedMessageSubscription;
  String? _registeredUserId;
  String? _registeredToken;
  String? _roleId;
  String? _pendingAlertId;
  String? _pendingNotificationType;
  int _authGeneration = 0;
  Future<void> _registrationQueue = Future<void>.value();

  PushNotificationService({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    FirebaseMessaging? messaging,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance,
        _messaging = messaging ?? FirebaseMessaging.instance;

  static bool get isSupportedPlatform =>
      kIsWeb || defaultTargetPlatform == TargetPlatform.android;

  Future<void> initialize({
    required GlobalKey<NavigatorState> navigatorKey,
    required GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey,
  }) async {
    if (!isSupportedPlatform || _authSubscription != null) return;
    _navigatorKey = navigatorKey;
    _scaffoldMessengerKey = scaffoldMessengerKey;
    if (kIsWeb) _restorePendingNotificationFromUrl();

    _foregroundMessageSubscription = FirebaseMessaging.onMessage.listen(
      _handleForegroundMessage,
      onError: (Object error) =>
          AppErrorLogger.log('PushNotifications.foregroundMessage', error),
    );
    _openedMessageSubscription = FirebaseMessaging.onMessageOpenedApp.listen(
      _handleNotificationOpened,
      onError: (Object error) =>
          AppErrorLogger.log('PushNotifications.notificationOpen', error),
    );
    _tokenRefreshSubscription = _messaging.onTokenRefresh.listen(
      (token) => unawaited(_registerToken(
        token,
        expectedGeneration: _authGeneration,
      ).catchError((Object error) {
        AppErrorLogger.log('PushNotifications.tokenRefresh', error);
      })),
      onError: (Object error) =>
          AppErrorLogger.log('PushNotifications.tokenRefreshStream', error),
    );
    _authSubscription = _auth.authStateChanges().listen(
          (user) => unawaited(
            _syncUser(user, requestPermission: !kIsWeb),
          ),
          onError: (Object error) =>
              AppErrorLogger.log('PushNotifications.authStream', error),
        );

    RemoteMessage? initialMessage;
    try {
      initialMessage = await _messaging.getInitialMessage();
    } catch (error) {
      AppErrorLogger.log('PushNotifications.initialMessage', error);
      rethrow;
    }
    if (initialMessage != null) _handleNotificationOpened(initialMessage);
  }

  Future<bool> enableBrowserNotifications() async {
    if (!kIsWeb) {
      throw UnsupportedError(
          'Browser notifications are only available on web.');
    }

    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('Sign in before enabling browser notifications.');
    }

    final permission = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    if (permission.authorizationStatus != AuthorizationStatus.authorized) {
      return false;
    }

    await _syncUser(
      user,
      requestPermission: false,
      rethrowErrors: true,
    );
    return _registeredUserId == user.uid && _registeredToken != null;
  }

  Future<void> openPendingAlert() async {
    if (_pendingAlertId == null || _auth.currentUser == null) return;
    _openAlertManagement();
  }

  Future<void> dispose() async {
    await _authSubscription?.cancel();
    await _tokenRefreshSubscription?.cancel();
    await _foregroundMessageSubscription?.cancel();
    await _openedMessageSubscription?.cancel();
    _authSubscription = null;
    _tokenRefreshSubscription = null;
    _foregroundMessageSubscription = null;
    _openedMessageSubscription = null;
  }

  Future<void> unregisterCurrentDevice() async {
    if (!isSupportedPlatform) return;
    _authGeneration++;
    await _enqueueRegistration(() async {
      final userId = _registeredUserId;
      final token = _registeredToken;
      if (userId == null || token == null || _auth.currentUser?.uid != userId) {
        return;
      }

      await _deviceReference(userId, token).delete();
      _registeredUserId = null;
      _registeredToken = null;
      _roleId = null;
    });
  }

  Future<void> _syncUser(
    User? user, {
    required bool requestPermission,
    bool rethrowErrors = false,
  }) async {
    final generation = ++_authGeneration;
    if (user == null) {
      _registeredUserId = null;
      _registeredToken = null;
      _roleId = null;
      return;
    }

    try {
      final profile = await _firestore.collection('users').doc(user.uid).get();
      if (generation != _authGeneration || _auth.currentUser?.uid != user.uid) {
        return;
      }
      final data = profile.data();
      if (!profile.exists || data?['isActive'] != true) return;

      final roleId = data?['roleId'] as String?;
      if (roleId != _networkAdminRole && roleId != _systemAdminRole) return;

      final permission = requestPermission
          ? await _messaging.requestPermission(
              alert: true,
              badge: true,
              sound: true,
            )
          : await _messaging.getNotificationSettings();
      if ((permission.authorizationStatus != AuthorizationStatus.authorized &&
              permission.authorizationStatus !=
                  AuthorizationStatus.provisional) ||
          generation != _authGeneration ||
          _auth.currentUser?.uid != user.uid) {
        return;
      }

      _registeredUserId = user.uid;
      _roleId = roleId;
      final token = kIsWeb
          ? await _messaging.getToken(vapidKey: _webVapidKey)
          : await _messaging.getToken();
      if (token != null && token.isNotEmpty) {
        await _registerToken(token, expectedGeneration: generation);
      }

      if (_pendingAlertId != null) _openAlertManagement();
    } catch (error) {
      AppErrorLogger.log('PushNotifications.deviceRegistration', error);
      if (rethrowErrors) rethrow;
    }
  }

  Future<void> _registerToken(
    String token, {
    required int expectedGeneration,
  }) {
    return _enqueueRegistration(() async {
      final userId = _registeredUserId;
      if (expectedGeneration != _authGeneration ||
          userId == null ||
          _auth.currentUser?.uid != userId) {
        return;
      }

      final oldToken = _registeredToken;
      if (oldToken != null && oldToken != token) {
        await _deviceReference(userId, oldToken).delete();
      }
      if (expectedGeneration != _authGeneration ||
          _auth.currentUser?.uid != userId) {
        return;
      }
      await _deviceReference(userId, token).set({
        'token': token,
        'platform': kIsWeb ? 'web' : 'android',
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      _registeredToken = token;
    });
  }

  Future<void> _enqueueRegistration(
    Future<void> Function() operation,
  ) {
    final result = _registrationQueue.then((_) => operation());
    _registrationQueue = result.then<void>(
      (_) {},
      onError: (Object error, StackTrace stackTrace) {
        AppErrorLogger.log('PushNotifications.registrationQueue', error);
      },
    );
    return result;
  }

  DocumentReference<Map<String, dynamic>> _deviceReference(
    String userId,
    String token,
  ) {
    final tokenId = sha256.convert(utf8.encode(token)).toString();
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('devices')
        .doc(tokenId);
  }

  void _handleForegroundMessage(RemoteMessage message) {
    final type = message.data['type'];
    if (type != _networkAlertType && type != _threatAlertType) return;

    final notification = message.notification;
    final title = notification?.title ?? 'Network alert';
    final body = notification?.body ?? 'A new network alert was created.';
    if (kIsWeb) {
      showPlatformNotification(
        title: title,
        body: body,
        tag: message.data['alertId'] ??
            message.data['assessmentId'] ??
            'netvision-alert',
        clickUrl: _notificationClickUrl(message),
      );
    }
    if (type == _networkAlertType && _roleId == _networkAdminRole) return;

    _scaffoldMessengerKey?.currentState?.showSnackBar(
      SnackBar(
        content: Text('$title: $body'),
        action: SnackBarAction(
          label: 'View',
          onPressed: _openAlertManagement,
        ),
      ),
    );
  }

  void _handleNotificationOpened(RemoteMessage message) {
    final type = message.data['type'];
    if (type != _networkAlertType && type != _threatAlertType) return;
    _pendingNotificationType = type;
    _pendingAlertId = type == _threatAlertType
        ? message.data['assessmentId'] as String?
        : message.data['alertId'] as String?;
    if (_auth.currentUser != null) _openAlertManagement();
  }

  void _restorePendingNotificationFromUrl() {
    final query = Uri.base.queryParameters;
    final type = query['notificationType'];
    if (type != _networkAlertType && type != _threatAlertType) return;

    final alertId =
        type == _threatAlertType ? query['assessmentId'] : query['alertId'];
    if (alertId == null || alertId.isEmpty) return;
    _pendingNotificationType = type;
    _pendingAlertId = alertId;
  }

  String _notificationClickUrl(RemoteMessage message) {
    final type = message.data['type'] as String;
    final alertId = type == _threatAlertType
        ? message.data['assessmentId'] as String?
        : message.data['alertId'] as String?;
    return Uri.base.replace(queryParameters: {
      ...Uri.base.queryParameters,
      'notificationType': type,
      if (alertId != null && alertId.isNotEmpty)
        type == _threatAlertType ? 'assessmentId' : 'alertId': alertId,
    }).toString();
  }

  void _openAlertManagement() {
    if (_pendingAlertId == null) return;
    final navigator = _navigatorKey?.currentState;
    if (navigator == null) return;

    _pendingAlertId = null;
    final notificationType = _pendingNotificationType;
    _pendingNotificationType = null;
    navigator.push(
      MaterialPageRoute<void>(
        builder: (_) => notificationType == _threatAlertType
            ? const ThreatMonitoringPage()
            : const AlertManagementPage(),
      ),
    );
  }
}
