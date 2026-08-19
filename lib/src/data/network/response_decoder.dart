import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../domain/contracts/session_store.dart';
import '../../domain/errors/cerqle_exception.dart';
import '../../domain/models/models.dart';
import 'widget_results.dart';

/// Strictly decodes visitor API responses into immutable SDK values.
///
/// Raw JSON and response bodies never leave this data-layer component.
final class WidgetResponseDecoder {
  /// Creates the stateless response decoder.
  const WidgetResponseDecoder();

  /// Decodes a session creation or restoration response.
  WidgetSessionResult session(
    http.Response response, {
    required bool preChatCompleted,
  }) {
    final json = _decodeObject(response);
    final visitorId = _requiredString(json, 'visitor_id');
    final token = _requiredString(json, 'token');
    final conversationId = _intOrNull(json['conversation_id']) ??
        _intOrNull(json['conversation']?['id']) ??
        0;
    final configJson = _requiredObject(json, 'config');
    final handoffObj = json['handoff'] ?? json['handover'];
    if (handoffObj == null) throw _invalidResponse();
    return WidgetSessionResult(
      session: CerqleStoredSession(
        visitorId: visitorId,
        token: token,
        savedAt: DateTime.now().toUtc(),
        preChatCompleted: preChatCompleted,
      ),
      conversationId: conversationId,
      widget: _parseWidgetConfig(configJson),
      messages: _parseMessages(json['messages']),
      supportAvailability: _parseAvailability(json['online'] == true),
      handoff: _parseHandoff(handoffObj),
    );
  }

  /// Decodes one forward-poll response.
  WidgetPollResult poll(http.Response response) {
    final json = _decodeObject(response);
    if (json['messages'] is! List<dynamic>) throw _invalidResponse();
    final typing = json['agent_typing'];
    final isTyping =
        typing is Map<String, dynamic> && typing['is_typing'] == true;
    final typingName = typing is Map<String, dynamic> ? typing['name'] : null;
    final handoffObj = json['handoff'] ?? json['handover'];
    if (handoffObj == null) throw _invalidResponse();
    return WidgetPollResult(
      messages: _parseMessages(json['messages']),
      supportAvailability: _parseAvailability(json['online'] == true),
      handoff: _parseHandoff(handoffObj),
      agentTyping: isTyping
          ? CerqleAgentTyping(name: typingName is String ? typingName : null)
          : null,
    );
  }

  /// Decodes a visitor-send confirmation.
  WidgetSendResult send(http.Response response) {
    final json = _decodeObject(response);
    final messageJson = _objectOrNull(json['message']) ?? json;
    final message = _parseMessage(messageJson);
    if (message == null) {
      throw const CerqleException(
        code: CerqleErrorCode.server,
        message: 'Cerqle returned an invalid message.',
        retryable: false,
      );
    }
    final handoffObj = json['handoff'] ?? json['handover'];
    return WidgetSendResult(
      message: message,
      handoff: _parseHandoff(handoffObj),
    );
  }

  /// Decodes a handoff response.
  CerqleHandoffState handoff(http.Response response) {
    final json = _decodeObject(response);
    return _parseHandoff(json['handoff'] ?? json['handover']);
  }

  /// Decodes the widget-safe realtime payload for one created message.
  CerqleMessage? realtimeMessage(Object? value) {
    if (value is! Map<String, dynamic>) return null;
    final messageJson = value['message'];
    if (messageJson is! Map<String, dynamic>) return null;
    return _parseMessage(messageJson);
  }

  /// Decodes the widget-safe realtime payload for agent typing changes.
  CerqleAgentTyping? realtimeTyping(Object? value) {
    if (value is! Map<String, dynamic>) return null;
    final typing = value['agent_typing'];
    if (typing is! Map<String, dynamic>) return null;
    final isTyping = typing['is_typing'];
    if (isTyping is! bool) return null;
    final name = typing['name'];
    if (name != null && name is! String) return null;
    return isTyping ? CerqleAgentTyping(name: name as String?) : null;
  }

  /// Decodes the widget-safe realtime payload for human-handoff updates.
  CerqleHandoffState? realtimeHandoff(Object? value) {
    if (value is! Map<String, dynamic>) return null;
    final handoff = value['handoff'];
    if (handoff is! Map<String, dynamic>) return null;
    return _parseHandoff(handoff);
  }

  Map<String, dynamic> _decodeObject(http.Response response) {
    try {
      final value = jsonDecode(utf8.decode(response.bodyBytes));
      if (value is Map<String, dynamic>) return value;
    } on Object {
      // The safe typed failure below deliberately excludes response contents.
    }
    throw CerqleException(
      code: CerqleErrorCode.server,
      message: 'Cerqle returned an invalid response.',
      retryable: response.statusCode >= 500,
      httpStatus: response.statusCode,
    );
  }

  List<CerqleMessage> _parseMessages(Object? value) {
    if (value is! List<dynamic>) {
      throw const CerqleException(
        code: CerqleErrorCode.server,
        message: 'Cerqle returned an incomplete response.',
        retryable: false,
      );
    }
    final messages = <CerqleMessage>[];
    for (final item in value) {
      if (item is! Map<String, dynamic>) {
        throw const CerqleException(
          code: CerqleErrorCode.server,
          message: 'Cerqle returned an invalid message.',
          retryable: false,
        );
      }
      final message = _parseMessage(item);
      if (message == null) {
        throw const CerqleException(
          code: CerqleErrorCode.server,
          message: 'Cerqle returned an invalid message.',
          retryable: false,
        );
      }
      messages.add(message);
    }
    return messages;
  }

  CerqleMessage? _parseMessage(Map<String, dynamic> json) {
    final rawId = json['id'];
    final id = rawId is int && rawId > 0 ? rawId : null;
    final createdAt = DateTime.tryParse(
      _stringOrNull(json['created_at']) ?? '',
    );
    if (id == null || createdAt == null || json['body'] is! String) return null;
    final role = switch (json['role']) {
      'visitor' => CerqleMessageRole.visitor,
      'agent' => CerqleMessageRole.agent,
      _ => CerqleMessageRole.unknown,
    };
    final type = switch (json['type']) {
      'text' => CerqleMessageType.text,
      'image' => CerqleMessageType.image,
      'audio' => CerqleMessageType.audio,
      'file' => CerqleMessageType.file,
      _ => CerqleMessageType.unknown,
    };
    final sentBy = role == CerqleMessageRole.visitor
        ? CerqleSenderKind.visitor
        : switch (json['sent_by']) {
            'human' => CerqleSenderKind.human,
            'bot' => CerqleSenderKind.bot,
            'automation' => CerqleSenderKind.automation,
            'broadcast' => CerqleSenderKind.broadcast,
            _ => CerqleSenderKind.unknown,
          };
    final attachmentUri = _safeRemoteUri(json['attachment_url']);
    return CerqleMessage(
      localId: 'server-$id',
      serverId: id,
      role: role,
      type: type,
      body: json['body'] as String,
      status: CerqleMessageStatus.sent,
      createdAt: createdAt.toLocal(),
      attachment: attachmentUri == null
          ? null
          : CerqleAttachment(
              url: attachmentUri,
              filename: _stringOrNull(json['filename']),
              mimeType: _stringOrNull(json['mime_type']),
            ),
      senderName: role == CerqleMessageRole.agent
          ? _stringOrNull(json['agent_name'])
          : null,
      sentBy: sentBy,
    );
  }

  CerqleWidgetConfig _parseWidgetConfig(Map<String, dynamic> json) {
    final members = <CerqleTeamMember>[];
    final rawMembers = json['team_members'] ??
        (json['available_team'] is Map<String, dynamic>
            ? (json['available_team'] as Map<String, dynamic>)['members']
            : null);
    if (rawMembers is List<dynamic>) {
      for (final item in rawMembers.whereType<Map<String, dynamic>>().take(5)) {
        final name = _stringOrNull(item['name']);
        if (name != null && name.isNotEmpty) {
          members.add(
            CerqleTeamMember(
              name: name,
              avatarUrl: _safeRemoteUri(item['avatar_url']),
            ),
          );
        }
      }
    }
    final preChatFields = <CerqlePreChatField>[];
    final rawFields = json['prechat_fields'];
    if (rawFields is List<dynamic>) {
      for (final field in rawFields) {
        preChatFields.add(switch (field) {
          'name' => CerqlePreChatField.name,
          'email' => CerqlePreChatField.email,
          _ => CerqlePreChatField.unknown,
        });
      }
    }
    final rawColor = _stringOrNull(json['primary_color']) ?? '#3E2A49';
    final color = RegExp(r'^#[0-9a-fA-F]{6}$').hasMatch(rawColor)
        ? rawColor
        : '#3E2A49';
    return CerqleWidgetConfig(
      title: _stringOrNull(json['title']) ?? 'Chat with us',
      subtitle:
          _stringOrNull(json['subtitle']) ??
          'We typically reply in a few minutes',
      welcomeMessage:
          _stringOrNull(json['welcome_message']) ??
          'Hi there! How can we help?',
      agentName: _stringOrNull(json['agent_name']) ?? 'Support',
      avatarUrl: _safeRemoteUri(json['avatar_url']),
      primaryColorHex: color,
      launcherPosition: switch (json['position']) {
        'bottom_right' => CerqleLauncherPosition.bottomRight,
        'bottom_left' => CerqleLauncherPosition.bottomLeft,
        _ => CerqleLauncherPosition.unknown,
      },
      launcherText: _stringOrNull(json['launcher_text']),
      launcherLogoUrl: _safeRemoteUri(json['launcher_logo_url']),
      footerCompanyName: _stringOrNull(json['footer_company_name']) ?? 'Cerqle',
      teamMembers: members,
      aiEnabled: json['ai_enabled'] == true,
      requiresPreChat: json['require_prechat'] == true,
      preChatFields: preChatFields,
      realtime: _parseRealtimeConfig(json['realtime']),
      offlineMessage: _stringOrNull(json['offline_message']),
    );
  }

  CerqleRealtimeConfig? _parseRealtimeConfig(Object? value) {
    if (value is! Map<String, dynamic>) return null;
    final authEndpoint = _safeRemoteUri(value['auth_endpoint']);
    if (authEndpoint == null) return null;
    return CerqleRealtimeConfig(
      key: _stringOrNull(value['key']) ?? '',
      cluster: _stringOrNull(value['cluster']) ?? 'mt1',
      authEndpoint: authEndpoint,
    );
  }

  CerqleHandoffState _parseHandoff(Object? value) {
    if (value is! Map<String, dynamic>) {
      return const CerqleHandoffState.unavailable();
    }
    final enabled = value['enabled'] == true || value['available'] == true;
    final eligible = value['eligible'] == true ||
        (value['available'] == true && value['requested'] != true);
    final statusStr = value['status'] as String? ??
        (value['requested'] == true ? 'connected' : 'bot');
    if (!enabled) {
      return const CerqleHandoffState.unavailable();
    }
    if (statusStr == 'connected') {
      return const CerqleHandoffState(status: CerqleHandoffStatus.connected);
    }
    if (eligible) {
      return const CerqleHandoffState(status: CerqleHandoffStatus.eligible);
    }
    return const CerqleHandoffState(status: CerqleHandoffStatus.unavailable);
  }

  CerqleSupportAvailability _parseAvailability(Object? value) =>
      switch (value) {
        true => CerqleSupportAvailability.available,
        false => CerqleSupportAvailability.unavailable,
        _ => CerqleSupportAvailability.unknown,
      };

  Map<String, dynamic> _requiredObject(Map<String, dynamic> json, String key) {
    final value = _objectOrNull(json[key]);
    if (value != null) return value;
    throw _invalidResponse();
  }

  CerqleException _invalidResponse() => const CerqleException(
    code: CerqleErrorCode.server,
    message: 'Cerqle returned an incomplete response.',
    retryable: false,
  );

  Map<String, dynamic>? _objectOrNull(Object? value) =>
      value is Map<String, dynamic> ? value : null;

  String _requiredString(Map<String, dynamic> json, String key) {
    final value = _stringOrNull(json[key]);
    if (value != null && value.isNotEmpty) return value;
    throw const CerqleException(
      code: CerqleErrorCode.server,
      message: 'Cerqle returned an incomplete response.',
      retryable: false,
    );
  }

  int? _intOrNull(Object? value) {
    if (value is int) return value;
    if (value is String) return int.tryParse(value);
    return null;
  }

  String? _stringOrNull(Object? value) => value is String ? value : null;

  Uri? _safeRemoteUri(Object? value) {
    if (value is! String || value.isEmpty) return null;
    final uri = Uri.tryParse(value);
    if (uri == null || !uri.isAbsolute) return null;
    if (uri.scheme != 'https' && (kReleaseMode || uri.scheme != 'http')) {
      return null;
    }
    return uri;
  }
}
