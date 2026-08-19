import 'dart:async';

import 'package:flutter/material.dart';

import '../../application/services/widget_onesignal_service.dart';
import '../../application/cerqle_runtime.dart';
import '../../configuration/cerqle_config.dart';
import '../../domain/errors/cerqle_exception.dart';
import '../../domain/events/chat_event.dart';
import '../screen/chat_screen.dart';
import '../view/chat_view.dart';

/// Static helpers for modal chat presentation, push notifications, and reset.
abstract final class CerqleChat {
  static final Map<String, Future<CerqleChatResult?>> _activePresentations =
      <String, Future<CerqleChatResult?>>{};
  static final Map<String, CerqleChatController> _ownedControllers =
      <String, CerqleChatController>{};
  static StreamSubscription<Map<String, dynamic>>?
      _notificationClickSubscription;
  static void Function(Map<String, dynamic> payload)? _onNotificationTapped;
  static CerqleConfig? _lastConfig;
  static GlobalKey<NavigatorState>? _navigatorKey;

  /// Initializes OneSignal push notification handlers for visitor chat.
  ///
  /// Call this in your host app's `main()` or splash screen:
  /// ```dart
  /// CerqleChat.initializeNotificationHandlers(
  ///   config: config,
  ///   navigatorKey: navigatorKey,
  /// );
  /// ```
  static void initializeNotificationHandlers({
    CerqleConfig? config,
    GlobalKey<NavigatorState>? navigatorKey,
    void Function(Map<String, dynamic> payload)? onNotificationTapped,
  }) {
    if (config != null) _lastConfig = config;
    if (navigatorKey != null) _navigatorKey = navigatorKey;
    if (onNotificationTapped != null) {
      _onNotificationTapped = onNotificationTapped;
    }

    final appId =
        config?.oneSignalAppId ?? CerqleConfig.defaultOneSignalAppId;
    WidgetOneSignalService.instance.initialize(appId: appId);

    _notificationClickSubscription?.cancel();
    _notificationClickSubscription = WidgetOneSignalService
        .instance.notificationClicks
        .listen(_handleNotificationClick);
  }

  /// Sets or updates the custom notification tapped callback.
  static void setOnNotificationTappedCallback(
    void Function(Map<String, dynamic> payload) callback,
  ) {
    _onNotificationTapped = callback;
  }

  /// Opens the chatbox from a notification click.
  static Future<CerqleChatResult?> openChatboxFromNotification({
    BuildContext? context,
    CerqleConfig? config,
    Map<String, dynamic>? payload,
  }) {
    final effectiveConfig = config ?? _lastConfig;
    if (effectiveConfig == null) {
      throw const CerqleException(
        code: CerqleErrorCode.configuration,
        message: 'No CerqleConfig provided for notification opening.',
        retryable: false,
      );
    }
    final effectiveContext = context ?? _navigatorKey?.currentContext;
    if (effectiveContext == null) {
      throw const CerqleException(
        code: CerqleErrorCode.configuration,
        message: 'No BuildContext or navigatorKey available to open chat.',
        retryable: false,
      );
    }

    return open(effectiveContext, config: effectiveConfig);
  }

  static void _handleNotificationClick(Map<String, dynamic> payload) {
    if (_onNotificationTapped != null) {
      _onNotificationTapped!(payload);
      return;
    }

    if (_navigatorKey?.currentContext != null && _lastConfig != null) {
      openChatboxFromNotification(
        context: _navigatorKey!.currentContext,
        config: _lastConfig,
        payload: payload,
      );
    }
  }

  /// Opens at most one chat presentation for the configuration scope.
  ///
  /// Uses [config.presentation] unless [presentation] overrides it. A supplied
  /// [controller] remains owned by the caller. Throws [CerqleException]
  /// when configuration is invalid or the controller belongs to another
  /// identity/widget scope.
  static Future<CerqleChatResult?> open(
    BuildContext context, {
    required CerqleConfig config,
    CerqleChatController? controller,
    CerqlePresentation? presentation,
  }) {
    validateCerqleRuntimeConfig(config);
    final scope = cerqlePresentationScope(config);
    final active = _activePresentations[scope];
    if (active != null) return active;

    if (controller != null &&
        cerqlePresentationScope(controller.config) != scope) {
      throw const CerqleException(
        code: CerqleErrorCode.configuration,
        message:
            'The supplied controller does not match the chat configuration.',
        retryable: false,
      );
    }

    final completer = Completer<CerqleChatResult?>();
    _activePresentations[scope] = completer.future;
    unawaited(
      _openPresentation(
            context,
            scope: scope,
            config: config,
            suppliedController: controller,
            presentation: presentation ?? config.presentation,
          )
          .then(completer.complete, onError: completer.completeError)
          .whenComplete(() => _activePresentations.remove(scope)),
    );
    return completer.future;
  }

  static Future<CerqleChatResult?> _openPresentation(
    BuildContext context, {
    required String scope,
    required CerqleConfig config,
    required CerqleChatController? suppliedController,
    required CerqlePresentation presentation,
  }) async {
    CerqleClient? ownedClient;
    final controller =
        suppliedController ??
        (() {
          final client = CerqleClient(config: config);
          ownedClient = client;
          return CerqleChatController(client: client);
        })();
    if (ownedClient != null) _ownedControllers[scope] = controller;

    try {
      switch (presentation) {
        case CerqlePresentation.fullScreen:
          await Navigator.of(context).push<CerqleChatResult>(
            MaterialPageRoute<CerqleChatResult>(
              builder: (_) =>
                  CerqleChatScreen(config: config, controller: controller),
            ),
          );
          break;
        case CerqlePresentation.bottomSheet:
          controller.handlePresentationOpened();
          await showModalBottomSheet<void>(
            context: context,
            isScrollControlled: true,
            useSafeArea: true,
            backgroundColor: Colors.transparent,
            builder: (sheetContext) => Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
              ),
              child: FractionallySizedBox(
                key: const ValueKey<String>('cerqle-bottom-sheet'),
                heightFactor: 0.96,
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(20),
                  ),
                  child: Material(
                    child: CerqleChatView(
                      config: config,
                      controller: controller,
                      onClose: () => Navigator.of(sheetContext).pop(),
                    ),
                  ),
                ),
              ),
            ),
          );
          controller.handlePresentationClosed(CerqleChatCloseReason.userClosed);
          break;
        case CerqlePresentation.dialog:
          controller.handlePresentationOpened();
          await showDialog<void>(
            context: context,
            builder: (dialogContext) => Dialog(
              clipBehavior: Clip.antiAlias,
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: 420,
                  maxHeight: 720,
                ),
                child: SizedBox(
                  width: 420,
                  height: MediaQuery.sizeOf(dialogContext).height * 0.82,
                  child: CerqleChatView(
                    config: config,
                    controller: controller,
                    onClose: () => Navigator.of(dialogContext).pop(),
                  ),
                ),
              ),
            ),
          );
          controller.handlePresentationClosed(CerqleChatCloseReason.userClosed);
          break;
      }
      return const CerqleChatResult(reason: CerqleChatCloseReason.userClosed);
    } finally {
      if (ownedClient != null) {
        _ownedControllers.remove(scope);
        await controller.dispose();
        await ownedClient!.close();
      }
    }
  }

  /// Deletes credentials for [config] and resets any facade-owned controller.
  ///
  /// Throws [CerqleException] when configuration or secure storage fails.
  static Future<void> resetSession({required CerqleConfig config}) async {
    validateCerqleRuntimeConfig(config);
    final scope = cerqlePresentationScope(config);
    final active = _ownedControllers[scope];
    if (active != null) {
      await active.resetSession();
      return;
    }

    await resetCerqleStoredSession(config);
  }
}
