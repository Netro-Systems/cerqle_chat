import 'dart:async';

import '../application/cerqle_runtime.dart';
import '../configuration/cerqle_config.dart';

abstract final class UnreadControllerRegistry {
  static final Map<String, Set<CerqleChatController>> _controllers =
      <String, Set<CerqleChatController>>{};

  static String register({
    required CerqleConfig config,
    required CerqleChatController controller,
  }) {
    final scope = cerqlePresentationScope(config);
    (_controllers[scope] ??= <CerqleChatController>{}).add(controller);
    return scope;
  }

  static void unregister(
    String scope,
    CerqleChatController controller,
  ) {
    final controllers = _controllers[scope];
    controllers?.remove(controller);
    if (controllers?.isEmpty == true) _controllers.remove(scope);
  }

  static CerqleChatController? first(String scope) {
    final controllers = _controllers[scope];
    return controllers == null || controllers.isEmpty
        ? null
        : controllers.first;
  }

  static void markRead(String scope) {
    final controllers = _controllers[scope];
    if (controllers == null) return;
    for (final controller in List<CerqleChatController>.of(controllers)) {
      unawaited(controller.markRead().catchError((_) {}));
    }
  }
}
