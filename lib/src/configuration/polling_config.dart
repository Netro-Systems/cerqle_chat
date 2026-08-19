part of 'cerqle_config.dart';

/// Foreground polling intervals used by [CerqleChatController].
@immutable
class CerqlePollingConfig {
  /// Creates polling configuration with conservative mobile-friendly defaults.
  const CerqlePollingConfig({
    this.visibleInterval = const Duration(seconds: 3),
    this.idleInterval = const Duration(seconds: 8),
    this.failureMaxInterval = const Duration(seconds: 30),
  });

  /// Interval while the conversation has recent activity.
  final Duration visibleInterval;

  /// Interval after the conversation becomes idle.
  final Duration idleInterval;

  /// Maximum delay used by failure backoff.
  final Duration failureMaxInterval;
}
