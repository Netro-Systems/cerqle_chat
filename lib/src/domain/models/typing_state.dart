part of 'models.dart';

/// Agent typing state reported by the latest poll response.
class CerqleAgentTyping {
  /// Creates an active typing state with an optional safe display name.
  const CerqleAgentTyping({this.name});

  /// Backend-supplied agent display name, when available.
  final String? name;
}
