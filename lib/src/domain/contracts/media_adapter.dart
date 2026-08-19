import '../models/models.dart';

/// Host-supplied bridge for the optional platform UI used by the default
/// composer to choose images and record microphone audio.
///
/// The SDK owns upload and message state. Implementations own platform picker
/// and recorder dependencies, permissions, and temporary resources.
abstract interface class CerqleMediaAdapter {
  /// Opens the host image picker and returns null when selection is cancelled.
  Future<CerqleUpload?> pickImage();

  /// Starts a host-owned microphone recording session.
  Future<void> startAudioRecording();

  /// Stops recording and returns audio, or null when no recording is available.
  Future<CerqleUpload?> stopAudioRecording();

  /// Cancels recording and releases host-owned temporary resources.
  Future<void> cancelAudioRecording();
}
