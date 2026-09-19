part of '../view/chat_view.dart';

const Color _deliverySeen = Colors.white;

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.message,
    required this.controller,
    required this.widgetConfig,
    required this.colors,
    required this.onRetry,
    required this.onRemove,
  });

  final CerqleMessage message;
  final CerqleChatController controller;
  final CerqleWidgetConfig? widgetConfig;
  final CerqleResolvedTheme colors;
  final VoidCallback? onRetry;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final visitor = message.role == CerqleMessageRole.visitor;
    final deliveryLabel = visitor ? ', ${_deliveryLabel(message.status)}' : '';
    return Semantics(
      label:
          '${visitor ? 'Your' : 'Support'} message. ${message.body}$deliveryLabel',
      child: _BubbleLayout(
        visitor: visitor,
        widgetConfig: widgetConfig,
        colors: colors,
        isImage: message.type == CerqleMessageType.image,
        bubbleKey: ValueKey<String>(
          'cerqle-message-bubble-${message.localId}',
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            _MessageContent(
              message: message,
              colors: colors,
              controller: controller,
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.end,
              children: <Widget>[
                Text(
                  _time(message.createdAt),
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: visitor
                            ? colors.onVisitorBubble.withValues(alpha: 0.72)
                            : colors.onAgentBubble.withValues(alpha: 0.72),
                      ),
                ),
                if (visitor) ...<Widget>[
                  const SizedBox(width: 4),
                  Icon(
                    _deliveryIcon(message.status),
                    size: 14,
                    color: _deliveryColor(colors, message.status),
                  ),
                ],
              ],
            ),
            if (onRetry != null || onRemove != null) ...<Widget>[
              const SizedBox(height: 4),
              Wrap(
                spacing: 4,
                children: <Widget>[
                  if (onRetry != null)
                    TextButton(
                      style: _messageActionStyle(visitor, colors),
                      onPressed: onRetry,
                      child: const Text('Retry'),
                    ),
                  if (onRemove != null)
                    TextButton(
                      style: _messageActionStyle(visitor, colors),
                      onPressed: onRemove,
                      child: const Text('Remove'),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  ButtonStyle _messageActionStyle(
    bool visitor,
    CerqleResolvedTheme colors,
  ) =>
      TextButton.styleFrom(
        foregroundColor:
            visitor ? colors.onVisitorBubble : colors.onAgentBubble,
      );

  static String _time(DateTime value) {
    final hour = value.hour % 12 == 0 ? 12 : value.hour % 12;
    final minute = value.minute.toString().padLeft(2, '0');
    return '$hour:$minute ${value.hour >= 12 ? 'PM' : 'AM'}';
  }

  static String _deliveryLabel(CerqleMessageStatus status) => switch (status) {
        CerqleMessageStatus.pending => 'sending',
        CerqleMessageStatus.sent => 'sent',
        CerqleMessageStatus.delivered => 'delivered',
        CerqleMessageStatus.read => 'read',
        CerqleMessageStatus.failed => 'failed',
        CerqleMessageStatus.unconfirmed => 'delivery unconfirmed',
      };

  static IconData _deliveryIcon(CerqleMessageStatus status) => switch (status) {
        CerqleMessageStatus.pending => Icons.schedule,
        CerqleMessageStatus.sent => Icons.check,
        CerqleMessageStatus.delivered ||
        CerqleMessageStatus.read =>
          Icons.done_all,
        CerqleMessageStatus.failed => Icons.error_outline,
        CerqleMessageStatus.unconfirmed => Icons.help_outline,
      };

  static Color _deliveryColor(
    CerqleResolvedTheme colors,
    CerqleMessageStatus status,
  ) =>
      switch (status) {
        CerqleMessageStatus.pending =>
          colors.onVisitorBubble.withValues(alpha: 0.60),
        CerqleMessageStatus.sent ||
        CerqleMessageStatus.delivered ||
        CerqleMessageStatus.unconfirmed =>
          colors.onVisitorBubble.withValues(alpha: 0.72),
        CerqleMessageStatus.read => _deliverySeen,
        CerqleMessageStatus.failed => colors.error,
      };
}
