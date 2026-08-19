part of 'models.dart';

/// Visitor values submitted for backend-required pre-chat fields.
class CerqlePreChatData {
  /// Creates pre-chat values. Required fields are validated by the controller.
  const CerqlePreChatData({this.name, this.email});

  /// Visitor name.
  final String? name;

  /// Visitor email address.
  final String? email;
}
