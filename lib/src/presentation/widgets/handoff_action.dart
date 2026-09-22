part of '../view/chat_view.dart';

class _HandoffAction extends StatelessWidget {
  const _HandoffAction({
    required this.state,
    required this.colors,
    required this.onPressed,
    this.compact = false,
  });

  final CerqleChatState state;
  final CerqleResolvedTheme colors;
  final VoidCallback onPressed;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final status = state.handoff.status;
    if (status == CerqleHandoffStatus.unavailable) {
      return const SizedBox.shrink();
    }
    final isActionable = status == CerqleHandoffStatus.eligible ||
        status == CerqleHandoffStatus.failed;
    final prompt = switch (status) {
      CerqleHandoffStatus.eligible => 'Prefer a person?',
      CerqleHandoffStatus.requesting => 'Connecting to a human agent…',
      CerqleHandoffStatus.connected => 'Connected to a human agent',
      CerqleHandoffStatus.failed => 'Could not connect.',
      CerqleHandoffStatus.unavailable => '',
    };
    final actionLabel =
        status == CerqleHandoffStatus.failed ? 'Try again' : 'Human Agent';
    if (compact) {
      return Tooltip(
        message: isActionable ? 'Switch to a human agent' : prompt,
        child: OutlinedButton(
          onPressed: isActionable ? onPressed : null,
          style: OutlinedButton.styleFrom(
            foregroundColor: colors.onPrimary,
            disabledForegroundColor: colors.onPrimary,
            minimumSize: const Size(48, 28),
            visualDensity: VisualDensity.compact,
            side: BorderSide(color: colors.onPrimary.withValues(alpha: 0.6)),
            padding: const EdgeInsets.symmetric(horizontal: 8),
          ),
          child: status == CerqleHandoffStatus.requesting
              ? _HandoffShimmer(color: colors.onPrimary)
              : Text(
                  switch (status) {
                    CerqleHandoffStatus.connected => 'Agent',
                    CerqleHandoffStatus.failed => 'Try again',
                    _ => 'AI',
                  },
                ),
        ),
      );
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(top: BorderSide(color: colors.outline)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (status == CerqleHandoffStatus.requesting) ...<Widget>[
            SizedBox.square(
              dimension: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: colors.primary,
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Text(
              prompt,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: colors.onSurfaceMuted),
            ),
          ),
          if (isActionable) ...<Widget>[
            const SizedBox(width: 8),
            Semantics(
              button: true,
              label: status == CerqleHandoffStatus.failed
                  ? 'Try human agent again'
                  : 'Request a human agent',
              child: OutlinedButton(
                onPressed: onPressed,
                style: OutlinedButton.styleFrom(
                  foregroundColor: colors.primary,
                  side: BorderSide(color: colors.primary),
                  minimumSize: const Size(48, 36),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  visualDensity: VisualDensity.compact,
                ),
                child: Text(actionLabel),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _HandoffShimmer extends StatefulWidget {
  const _HandoffShimmer({required this.color});

  final Color color;

  @override
  State<_HandoffShimmer> createState() => _HandoffShimmerState();
}

class _HandoffShimmerState extends State<_HandoffShimmer>
    with SingleTickerProviderStateMixin {
  late final _animation = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  );

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    if (reduceMotion) {
      _animation.stop();
    } else if (!_animation.isAnimating) {
      _animation.repeat();
    }
    return Semantics(
      label: 'Connecting to a human agent',
      liveRegion: true,
      child: SizedBox(
        width: 32,
        height: 12,
        child: AnimatedBuilder(
          animation: _animation,
          child: const _ShimmerBlock(height: 12),
          builder: (context, child) {
            final travel = reduceMotion ? 0.0 : _animation.value * 3 - 1.5;
            return ShaderMask(
              blendMode: BlendMode.srcIn,
              shaderCallback: (bounds) => LinearGradient(
                begin: Alignment(travel - 1, 0),
                end: Alignment(travel + 1, 0),
                colors: <Color>[
                  widget.color.withValues(alpha: 0.25),
                  widget.color.withValues(alpha: 0.85),
                  widget.color.withValues(alpha: 0.25),
                ],
                stops: const <double>[0.2, 0.5, 0.8],
              ).createShader(bounds),
              child: child,
            );
          },
        ),
      ),
    );
  }

  @override
  void dispose() {
    _animation.dispose();
    super.dispose();
  }
}
