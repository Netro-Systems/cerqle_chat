part of 'models.dart';

/// Current human-support handoff state reported by the backend.
enum CerqleHandoffStatus {
  unavailable,
  eligible,
  requesting,
  connected,
  failed,
}

/// Immutable handoff state exposed by the controller.
class CerqleHandoffState {
  /// Creates a handoff state with an optional safe [error].
  const CerqleHandoffState({required this.status, this.error});

  /// Creates the default state when handoff is not available.
  const CerqleHandoffState.unavailable()
    : status = CerqleHandoffStatus.unavailable,
      error = null;

  /// Backend-authoritative handoff status.
  final CerqleHandoffStatus status;

  /// Recoverable failure associated with a handoff request.
  final CerqleException? error;
}
