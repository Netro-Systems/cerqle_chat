part of 'models.dart';

/// Server-configured launcher alignment.
enum CerqleLauncherPosition { bottomRight, bottomLeft, unknown }

/// Pre-chat fields currently understood by the SDK.
enum CerqlePreChatField { name, email, unknown }

/// Public team-member presentation data returned by widget configuration.
class CerqleTeamMember {
  /// Creates immutable team-member presentation data.
  const CerqleTeamMember({required this.name, this.avatarUrl});

  /// Display name.
  final String name;

  /// Optional avatar URL.
  final Uri? avatarUrl;
}

/// Immutable public widget configuration returned by the session API.
///
/// Collection fields are defensively copied and cannot be mutated by callers.
class CerqleWidgetConfig {
  /// Creates parsed widget configuration.
  CerqleWidgetConfig({
    required this.title,
    required this.subtitle,
    required this.welcomeMessage,
    required this.agentName,
    required this.primaryColorHex,
    required this.launcherPosition,
    required this.footerCompanyName,
    required List<CerqleTeamMember> teamMembers,
    required this.aiEnabled,
    required this.requiresPreChat,
    required List<CerqlePreChatField> preChatFields,
    this.avatarUrl,
    this.launcherText,
    this.launcherLogoUrl,
    this.offlineMessage,
  }) : teamMembers = List<CerqleTeamMember>.unmodifiable(teamMembers),
       preChatFields = List<CerqlePreChatField>.unmodifiable(preChatFields);

  /// Header title.
  final String title;

  /// Header subtitle.
  final String subtitle;

  /// Introductory welcome text; this is not conversation history.
  final String welcomeMessage;

  /// Generic support name configured for the widget.
  final String agentName;

  /// Optional header avatar URL.
  final Uri? avatarUrl;

  /// Server primary color in hexadecimal notation.
  final String primaryColorHex;

  /// Preferred floating-launcher alignment.
  final CerqleLauncherPosition launcherPosition;

  /// Optional launcher label.
  final String? launcherText;

  /// Optional launcher image URL.
  final Uri? launcherLogoUrl;

  /// Footer company label.
  final String footerCompanyName;

  /// Team members shown by supported presentations.
  final List<CerqleTeamMember> teamMembers;

  /// Whether the widget has active AI support.
  final bool aiEnabled;

  /// Whether the backend requires pre-chat submission.
  final bool requiresPreChat;

  /// Required pre-chat fields.
  final List<CerqlePreChatField> preChatFields;

  /// Server message shown outside working hours.
  final String? offlineMessage;
}
