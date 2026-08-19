part of '../view/chat_view.dart';

class _HandoffAction extends StatelessWidget {
  const _HandoffAction({
    required this.state,
    required this.colors,
    required this.onPressed,
  });

  final CerqleChatState state;
  final CerqleResolvedTheme colors;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final status = state.handoff.status;
    if (status == CerqleHandoffStatus.unavailable) {
      return const SizedBox.shrink();
    }
    final isActionable =
        status == CerqleHandoffStatus.eligible ||
        status == CerqleHandoffStatus.failed;
    final prompt = switch (status) {
      CerqleHandoffStatus.eligible => 'Prefer a person?',
      CerqleHandoffStatus.requesting => 'Connecting to a human agent…',
      CerqleHandoffStatus.connected => 'Connected to a human agent',
      CerqleHandoffStatus.failed => 'Could not connect.',
      CerqleHandoffStatus.unavailable => '',
    };
    final actionLabel = status == CerqleHandoffStatus.failed
        ? 'Try again'
        : 'Human Agent';
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
