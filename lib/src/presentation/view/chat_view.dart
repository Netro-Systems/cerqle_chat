import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:just_audio/just_audio.dart';
import 'package:record/record.dart';

import '../../application/cerqle_runtime.dart';
import '../../configuration/cerqle_config.dart';
import '../../diagnostics/debug_upload_logger.dart';
import '../../domain/contracts/media_adapter.dart';
import '../../domain/errors/cerqle_exception.dart';
import '../../domain/models/models.dart';
import '../media/remote_image.dart';
import '../theme/resolved_theme.dart';
import '../widgets/brand_logo.dart';
import '../widgets/brand_footer.dart';
import '../widgets/availability_banner.dart';
import '../widgets/chat_error_state.dart';
import '../widgets/connection_banner.dart';

part '../widgets/loading_shimmer.dart';
part '../widgets/chat_header.dart';
part '../widgets/chat_timeline.dart';
part '../widgets/welcome_bubble.dart';
part '../widgets/pre_chat_form.dart';
part '../widgets/message_bubble.dart';
part '../widgets/message_content.dart';
part '../widgets/audio_playback_coordinator.dart';
part '../widgets/default_media_adapter.dart';
part '../widgets/typing_indicator.dart';
part '../widgets/handoff_action.dart';
part '../widgets/message_composer.dart';
part '../widgets/image_preview.dart';
part '../widgets/audio_preview.dart';

/// Builds a custom chat state such as an empty or error presentation.
typedef CerqleChatStateBuilder =
    Widget Function(BuildContext context, CerqleChatState state);

/// Builds a custom presentation for one immutable message.
typedef CerqleMessageBuilder =
    Widget Function(BuildContext context, CerqleMessage message);

/// Builds a custom composer connected to the active controller and state.
typedef CerqleComposerBuilder =
    Widget Function(
      BuildContext context,
      CerqleChatController controller,
      CerqleChatState state,
    );

/// Embeddable prebuilt chat UI with no scaffold or navigation assumptions.
class CerqleChatView extends StatefulWidget {
  /// Creates an embedded chat view.
  ///
  /// When [controller] is omitted, the view owns and disposes its runtime.
  const CerqleChatView({
    super.key,
    required this.config,
    this.controller,
    this.showHeader = true,
    this.emptyBuilder,
    this.errorBuilder,
    this.messageBuilder,
    this.composerBuilder,
    this.onClose,
  });

  /// Widget, identity, transport, polling, and theme configuration.
  final CerqleConfig config;

  /// Optional host-owned controller.
  final CerqleChatController? controller;

  /// Whether the built-in branded header is visible.
  final bool showHeader;

  /// Optional replacement for the ready state with no server messages.
  final CerqleChatStateBuilder? emptyBuilder;

  /// Optional replacement for terminal error state.
  final CerqleChatStateBuilder? errorBuilder;

  /// Optional per-message renderer.
  final CerqleMessageBuilder? messageBuilder;

  /// Optional composer renderer.
  final CerqleComposerBuilder? composerBuilder;

  /// Optional close callback rendered by the built-in header.
  final VoidCallback? onClose;

  @override
  State<CerqleChatView> createState() => _CerqleChatViewState();
}

class _CerqleChatViewState extends State<CerqleChatView> {
  final ScrollController _scrollController = ScrollController();
  late CerqleChatController _controller;
  CerqleClient? _ownedClient;
  StreamSubscription<CerqleChatState>? _subscription;
  late CerqleChatState _state;
  bool _nearBottom = true;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_trackScrollPosition);
    _attachRuntime();
  }

  @override
  void didUpdateWidget(covariant CerqleChatView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.controller, widget.controller) ||
        !identical(oldWidget.config, widget.config)) {
      unawaited(_replaceRuntime());
    }
  }

  void _attachRuntime() {
    final supplied = widget.controller;
    if (supplied == null) {
      final client = CerqleClient(config: widget.config);
      _ownedClient = client;
      _controller = CerqleChatController(client: client);
    } else {
      _controller = supplied;
    }
    _state = _controller.state;
    _subscription = _controller.states.listen(_onState);
    unawaited(_controller.initialize().catchError((_) {}));
  }

  Future<void> _replaceRuntime() async {
    await _subscription?.cancel();
    final oldClient = _ownedClient;
    if (oldClient != null) {
      await _controller.dispose();
      await oldClient.close();
    }
    _ownedClient = null;
    if (!mounted) return;
    _attachRuntime();
    setState(() {});
  }

  void _onState(CerqleChatState next) {
    if (!mounted) return;
    final grew = next.messages.length > _state.messages.length;
    final sentByVisitor =
        grew &&
        next.messages.isNotEmpty &&
        next.messages.last.role == CerqleMessageRole.visitor;
    setState(() => _state = next);
    if (grew && (_nearBottom || sentByVisitor)) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToEnd());
    }
  }

  void _trackScrollPosition() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    _nearBottom = position.pixels - position.minScrollExtent < 96;
  }

  void _scrollToEnd() {
    if (!mounted || !_scrollController.hasClients) return;
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final target = _scrollController.position.minScrollExtent;
    if (reduceMotion) {
      _scrollController.jumpTo(target);
    } else {
      unawaited(
        _scrollController.animateTo(
          target,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final hostTheme = Theme.of(context);
    final colors = CerqleResolvedTheme.resolve(
      hostTheme: hostTheme,
      server: _state.widget,
      override: widget.config.theme,
      useApiColors: widget.config.useApiColors,
    );
    final sdkTheme = hostTheme.copyWith(
      colorScheme: hostTheme.colorScheme.copyWith(
        primary: colors.primary,
        onPrimary: colors.onPrimary,
      ),
      textSelectionTheme: hostTheme.textSelectionTheme.copyWith(
        cursorColor: colors.primary,
        selectionColor: colors.primary.withValues(alpha: 0.24),
        selectionHandleColor: colors.primary,
      ),
    );
    return Theme(
      data: sdkTheme,
      child: ColoredBox(
        color: colors.background,
        child: _isLoading(_state.phase)
            ? _ChatLoadingShimmer(showHeader: widget.showHeader)
            : Column(
                children: <Widget>[
                  if (widget.showHeader)
                    _ChatHeader(
                      state: _state,
                      colors: colors,
                      onClose: widget.onClose,
                    ),
                  if (_state.phase == CerqleChatPhase.reconnecting)
                    ChatConnectionBanner(colors: colors),
                  if (_state.supportAvailability ==
                      CerqleSupportAvailability.unavailable)
                    ChatAvailabilityBanner(state: _state, colors: colors),
                  Expanded(child: _buildBody(colors)),
                  if (_canCompose(_state)) _buildComposer(colors),
                ],
              ),
      ),
    );
  }

  bool _isLoading(CerqleChatPhase phase) =>
      phase == CerqleChatPhase.idle ||
      phase == CerqleChatPhase.initializing ||
      phase == CerqleChatPhase.expired;

  Widget _buildBody(CerqleResolvedTheme colors) {
    switch (_state.phase) {
      case CerqleChatPhase.idle:
      case CerqleChatPhase.initializing:
      case CerqleChatPhase.expired:
        return const SizedBox.shrink();
      case CerqleChatPhase.awaitingPreChat:
        return _PreChatForm(
          controller: _controller,
          state: _state,
          colors: colors,
        );
      case CerqleChatPhase.failure:
        return widget.errorBuilder?.call(context, _state) ??
            ChatErrorState(
              state: _state,
              colors: colors,
              onRetry: _state.error?.retryable == true
                  ? () => unawaited(_controller.initialize().catchError((_) {}))
                  : null,
            );
      case CerqleChatPhase.ready:
      case CerqleChatPhase.reconnecting:
        if (_state.messages.isEmpty) {
          final custom = widget.emptyBuilder?.call(context, _state);
          if (custom != null) return custom;
        }
        return _timeline(colors);
      case CerqleChatPhase.disposed:
        return const SizedBox.shrink();
    }
  }

  Widget _timeline(CerqleResolvedTheme colors) {
    final configuredWelcome = _state.widget?.welcomeMessage.trim();
    final welcome = configuredWelcome?.isNotEmpty == true
        ? configuredWelcome!
        : 'Hi there! How can we help?';
    const welcomeCount = 1;
    final typingCount = _state.agentTyping == null ? 0 : 1;
    return RefreshIndicator(
      color: colors.primary,
      onRefresh: _controller.refresh,
      child: Stack(
        children: <Widget>[
          ListView.builder(
            controller: _scrollController,
            reverse: true,
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
            itemCount: welcomeCount + _state.messages.length + typingCount,
            itemBuilder: (context, index) {
              if (typingCount == 1 && index == 0) {
                return _TypingIndicator(
                  typing: _state.agentTyping!,
                  colors: colors,
                );
              }
              final messageIndex =
                  _state.messages.length - 1 - (index - typingCount);
              if (messageIndex < 0) {
                return Padding(
                  padding: EdgeInsets.only(bottom: colors.messageSpacing),
                  child: _WelcomeBubble(
                    body: welcome,
                    widgetConfig: _state.widget,
                    colors: colors,
                  ),
                );
              }
              final message = _state.messages[messageIndex];
              return Padding(
                padding: EdgeInsets.only(bottom: colors.messageSpacing),
                child:
                    widget.messageBuilder?.call(context, message) ??
                    _MessageBubble(
                      message: message,
                      controller: _controller,
                      widgetConfig: _state.widget,
                      colors: colors,
                      onRetry:
                          message.status == CerqleMessageStatus.failed &&
                              message.error?.retryable == true
                          ? () => unawaited(
                              _controller
                                  .retryMessage(message.localId)
                                  .catchError((_) => message),
                            )
                          : null,
                      onRemove:
                          message.status == CerqleMessageStatus.failed ||
                              message.status == CerqleMessageStatus.unconfirmed
                          ? () => unawaited(
                              _controller.removeMessage(message.localId),
                            )
                          : null,
                      onRefresh:
                          message.status == CerqleMessageStatus.unconfirmed
                          ? () => unawaited(
                              _controller.refresh().catchError((_) {}),
                            )
                          : null,
                    ),
              );
            },
          ),
          if (!_nearBottom)
            PositionedDirectional(
              end: 12,
              bottom: 12,
              child: FloatingActionButton.small(
                heroTag: null,
                tooltip: 'Jump to latest message',
                onPressed: _scrollToEnd,
                backgroundColor: colors.surface,
                foregroundColor: colors.onSurface,
                child: const Icon(Icons.keyboard_arrow_down),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildComposer(CerqleResolvedTheme colors) {
    final custom = widget.composerBuilder;
    if (custom != null) return custom(context, _controller, _state);
    return Material(
      color: colors.surface,
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            _HandoffAction(
              state: _state,
              colors: colors,
              onPressed: () =>
                  unawaited(_controller.requestHumanAgent().catchError((_) {})),
            ),
            _Composer(
              controller: _controller,
              colors: colors,
              mediaAdapter: widget.config.mediaAdapter,
              imagesEnabled: true,
              audioEnabled: true,
            ),
            BrandFooter(
              companyName: _state.widget?.footerCompanyName,
              colors: colors,
            ),
          ],
        ),
      ),
    );
  }

  bool _canCompose(CerqleChatState state) =>
      state.phase == CerqleChatPhase.ready ||
      state.phase == CerqleChatPhase.reconnecting;

  @override
  void dispose() {
    _scrollController
      ..removeListener(_trackScrollPosition)
      ..dispose();
    unawaited(_subscription?.cancel());
    final client = _ownedClient;
    if (client != null) {
      unawaited(_controller.dispose().then((_) => client.close()));
    }
    super.dispose();
  }
}
