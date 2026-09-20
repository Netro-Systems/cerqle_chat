import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('bundles the built-in launcher logo', (_) async {
    final logo = await rootBundle.load(
      'packages/cerqle_chat/assets/images/cerqle-icon-purple-bg.svg',
    );

    expect(logo.lengthInBytes, greaterThan(0));
  });

  testWidgets('bundles the complete chat action icon set', (_) async {
    const icons = <String>[
      'attachment.png',
      'microphone.png',
      'sent-fast.png',
      'document.png',
      'camera.png',
      'gallery.png',
      'headphones.png',
      'remove.png',
      'trash.png',
    ];

    for (final icon in icons) {
      final data = await rootBundle.load(
        'packages/cerqle_chat/assets/icons/$icon',
      );
      expect(data.lengthInBytes, greaterThan(0), reason: icon);
    }
  });
}
