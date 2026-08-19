part of '../configuration/cerqle_config.dart';

/// Receives a redacted SDK diagnostic event.
typedef CerqleDiagnosticsCallback = void Function(CerqleDiagnosticEvent event);

/// Stable categories of redacted operational diagnostics.
enum CerqleDiagnosticKind { initialization, lifecycle, connection, poll, send }

/// A redacted operational event that contains no visitor or message content.
@immutable
class CerqleDiagnosticEvent {
  /// Creates a safe diagnostic event.
  const CerqleDiagnosticEvent({
    required this.kind,
    required this.occurredAt,
    this.duration,
    this.httpStatus,
    this.errorCode,
  });

  /// Operation category.
  final CerqleDiagnosticKind kind;

  /// UTC-compatible occurrence time supplied by the controller.
  final DateTime occurredAt;

  /// Optional operation duration.
  final Duration? duration;

  /// Optional HTTP status without a response body.
  final int? httpStatus;

  /// Optional safe SDK error category.
  final CerqleErrorCode? errorCode;
}
