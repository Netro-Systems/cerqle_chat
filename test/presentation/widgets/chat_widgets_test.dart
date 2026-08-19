import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:cerqle_chat/cerqle_chat.dart';
import 'package:cerqle_chat/src/presentation/media/remote_image.dart';

import '../../support/support.dart';

part 'view_state_tests.dart';
part 'composer_handoff_tests.dart';
part 'launcher_tests.dart';
part 'presentation_layout_tests.dart';

void main() {
  const config = CerqleConfig(
    widgetKey: 'test-widget',
    apiBaseUrl: 'https://chat.example.com',
    polling: CerqlePollingConfig(
      visibleInterval: Duration(minutes: 1),
      idleInterval: Duration(minutes: 1),
      failureMaxInterval: Duration(minutes: 1),
    ),
  );

  registerViewStateTests(config);
  registerComposerHandoffTests(config);
  registerLauncherTests(config);
  registerPresentationLayoutTests(config);
}

Widget _app(Widget child) => MaterialApp(home: Scaffold(body: child));

_TestRuntime _runtime(CerqleConfig config, http.Client httpClient) {
  final client = CerqleClient(
    config: config,
    httpClient: httpClient,
    sessionStore: MemorySessionStore(),
  );
  return _TestRuntime(
    client: client,
    controller: CerqleChatController(client: client),
  );
}

class _TestRuntime {
  const _TestRuntime({required this.client, required this.controller});

  final CerqleClient client;
  final CerqleChatController controller;

  Future<void> dispose() async {
    await controller.dispose();
    await client.close();
  }
}

class _FakeMediaAdapter implements CerqleMediaAdapter {
  int imagePicks = 0;
  int recordingStarts = 0;
  int recordingStops = 0;
  int recordingCancels = 0;

  @override
  Future<CerqleUpload?> pickImage() async {
    imagePicks++;
    return CerqleUpload(
      bytes: Uint8List.fromList(
        base64Decode(
          'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR4nGNgYAAAAAMAASsJTYQAAAAASUVORK5CYII=',
        ),
      ),
      filename: 'photo.png',
      mimeType: 'image/png',
    );
  }

  @override
  Future<void> startAudioRecording() async {
    recordingStarts++;
  }

  @override
  Future<CerqleUpload?> stopAudioRecording() async {
    recordingStops++;
    return CerqleUpload(
      bytes: Uint8List.fromList(<int>[1, 2, 3, 4]),
      filename: 'voice.wav',
      mimeType: 'audio/wav',
    );
  }

  @override
  Future<void> cancelAudioRecording() async {
    recordingCancels++;
  }
}
