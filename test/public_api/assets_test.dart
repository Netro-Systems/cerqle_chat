import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('bundles the built-in launcher logo', (_) async {
    final logo = await rootBundle.load(
      'packages/cerqle_chat/assets/images/cerqle-icon-purple-bg.svg',
    );

    expect(logo.lengthInBytes, greaterThan(0));
  });
}
