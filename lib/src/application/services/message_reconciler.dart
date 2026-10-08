import '../../domain/models/models.dart';

/// Pure ordering and server-ID reconciliation for immutable message lists.
///
/// Server IDs are authoritative. Local IDs remain attached when a later
/// server representation replaces an existing entry.
final class MessageReconciler {
  const MessageReconciler();

  List<CerqleMessage> merge(
    List<CerqleMessage> existing,
    List<CerqleMessage> incoming, {
    void Function(CerqleMessage message)? onNewAgentMessage,
  }) {
    final messages = <CerqleMessage>[...existing];
    final indexes = <int, int>{};
    for (var index = 0; index < messages.length; index++) {
      final id = messages[index].serverId;
      if (id != null) indexes[id] = index;
    }
    for (final message in incoming) {
      final id = message.serverId;
      if (id == null) continue;
      final existingIndex = indexes[id];
      if (existingIndex == null) {
        indexes[id] = messages.length;
        messages.add(message);
        if (message.role == CerqleMessageRole.agent && !message.isActivity) {
          onNewAgentMessage?.call(message);
        }
      } else {
        final existingMessage = messages[existingIndex];
        messages[existingIndex] = message.copyWith(
          localId: existingMessage.localId,
          localUpload: existingMessage.localUpload,
          status: _mostAdvancedStatus(
            existingMessage.status,
            message.status,
          ),
        );
      }
    }
    messages.sort(compare);
    return messages;
  }

  int greatestServerId(List<CerqleMessage> messages, {required int fallback}) =>
      messages.fold<int>(
        fallback,
        (greatest, message) => message.serverId == null
            ? greatest
            : greatest > message.serverId!
                ? greatest
                : message.serverId!,
      );

  int compare(CerqleMessage a, CerqleMessage b) {
    final aId = a.serverId;
    final bId = b.serverId;
    if (aId != null && bId != null) return aId.compareTo(bId);
    if (aId != null) return -1;
    if (bId != null) return 1;
    final time = a.createdAt.compareTo(b.createdAt);
    return time != 0 ? time : a.localId.compareTo(b.localId);
  }

  CerqleMessageStatus _mostAdvancedStatus(
    CerqleMessageStatus current,
    CerqleMessageStatus incoming,
  ) {
    if (current == incoming) return current;
    if (incoming == CerqleMessageStatus.failed) {
      return current == CerqleMessageStatus.delivered ||
              current == CerqleMessageStatus.read
          ? current
          : incoming;
    }
    if (current == CerqleMessageStatus.failed) return current;
    const rank = <CerqleMessageStatus, int>{
      CerqleMessageStatus.pending: 0,
      CerqleMessageStatus.unconfirmed: 0,
      CerqleMessageStatus.sent: 1,
      CerqleMessageStatus.delivered: 2,
      CerqleMessageStatus.read: 3,
      CerqleMessageStatus.failed: -1,
    };
    return rank[incoming]! > rank[current]! ? incoming : current;
  }
}
