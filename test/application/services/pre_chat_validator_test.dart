import 'package:flutter_test/flutter_test.dart';
import 'package:cerqle_chat/cerqle_chat.dart';
import 'package:cerqle_chat/src/application/services/pre_chat_validator.dart';

void main() {
  const validator = PreChatValidator();

  test('accepts required values supplied by the active user', () {
    expect(
      validator.isSatisfiedBy(
        _widget(<CerqlePreChatField>[
          CerqlePreChatField.name,
          CerqlePreChatField.email,
        ]),
        const CerqleUser(name: 'Visitor', email: 'visitor@example.com'),
      ),
      isTrue,
    );
  });

  test('rejects unknown backend requirements as unsupported', () {
    expect(
      () => validator.validateConfiguration(
        _widget(<CerqlePreChatField>[CerqlePreChatField.unknown]),
      ),
      throwsA(
        isA<CerqleException>().having(
          (error) => error.code,
          'code',
          CerqleErrorCode.unsupported,
        ),
      ),
    );
  });
}

CerqleWidgetConfig _widget(List<CerqlePreChatField> fields) =>
    CerqleWidgetConfig(
      title: 'Support',
      subtitle: 'Online',
      welcomeMessage: 'Hello',
      agentName: 'Support',
      primaryColorHex: '#ff762e',
      launcherPosition: CerqleLauncherPosition.bottomRight,
      footerCompanyName: 'Cerqle',
      teamMembers: const <CerqleTeamMember>[],
      aiEnabled: true,
      requiresPreChat: true,
      preChatFields: fields,
    );
