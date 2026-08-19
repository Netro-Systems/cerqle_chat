part of 'models.dart';

/// Message direction represented by the visitor API.
enum CerqleMessageRole { visitor, agent, unknown }

/// Supported message content categories.
enum CerqleMessageType { text, image, audio, file, unknown }

/// Delivery state of a message in controller state.
enum CerqleMessageStatus { pending, sent, failed, unconfirmed }

/// Backend-reported sender category.
enum CerqleSenderKind { visitor, bot, human, automation, broadcast, unknown }

/// Immutable chat message visible to headless and prebuilt integrations.
class CerqleMessage {
  /// Creates a message with local and optional server identity.
  const CerqleMessage({
    required this.localId,
    required this.role,
    required this.type,
    required this.body,
    required this.status,
    required this.createdAt,
    this.serverId,
    this.attachment,
    this.localUpload,
    this.senderName,
    this.sentBy,
    this.error,
  });

  /// SDK-local identity used while a send is pending.
  final String localId;

  /// Authoritative server identity, when confirmed.
  final int? serverId;

  /// Message direction.
  final CerqleMessageRole role;

  /// Content category.
  final CerqleMessageType type;

  /// Plain-text body or caption.
  final String body;

  /// Current delivery state.
  final CerqleMessageStatus status;

  /// Message creation time.
  final DateTime createdAt;

  /// Optional attachment metadata.
  final CerqleAttachment? attachment;

  /// Optional in-memory upload used for local pending media previews.
  final CerqleUpload? localUpload;

  /// Optional backend-supplied sender name.
  final String? senderName;

  /// Optional backend-supplied sender category.
  final CerqleSenderKind? sentBy;

  /// Safe delivery failure, when applicable.
  final CerqleException? error;

  /// Returns an updated immutable message.
  CerqleMessage copyWith({
    String? localId,
    int? serverId,
    CerqleMessageRole? role,
    CerqleMessageType? type,
    String? body,
    CerqleMessageStatus? status,
    DateTime? createdAt,
    CerqleAttachment? attachment,
    CerqleUpload? localUpload,
    String? senderName,
    CerqleSenderKind? sentBy,
    CerqleException? error,
    bool clearError = false,
  }) => CerqleMessage(
    localId: localId ?? this.localId,
    serverId: serverId ?? this.serverId,
    role: role ?? this.role,
    type: type ?? this.type,
    body: body ?? this.body,
    status: status ?? this.status,
    createdAt: createdAt ?? this.createdAt,
    attachment: attachment ?? this.attachment,
    localUpload: localUpload ?? this.localUpload,
    senderName: senderName ?? this.senderName,
    sentBy: sentBy ?? this.sentBy,
    error: clearError ? null : error ?? this.error,
  );
}
