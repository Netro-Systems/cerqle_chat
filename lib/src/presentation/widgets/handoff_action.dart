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
    final isActionable = status == CerqleHandoffStatus.eligible ||
        status == CerqleHandoffStatus.failed;
    final prompt = switch (status) {
      CerqleHandoffStatus.eligible => 'Need a person?',
      CerqleHandoffStatus.requesting => 'Requesting human support…',
      CerqleHandoffStatus.connected => 'Connected to a human agent',
      CerqleHandoffStatus.failed => 'Could not connect.',
      CerqleHandoffStatus.unavailable => '',
    };
    final actionLabel =
        status == CerqleHandoffStatus.failed ? 'Try again' : 'Talk to an agent';
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 48),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      decoration: BoxDecoration(
        color: Color.alphaBlend(
          colors.primary.withValues(alpha: 0.08),
          colors.surface,
        ),
        border: Border(
            bottom: BorderSide(color: colors.primary.withValues(alpha: 0.16))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
          ] else ...<Widget>[
            Icon(Icons.headset_mic_outlined,
                size: 16, color: colors.onSurfaceMuted),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Text(
              prompt,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceMuted,
                  ),
            ),
          ),
          if (isActionable) ...<Widget>[
            const SizedBox(width: 8),
            Semantics(
              button: true,
              label: status == CerqleHandoffStatus.failed
                  ? 'Try human agent again'
                  : 'Request a human agent',
              child: TextButton(
                onPressed: onPressed,
                style: TextButton.styleFrom(
                  foregroundColor: colors.primary,
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
