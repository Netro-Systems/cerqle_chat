import '../../domain/contracts/session_store.dart';
import '../../domain/models/models.dart';

/// Parsed result of creating or restoring a visitor session.
///
/// This transport-facing aggregate remains internal to the SDK and keeps raw
/// response maps from crossing the data boundary.
final class WidgetSessionResult {
  /// Creates a fully decoded session result.
  WidgetSessionResult({
    required this.session,
    required this.widget,
    required this.messages,
    required this.supportAvailability,
    required this.handoff,
  });

  /// Secure visitor credentials returned by the backend.
  final CerqleStoredSession session;

  /// Backend-authoritative widget configuration.
  final CerqleWidgetConfig widget;

  /// Initial ordered conversation batch.
  final List<CerqleMessage> messages;

  /// Current working-hours availability.
  final CerqleSupportAvailability supportAvailability;

  /// Current human-handoff state.
  final CerqleHandoffState handoff;
}

/// Parsed result of one forward-poll page.
final class WidgetPollResult {
  /// Creates a fully decoded poll result.
  WidgetPollResult({
    required this.messages,
    required this.supportAvailability,
    required this.handoff,
    required this.agentTyping,
  });

  /// Messages returned after the requested receive cursor.
  final List<CerqleMessage> messages;

  /// Current working-hours availability.
  final CerqleSupportAvailability supportAvailability;

  /// Current human-handoff state.
  final CerqleHandoffState handoff;

  /// Current agent typing state, or null when inactive.
  final CerqleAgentTyping? agentTyping;
}

/// Parsed server confirmation for a visitor send.
final class WidgetSendResult {
  /// Creates a decoded send result.
  WidgetSendResult({required this.message, required this.handoff});

  /// Backend-confirmed visitor message.
  final CerqleMessage message;

  /// Handoff state returned alongside the send.
  final CerqleHandoffState handoff;
}
