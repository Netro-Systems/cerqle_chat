import '../../domain/models/models.dart';

/// Owns the current immutable controller snapshot.
///
/// Side effects remain in the controller; this type gives state ownership one
/// explicit seam for future transition validation without changing public API.
final class ChatStateMachine {
  CerqleChatState _state = CerqleChatState.initial();

  CerqleChatState get state => _state;

  void replace(CerqleChatState next) {
    _state = next;
  }
}
