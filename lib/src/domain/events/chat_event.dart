import '../models/models.dart';

/// Base type for lifecycle and message events emitted by a chat controller.
sealed class CerqleChatEvent {
  /// Creates a chat event.
  const CerqleChatEvent();
}

/// Describes why a prebuilt chat presentation was closed.
enum CerqleChatCloseReason { userClosed, sessionReset, configurationFailure }

/// Emitted after a session becomes ready for messaging.
final class CerqleSessionReady extends CerqleChatEvent {
  /// Creates a session-ready event.
  const CerqleSessionReady();
}

/// Emitted when a prebuilt presentation opens.
final class CerqleChatOpened extends CerqleChatEvent {
  /// Creates a presentation-opened event.
  const CerqleChatOpened();
}

/// Emitted when a prebuilt presentation closes.
final class CerqleChatClosed extends CerqleChatEvent {
  /// Creates a close event with its [reason].
  const CerqleChatClosed({required this.reason});

  /// Reason reported by the presentation.
  final CerqleChatCloseReason reason;
}

/// Emitted after a visitor message is confirmed by the backend.
final class CerqleMessageSent extends CerqleChatEvent {
  /// Creates a sent-message event.
  const CerqleMessageSent({required this.message});

  /// Confirmed visitor message.
  final CerqleMessage message;
}

/// Emitted for a newly reconciled incoming message.
final class CerqleMessageReceived extends CerqleChatEvent {
  /// Creates a received-message event.
  const CerqleMessageReceived({required this.message});

  /// Newly received message.
  final CerqleMessage message;
}

/// Emitted when the backend-authoritative handoff state changes.
final class CerqleHandoffChanged extends CerqleChatEvent {
  /// Creates a handoff change event.
  const CerqleHandoffChanged({required this.handoff});

  /// Updated handoff state.
  final CerqleHandoffState handoff;
}

/// Emitted when network synchronization state changes.
final class CerqleConnectionChanged extends CerqleChatEvent {
  /// Creates a connection change event.
  const CerqleConnectionChanged({required this.connection});

  /// Updated connection state.
  final CerqleConnectionState connection;
}
