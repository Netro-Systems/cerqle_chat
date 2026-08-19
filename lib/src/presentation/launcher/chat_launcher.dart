import 'dart:async';

import 'package:flutter/material.dart';

import '../../application/cerqle_runtime.dart';
import '../../configuration/cerqle_config.dart';
import '../../domain/models/models.dart';
import '../facade/cerqle_chat.dart';
import '../media/remote_image.dart';
import '../theme/resolved_theme.dart';
import '../widgets/brand_logo.dart';

/// Builds a custom launcher from controller state and an idempotent open action.
typedef CerqleLauncherBuilder =
    Widget Function(
      BuildContext context,
      CerqleChatState state,
      VoidCallback openChat,
    );

/// Floating launcher that initializes chat and opens one presentation per scope.
class CerqleChatLauncher extends StatefulWidget {
  /// Creates a launcher.
  ///
  /// When [controller] is omitted, the launcher owns and disposes its runtime.
  const CerqleChatLauncher({
    super.key,
    required this.config,
    this.controller,
    this.alignment,
    this.margin,
    this.presentation,
    this.builder,
  });

  /// Widget and visitor configuration.
  final CerqleConfig config;

  /// Optional host-owned controller.
  final CerqleChatController? controller;

  /// Optional alignment overriding the server launcher position.
  final Alignment? alignment;

  /// Insets around the floating launcher.
  final EdgeInsetsGeometry? margin;

  /// Presentation style used when tapped.
  final CerqlePresentation? presentation;

  /// Optional custom launcher renderer.
  final CerqleLauncherBuilder? builder;

  @override
  State<CerqleChatLauncher> createState() => _CerqleChatLauncherState();
}

class _CerqleChatLauncherState extends State<CerqleChatLauncher> {
  late CerqleChatController _controller;
  CerqleClient? _ownedClient;
  StreamSubscription<CerqleChatState>? _subscription;
  late CerqleChatState _state;
  bool _opening = false;

  @override
  void initState() {
    super.initState();
    final supplied = widget.controller;
    if (supplied == null) {
      final client = CerqleClient(config: widget.config);
      _ownedClient = client;
      _controller = CerqleChatController(client: client);
    } else {
      _controller = supplied;
    }
    _state = _controller.state;
    _subscription = _controller.states.listen((state) {
      if (mounted) setState(() => _state = state);
    });
    unawaited(_controller.initialize().catchError((_) {}));
  }

  @override
  Widget build(BuildContext context) {
    final open = _opening ? () {} : () => unawaited(_open());
    final custom = widget.builder;
    if (custom != null) return custom(context, _state, open);

    final isConfigurationLoaded = _state.widget != null;
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (reduceMotion) {
      if (!isConfigurationLoaded) return const SizedBox.shrink();
      return _buildPositionedLauncher(
        context,
        child: _buildDefaultLauncherButton(context, open),
      );
    }

    return _buildPositionedLauncher(
      context,
      child: AnimatedSwitcher(
        key: const ValueKey<String>('cerqle-launcher-transition'),
        duration: const Duration(milliseconds: 140),
        transitionBuilder: _buildZoomTransition,
        child: isConfigurationLoaded
            ? KeyedSubtree(
                key: const ValueKey<String>('cerqle-launcher-loaded'),
                child: _buildDefaultLauncherButton(context, open),
              )
            : const SizedBox.shrink(
                key: ValueKey<String>('cerqle-launcher-loading'),
              ),
      ),
    );
  }

  Widget _buildPositionedLauncher(
    BuildContext context, {
    required Widget child,
  }) => Align(
    alignment: widget.alignment ?? _serverAlignment(_state),
    child: SafeArea(
      minimum: (widget.margin ?? const EdgeInsets.all(16)).resolve(
        Directionality.of(context),
      ),
      child: child,
    ),
  );

  Widget _buildDefaultLauncherButton(BuildContext context, VoidCallback open) {
    final colors = CerqleResolvedTheme.resolve(
      hostTheme: Theme.of(context),
      server: _state.widget,
      override: widget.config.theme,
      useApiColors: widget.config.useApiColors,
    );
    const label = 'Open chat';
    return Semantics(
      button: true,
      label: label,
      child: SizedBox.square(
        dimension: colors.launcherSize,
        child: Stack(
          clipBehavior: Clip.none,
          children: <Widget>[
            Positioned.fill(
              child: FloatingActionButton(
                heroTag: null,
                tooltip: label,
                onPressed: open,
                backgroundColor: colors.primary,
                foregroundColor: colors.onPrimary,
                child: _launcherIcon(_state, colors.launcherSize),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildZoomTransition(Widget child, Animation<double> animation) {
    final scale = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic));
    return ScaleTransition(
      key: child.key == const ValueKey<String>('cerqle-launcher-loaded')
          ? const ValueKey<String>('cerqle-launcher-zoom')
          : null,
      scale: scale,
      alignment: Alignment.center,
      child: child,
    );
  }

  Widget _launcherIcon(CerqleChatState state, double launcherSize) {
    final logo = state.widget?.launcherLogoUrl;
    return SizedBox.square(
      dimension: launcherSize * 4 / 7,
      child: logo == null
          ? _builtInLauncherLogo()
          : CerqleRemoteImage(
              url: logo,
              fit: BoxFit.contain,
              errorBuilder: (_) => _builtInLauncherLogo(),
            ),
    );
  }

  Widget _builtInLauncherLogo() =>
      const CerqleBrandLogo(imageKey: ValueKey<String>('cerqle-launcher-logo'));

  Alignment _serverAlignment(CerqleChatState state) =>
      state.widget?.launcherPosition == CerqleLauncherPosition.bottomLeft
      ? Alignment.bottomLeft
      : Alignment.bottomRight;

  Future<void> _open() async {
    if (_opening) return;
    setState(() => _opening = true);
    try {
      await CerqleChat.open(
        context,
        config: widget.config,
        controller: _controller,
        presentation: widget.presentation,
      );
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  @override
  void dispose() {
    unawaited(_subscription?.cancel());
    final client = _ownedClient;
    if (client != null) {
      unawaited(_controller.dispose().then((_) => client.close()));
    }
    super.dispose();
  }
}
