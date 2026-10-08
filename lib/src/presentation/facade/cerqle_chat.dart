import 'dart:async';

import 'package:app_settings/app_settings.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../application/services/widget_onesignal_service.dart';
import '../../application/cerqle_runtime.dart';
import '../../configuration/cerqle_config.dart';
import '../../domain/errors/cerqle_exception.dart';
import '../../domain/events/chat_event.dart';
import '../../domain/models/models.dart';
import '../screen/chat_screen.dart';
import '../unread_controller_registry.dart';
import '../view/chat_view.dart';
import '../widgets/unread_badge.dart';

/// Static helpers for modal chat presentation, push notifications, and reset.
abstract final class CerqleChat {
  static final Map<String, Future<CerqleChatResult?>> _activePresentations =
      <String, Future<CerqleChatResult?>>{};
  static final Map<String, CerqleChatController> _ownedControllers =
      <String, CerqleChatController>{};
  static final Map<String, Future<void>> _startupRegistrations =
      <String, Future<void>>{};
  static StreamSubscription<Map<String, dynamic>>?
      _notificationClickSubscription;
  static void Function(Map<String, dynamic> payload)? _onNotificationTapped;
  static Map<String, dynamic>? _pendingNotificationPayload;
  static CerqleConfig? _lastConfig;
  static GlobalKey<NavigatorState>? _navigatorKey;

  /// Initializes the Cerqle runtime for the host application.
  ///
  /// Notification handling is configured internally. Visitor registration is
  /// also automatic unless [CerqleConfig.registerUserOnStartup] is false.
  /// ```dart
  /// await CerqleChat.initialize(
  ///   config: config,
  ///   navigatorKey: navigatorKey,
  /// );
  /// ```
  static Future<void> initialize({
    required CerqleConfig config,
    GlobalKey<NavigatorState>? navigatorKey,
    void Function(Map<String, dynamic> payload)? onNotificationTapped,
  }) async {
    validateCerqleRuntimeConfig(config);
    _lastConfig = config;
    if (navigatorKey != null) _navigatorKey = navigatorKey;
    if (onNotificationTapped != null) {
      _onNotificationTapped = onNotificationTapped;
    }

    await _initializeNotificationHandlers(config);
    if (config.registerUserOnStartup) {
      _scheduleStartupRegistration(config);
    }
    _schedulePendingNotificationOpen();
  }

  static Future<void> _initializeNotificationHandlers(
    CerqleConfig config,
  ) async {
    await _notificationClickSubscription?.cancel();
    _notificationClickSubscription = null;
    if (!config.enableOneSignal || config.oneSignalAppId.trim().isEmpty) return;

    await WidgetOneSignalService.instance.initialize(
      appId: config.oneSignalAppId,
    );
    await WidgetOneSignalService.instance.requestPermission();
    _notificationClickSubscription = WidgetOneSignalService
        .instance.notificationClicks
        .listen(_handleNotificationClick);
  }

  static void _scheduleStartupRegistration(CerqleConfig config) {
    final scope = cerqlePresentationScope(config);
    if (_startupRegistrations.containsKey(scope)) return;
    final registration = _registerUser(config);
    _startupRegistrations[scope] = registration;
    unawaited(registration);
  }

  static Future<void> _registerUser(CerqleConfig config) async {
    final client = CerqleClient(config: config);
    final controller = CerqleChatController(client: client);
    try {
      await controller.initialize();
    } catch (_) {
      // Startup registration is best-effort and must not block the host app.
    } finally {
      await controller.dispose();
      await client.close();
    }
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
  }) async {
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

    final config = _lastConfig;
    if (config == null) return;

    final context = _navigatorKey?.currentContext;
    if (context != null) {
      unawaited(
        openChatboxFromNotification(
          context: context,
          config: config,
          payload: payload,
        ).catchError((_) => null),
      );
    } else {
      _pendingNotificationPayload = payload;
      _schedulePendingNotificationOpen();
    }
  }

  static void _schedulePendingNotificationOpen() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final payload = _pendingNotificationPayload;
      if (payload == null) return;
      final context = _navigatorKey?.currentContext;
      final config = _lastConfig;
      if (context != null && config != null) {
        _pendingNotificationPayload = null;
        unawaited(
          openChatboxFromNotification(
            context: context,
            config: config,
            payload: payload,
          ).catchError((_) => null),
        );
      }
    });
  }

  /// Opens at most one chat presentation for the configuration scope.
  ///
  /// Uses [CerqleConfig.presentation] unless [presentation] overrides it. A supplied
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
    _lastConfig = config;
    final scope = cerqlePresentationScope(config);
    final active = _activePresentations[scope];
    if (active != null) return active;

    final effectiveController =
        controller ?? UnreadControllerRegistry.first(scope);
    if (effectiveController != null &&
        cerqlePresentationScope(effectiveController.config) != scope) {
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
        suppliedController: effectiveController,
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
    if (config.requireNotificationPermission &&
        !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS)) {
      await WidgetOneSignalService.instance.initialize(
        appId: config.oneSignalAppId,
      );
      final permission =
          await WidgetOneSignalService.instance.requestPermissionForChatOpen();
      if (permission == CerqleNotificationPermissionResult.cannotRequest &&
          context.mounted) {
        _showNotificationSettingsSnack(context);
      }
      if (permission != CerqleNotificationPermissionResult.granted) {
        return null;
      }
    }
    if (!context.mounted) {
      return const CerqleChatResult(reason: CerqleChatCloseReason.userClosed);
    }

    UnreadControllerRegistry.markRead(scope);

    CerqleClient? ownedClient;
    final controller = suppliedController ??
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

  static void _showNotificationSettingsSnack(BuildContext context) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;

    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: const Text('Enable notifications in Settings.'),
          // A fixed snack remains visible when CerqleChatLauncher is supplied
          // as Scaffold.floatingActionButton. The launcher can occupy the
          // slot's full layout bounds, which makes Flutter reject a floating
          // snack as being off screen.
          behavior: SnackBarBehavior.fixed,
          duration: const Duration(seconds: 4),
          action: SnackBarAction(
            label: 'Settings',
            onPressed: () => unawaited(
              AppSettings.openAppSettings(
                type: AppSettingsType.notification,
              ),
            ),
          ),
        ),
      );
  }

  /// Adds an unread indicator to any host-owned widget.
  ///
  /// The wrapper owns its unread listener. It renders a dot by default. Set
  /// [showCount] to display a count, or provide [labelBuilder] for custom
  /// content. Opening chat with the same [config] clears the badge.
  static Widget badge({
    Key? key,
    required CerqleConfig config,
    required Widget child,
    bool showCount = false,
    int maxCount = 99,
    Widget Function(BuildContext context, int unreadCount)? labelBuilder,
    Color? backgroundColor,
    Color? textColor,
    double? smallSize = 8,
    double? largeSize,
    TextStyle? textStyle,
    EdgeInsetsGeometry? padding,
    AlignmentGeometry? alignment,
    Offset? offset,
  }) =>
      _CerqleUnreadBadge(
        key: key,
        config: config,
        showCount: showCount,
        maxCount: maxCount,
        labelBuilder: labelBuilder,
        backgroundColor: backgroundColor,
        textColor: textColor,
        smallSize: smallSize,
        largeSize: largeSize,
        textStyle: textStyle,
        padding: padding,
        alignment: alignment,
        offset: offset,
        child: child,
      );

  /// Deletes credentials for [config] and resets any facade-owned controller.
  ///
  /// Throws [CerqleException] when configuration or secure storage fails.
  static Future<void> resetSession({required CerqleConfig config}) async {
    validateCerqleRuntimeConfig(config);
    final scope = cerqlePresentationScope(config);
    _startupRegistrations.remove(scope);
    final active = _ownedControllers[scope];
    if (active != null) {
      await active.resetSession();
      return;
    }

    await resetCerqleStoredSession(config);
  }
}

class _CerqleUnreadBadge extends StatefulWidget {
  const _CerqleUnreadBadge({
    super.key,
    required this.config,
    required this.child,
    required this.showCount,
    required this.maxCount,
    required this.labelBuilder,
    required this.backgroundColor,
    required this.textColor,
    required this.smallSize,
    required this.largeSize,
    required this.textStyle,
    required this.padding,
    required this.alignment,
    required this.offset,
  });

  final CerqleConfig config;
  final Widget child;
  final bool showCount;
  final int maxCount;
  final Widget Function(BuildContext context, int unreadCount)? labelBuilder;
  final Color? backgroundColor;
  final Color? textColor;
  final double? smallSize;
  final double? largeSize;
  final TextStyle? textStyle;
  final EdgeInsetsGeometry? padding;
  final AlignmentGeometry? alignment;
  final Offset? offset;

  @override
  State<_CerqleUnreadBadge> createState() => _CerqleUnreadBadgeState();
}

class _CerqleUnreadBadgeState extends State<_CerqleUnreadBadge> {
  StreamSubscription<CerqleChatState>? _subscription;
  late CerqleClient _client;
  late CerqleChatController _controller;
  late String _scope;
  late int _unreadCount;

  @override
  void initState() {
    super.initState();
    _attachRuntime();
  }

  @override
  void didUpdateWidget(covariant _CerqleUnreadBadge oldWidget) {
    super.didUpdateWidget(oldWidget);
    final nextScope = cerqlePresentationScope(widget.config);
    if (_scope != nextScope) {
      unawaited(_replaceRuntime());
    }
  }

  void _attachRuntime() {
    validateCerqleRuntimeConfig(widget.config);
    _client = CerqleClient(config: widget.config);
    _controller = CerqleChatController(client: _client);
    _scope = UnreadControllerRegistry.register(
      config: widget.config,
      controller: _controller,
    );
    _unreadCount = _controller.state.unreadCount;
    _subscription = _controller.states.listen((state) {
      if (mounted && state.unreadCount != _unreadCount) {
        setState(() => _unreadCount = state.unreadCount);
      }
    });
    if (widget.config.registerUserOnStartup) {
      unawaited(_controller.initialize().catchError((_) {}));
    }
  }

  Future<void> _replaceRuntime() async {
    await _subscription?.cancel();
    UnreadControllerRegistry.unregister(_scope, _controller);
    await _controller.dispose();
    await _client.close();
    if (!mounted) return;
    _attachRuntime();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) => CerqleUnreadBadgeView(
        unreadCount: _unreadCount,
        indicatorKey: const ValueKey<String>('cerqle-unread-badge-indicator'),
        showCount: widget.showCount,
        maxCount: widget.maxCount,
        labelBuilder: widget.labelBuilder,
        backgroundColor: widget.backgroundColor,
        textColor: widget.textColor,
        smallSize: widget.smallSize,
        largeSize: widget.largeSize,
        textStyle: widget.textStyle,
        padding: widget.padding,
        alignment: widget.alignment,
        offset: widget.offset,
        child: widget.child,
      );

  @override
  void dispose() {
    unawaited(_subscription?.cancel());
    UnreadControllerRegistry.unregister(_scope, _controller);
    unawaited(_controller.dispose().then((_) => _client.close()));
    super.dispose();
  }
}
