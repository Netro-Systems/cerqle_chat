import '../models/models.dart';

/// Override for the platform media behavior used by the default composer.
///
/// The SDK provides a built-in implementation. Supply a custom implementation
/// only when the host app needs different picker or recorder behavior. The SDK
/// continues to own upload and message state; custom implementations own their
/// platform dependencies, permissions, and temporary resources.
abstract interface class CerqleMediaAdapter {
  /// Opens an image picker and returns null when selection is cancelled.
  Future<CerqleUpload?> pickImage();

  /// Opens a document picker and returns null when selection is cancelled.
  Future<CerqleUpload?> pickDocument();

  /// Starts a microphone recording session.
  Future<void> startAudioRecording();

  /// Stops recording and returns audio, or null when no recording is available.
  Future<CerqleUpload?> stopAudioRecording();

  /// Cancels recording and releases temporary resources.
  Future<void> cancelAudioRecording();
}
