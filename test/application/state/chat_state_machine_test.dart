import 'package:flutter_test/flutter_test.dart';
import 'package:cerqle_chat/cerqle_chat.dart';
import 'package:cerqle_chat/src/application/state/chat_state_machine.dart';

void main() {
  test('owns and replaces immutable controller snapshots', () {
    final machine = ChatStateMachine();
    expect(machine.state.phase, CerqleChatPhase.idle);

    final ready = machine.state.copyWith(phase: CerqleChatPhase.ready);
    machine.replace(ready);

    expect(machine.state, same(ready));
  });
}
