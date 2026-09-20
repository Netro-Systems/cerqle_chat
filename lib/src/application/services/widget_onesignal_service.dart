import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';

/// Result of checking notification permission when a visitor opens chat.
enum CerqleNotificationPermissionResult {
  granted,
  cannotRequest,
}

/// Manages OneSignal device registration, identity, and push notification clicks.
final class WidgetOneSignalService {
  WidgetOneSignalService();

  static final WidgetOneSignalService instance = WidgetOneSignalService();

  late final StreamController<Map<String, dynamic>> _notificationClicks =
      StreamController<Map<String, dynamic>>.broadcast(
    onListen: () {
      if (_pendingNotificationClick != null) {
        Future.microtask(() {
          if (_pendingNotificationClick != null) {
            _notificationClicks.add(_pendingNotificationClick!);
            _pendingNotificationClick = null;
          }
        });
      }
    },
  );

  final StreamController<Map<String, dynamic>> _foregroundNotifications =
      StreamController<Map<String, dynamic>>.broadcast();

  Map<String, dynamic>? _pendingNotificationClick;
  bool _initialized = false;
  String? _initializedAppId;
  String? _loggedInExternalId;
  Future<bool>? _permissionRequest;
  Future<CerqleNotificationPermissionResult>? _chatOpenPermissionRequest;
  bool? _permissionGranted;

  /// Stream of data payloads from tapped push notifications.
  Stream<Map<String, dynamic>> get notificationClicks =>
      _notificationClicks.stream;

  /// Stream of data payloads from notifications arriving while the app is in the foreground.
  Stream<Map<String, dynamic>> get foregroundNotifications =>
      _foregroundNotifications.stream;

  /// Whether OneSignal has been successfully initialized.
  bool get isInitialized => _initialized;

  /// Initializes OneSignal with [appId] and attaches notification click listeners.
  Future<void> initialize({required String appId}) async {
    if (appId.trim().isEmpty) return;
    if (_initialized && _initializedAppId == appId) return;

    _initialized = true;
    _initializedAppId = appId;

    try {
      if (kDebugMode) {
        OneSignal.Debug.setLogLevel(OSLogLevel.verbose);
      }
      await OneSignal.initialize(appId);
      OneSignal.Notifications.addClickListener(_onNotificationClick);
      OneSignal.Notifications.addForegroundWillDisplayListener(
        _onForegroundWillDisplay,
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[Cerqle] OneSignal initialization failed: $e');
      }
      _initialized = false;
      _initializedAppId = null;
    }
  }

  /// Requests push notification permission and opts in to push subscription.
  Future<void> requestPermission() async {
    await _ensureNotificationPermission();
  }

  /// Checks live platform permission and requests it when the native prompt is
  /// still available.
  ///
  /// Unlike [requestPermission], this deliberately does not trust the cached
  /// startup result because the user may have changed permission in Settings.
  Future<CerqleNotificationPermissionResult> requestPermissionForChatOpen() {
    final active = _chatOpenPermissionRequest;
    if (active != null) return active;

    final request = _requestPermissionForChatOpen();
    _chatOpenPermissionRequest = request;
    return request.whenComplete(() {
      if (identical(_chatOpenPermissionRequest, request)) {
        _chatOpenPermissionRequest = null;
      }
    });
  }

  Future<CerqleNotificationPermissionResult>
      _requestPermissionForChatOpen() async {
    if (!_initialized) {
      return CerqleNotificationPermissionResult.cannotRequest;
    }

    try {
      if (OneSignal.Notifications.permission) {
        await OneSignal.User.pushSubscription.optIn();
        _permissionGranted = true;
        return CerqleNotificationPermissionResult.granted;
      }

      if (!await OneSignal.Notifications.canRequest()) {
        _permissionGranted = false;
        return CerqleNotificationPermissionResult.cannotRequest;
      }

      final granted = await OneSignal.Notifications.requestPermission(false);
      if (granted) {
        await OneSignal.User.pushSubscription.optIn();
        _permissionGranted = true;
        return CerqleNotificationPermissionResult.granted;
      }

      _permissionGranted = false;
      // OneSignal's Android canRequest value can remain true after the OS has
      // exhausted its native prompts. A failed request is therefore treated as
      // requiring Settings so the caller can always offer a recovery action.
      return CerqleNotificationPermissionResult.cannotRequest;
    } catch (_) {
      _permissionGranted = false;
      return CerqleNotificationPermissionResult.cannotRequest;
    }
  }

  Future<bool> _ensureNotificationPermission() {
    if (!_initialized) return Future<bool>.value(false);
    final granted = _permissionGranted;
    if (granted != null) return Future<bool>.value(granted);
    final active = _permissionRequest;
    if (active != null) return active;

    final request = _requestNotificationPermission();
    _permissionRequest = request;
    return request.whenComplete(() {
      if (identical(_permissionRequest, request)) {
        _permissionRequest = null;
      }
    });
  }

  Future<bool> _requestNotificationPermission() async {
    try {
      // Do not show OneSignal's fallback dialog directing users to Settings
      // after they have already denied notification permission.
      final granted = await OneSignal.Notifications.requestPermission(false);
      if (!granted) {
        _permissionGranted = false;
        return false;
      }
      await OneSignal.User.pushSubscription.optIn();
      _permissionGranted = true;
      return true;
    } catch (_) {
      _permissionGranted = false;
      return false;
    }
  }

  /// Links a verified user external ID to OneSignal.
  Future<void> login(String externalId) async {
    if (!_initialized || externalId.trim().isEmpty) return;
    if (_loggedInExternalId == externalId) return;
    try {
      await OneSignal.login(externalId.trim());
      _loggedInExternalId = externalId.trim();
    } catch (_) {}
  }

  /// Logs out the user from OneSignal and opts out of pushes on reset.
  Future<void> logout() async {
    if (!_initialized) return;
    try {
      await OneSignal.User.pushSubscription.optOut();
      await OneSignal.logout();
      _loggedInExternalId = null;
    } catch (_) {}
  }

  /// Resolves the current OneSignal Push Subscription ID with retries.
  Future<String?> currentPushToken({
    bool ensureReady = true,
    bool requestPermission = true,
  }) async {
    if (_pushTokenOverride != null) return _pushTokenOverride;
    if (!_initialized) return null;

    if (ensureReady) {
      final granted = requestPermission
          ? await _ensureNotificationPermission()
          : _permissionGranted == true || OneSignal.Notifications.permission;
      if (!granted) return null;
    }

    try {
      if (!ensureReady) {
        final subscriptionId = OneSignal.User.pushSubscription.id;
        return subscriptionId?.isNotEmpty == true ? subscriptionId : null;
      }

      for (var attempt = 1; attempt <= 15; attempt++) {
        final subscriptionId = OneSignal.User.pushSubscription.id;
        if (subscriptionId != null && subscriptionId.isNotEmpty) {
          if (kDebugMode) {
            debugPrint(
              '[Cerqle] Resolved OneSignal subscription ID: $subscriptionId (attempt $attempt)',
            );
          }
          return subscriptionId;
        }
        await Future<void>.delayed(const Duration(milliseconds: 400));
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  String? _pushTokenOverride;

  @visibleForTesting
  void setPushTokenOverride(String? token) {
    _pushTokenOverride = token;
  }

  void _onNotificationClick(OSNotificationClickEvent event) {
    event.preventDefault();
    final data = _extractPayload(event.notification);
    if (_notificationClicks.hasListener) {
      _notificationClicks.add(data);
    } else {
      _pendingNotificationClick = data;
    }
  }

  void _onForegroundWillDisplay(OSNotificationWillDisplayEvent event) {
    final data = _extractPayload(event.notification);
    _foregroundNotifications.add(data);
  }

  Map<String, dynamic> _extractPayload(OSNotification notification) {
    return <String, dynamic>{
      ...?notification.additionalData,
      if (notification.title?.isNotEmpty == true) 'title': notification.title,
      if (notification.body?.isNotEmpty == true) 'body': notification.body,
      if (notification.launchUrl?.isNotEmpty == true)
        'url': notification.launchUrl,
      'notification_id': notification.notificationId,
    };
  }

  @visibleForTesting
  void simulateNotificationClick(Map<String, dynamic> payload) {
    if (_notificationClicks.hasListener) {
      _notificationClicks.add(payload);
    } else {
      _pendingNotificationClick = payload;
    }
  }

  @visibleForTesting
  void simulateForegroundNotification(Map<String, dynamic> payload) {
    _foregroundNotifications.add(payload);
  }

  @visibleForTesting
  void resetForTesting() {
    _pushTokenOverride = null;
    _pendingNotificationClick = null;
    _initialized = false;
    _initializedAppId = null;
    _loggedInExternalId = null;
    _permissionRequest = null;
    _chatOpenPermissionRequest = null;
    _permissionGranted = null;
  }
}
