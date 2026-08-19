import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

const _cerqleLogoAsset = 'assets/images/cerqle-icon.svg';

class CerqleBrandLogo extends StatelessWidget {
  const CerqleBrandLogo({super.key, this.imageKey, this.fit = BoxFit.contain});

  final Key? imageKey;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) => SvgPicture.asset(
    _cerqleLogoAsset,
    key: imageKey,
    package: 'cerqle_chat',
    fit: fit,
    excludeFromSemantics: true,
  );
}
