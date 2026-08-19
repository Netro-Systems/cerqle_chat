part of 'models.dart';

/// Lifecycle phase of a chat controller.
enum CerqleChatPhase {
  idle,
  initializing,
  awaitingPreChat,
  ready,
  reconnecting,
  expired,
  failure,
  disposed,
}

/// Network synchronization state, separate from support availability.
enum CerqleConnectionState { disconnected, connecting, connected, reconnecting }

/// Working-hours availability reported by the backend.
enum CerqleSupportAvailability { unknown, available, unavailable }

/// Immutable snapshot emitted by a chat controller.
class CerqleChatState {
  /// Creates a state snapshot and defensively copies [messages].
  CerqleChatState({
    required this.phase,
    required List<CerqleMessage> messages,
    required this.connection,
    required this.widget,
    required this.handoff,
    required this.supportAvailability,
    required this.visitorTyping,
    required this.agentTyping,
    required this.pendingCount,
    this.error,
  }) : messages = List<CerqleMessage>.unmodifiable(messages);

  /// Creates the initial disconnected state.
  factory CerqleChatState.initial() => CerqleChatState(
    phase: CerqleChatPhase.idle,
    messages: const <CerqleMessage>[],
    connection: CerqleConnectionState.disconnected,
    widget: null,
    handoff: const CerqleHandoffState.unavailable(),
    supportAvailability: CerqleSupportAvailability.unknown,
    visitorTyping: false,
    agentTyping: null,
    pendingCount: 0,
  );

  /// Session lifecycle phase.
  final CerqleChatPhase phase;

  /// Ordered, deduplicated messages.
  final List<CerqleMessage> messages;

  /// Network synchronization status.
  final CerqleConnectionState connection;

  /// Server widget configuration after initialization.
  final CerqleWidgetConfig? widget;

  /// Backend-authoritative handoff state.
  final CerqleHandoffState handoff;

  /// Support working-hours availability.
  final CerqleSupportAvailability supportAvailability;

  /// Whether the controller last published visitor typing as active.
  final bool visitorTyping;

  /// Current agent typing state, if active.
  final CerqleAgentTyping? agentTyping;

  /// Number of pending or unconfirmed visitor messages.
  final int pendingCount;

  /// Current recoverable or terminal error.
  final CerqleException? error;

  /// Returns an updated immutable state snapshot.
  CerqleChatState copyWith({
    CerqleChatPhase? phase,
    List<CerqleMessage>? messages,
    CerqleConnectionState? connection,
    Object? widget = _notProvided,
    CerqleHandoffState? handoff,
    CerqleSupportAvailability? supportAvailability,
    bool? visitorTyping,
    Object? agentTyping = _notProvided,
    int? pendingCount,
    Object? error = _notProvided,
  }) => CerqleChatState(
    phase: phase ?? this.phase,
    messages: messages ?? this.messages,
    connection: connection ?? this.connection,
    widget: identical(widget, _notProvided)
        ? this.widget
        : widget as CerqleWidgetConfig?,
    handoff: handoff ?? this.handoff,
    supportAvailability: supportAvailability ?? this.supportAvailability,
    visitorTyping: visitorTyping ?? this.visitorTyping,
    agentTyping: identical(agentTyping, _notProvided)
        ? this.agentTyping
        : agentTyping as CerqleAgentTyping?,
    pendingCount: pendingCount ?? this.pendingCount,
    error: identical(error, _notProvided)
        ? this.error
        : error as CerqleException?,
  );
}

const Object _notProvided = Object();
