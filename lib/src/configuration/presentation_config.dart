part of 'cerqle_config.dart';

/// Supported modal presentation styles for [CerqleChat.open].
enum CerqlePresentation { fullScreen, bottomSheet, dialog }

/// Result returned when a prebuilt chat presentation closes.
@immutable
class CerqleChatResult {
  /// Creates a result with the authoritative close [reason].
  const CerqleChatResult({required this.reason});

  /// Reason the presentation closed.
  final CerqleChatCloseReason reason;
}
