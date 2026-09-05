import 'dart:async';

import 'package:flutter/material.dart';

import '../../application/cerqle_runtime.dart';
import '../../configuration/cerqle_config.dart';
import '../../domain/events/chat_event.dart';
import '../view/chat_view.dart';

/// Full-screen scaffold integration for the prebuilt chat experience.
class CerqleChatScreen extends StatefulWidget {
  /// Creates a full-screen chat.
  ///
  /// When [controller] is omitted, the screen owns and disposes its runtime.
  const CerqleChatScreen({
    super.key,
    required this.config,
    this.controller,
    this.appBar,
    this.onClosed,
  });

  /// Widget and visitor configuration.
  final CerqleConfig config;

  /// Optional host-owned controller.
  final CerqleChatController? controller;

  /// Optional host-owned app bar replacing the built-in header.
  final PreferredSizeWidget? appBar;

  /// Called once when this presentation closes.
  final ValueChanged<CerqleChatCloseReason>? onClosed;

  @override
  State<CerqleChatScreen> createState() => _CerqleChatScreenState();
}

class _CerqleChatScreenState extends State<CerqleChatScreen> {
  late CerqleChatController _controller;
  CerqleClient? _ownedClient;
  bool _closed = false;

  @override
  void initState() {
    super.initState();
    final supplied = widget.controller;
    if (supplied == null) {
      final client = CerqleClient(config: widget.config);
      _ownedClient = client;
      _controller = CerqleChatController(client: client);
    } else {
      _controller = supplied;
    }
    _controller.handlePresentationOpened();
  }

  @override
  Widget build(BuildContext context) {
    final usesBrandedHeader = widget.appBar == null;
    final navigator = Navigator.of(context);
    return Scaffold(
      appBar: widget.appBar,
      body: CerqleChatView(
        config: widget.config,
        controller: _controller,
        showHeader: usesBrandedHeader,
        onClose: usesBrandedHeader && navigator.canPop()
            ? () => navigator.maybePop()
            : null,
      ),
    );
  }

  void _notifyClosed() {
    if (_closed) return;
    _closed = true;
    const reason = CerqleChatCloseReason.userClosed;
    _controller.handlePresentationClosed(reason);
    widget.onClosed?.call(reason);
  }

  @override
  void dispose() {
    _notifyClosed();
    final client = _ownedClient;
    if (client != null) {
      unawaited(_controller.dispose().then((_) => client.close()));
    }
    super.dispose();
  }
}
