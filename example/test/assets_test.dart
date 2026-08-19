import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:cerqle_chat_example/src/widgets/example_brand_header.dart';

void main() {
  testWidgets('example header targets the package-owned brand logo',
      (tester) async {
    await tester.pumpWidget(
      DefaultAssetBundle(
        bundle: _TestAssetBundle(),
        child: const MaterialApp(home: ExampleBrandHeader()),
      ),
    );

    final logo = tester.widget<SvgPicture>(find.byType(SvgPicture));
    final loader = logo.bytesLoader as SvgAssetLoader;
    expect(loader.assetName, 'assets/images/cerqle-icon.svg');
    expect(loader.packageName, 'cerqle_chat');
  });
}

class _TestAssetBundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) {
    if (key == 'AssetManifest.bin') {
      return rootBundle.load(key);
    }

    final bytes = Uint8List.fromList(
      utf8.encode(
        '<svg xmlns="http://www.w3.org/2000/svg" width="1" height="1" />',
      ),
    );
    return Future<ByteData>.value(ByteData.view(bytes.buffer));
  }
}
