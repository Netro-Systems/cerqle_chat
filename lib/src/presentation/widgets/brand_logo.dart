import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

const _cerqleLogoAsset = 'assets/images/cerqle-icon-purple-bg.svg';

class CerqleBrandLogo extends StatelessWidget {
  const CerqleBrandLogo({super.key, this.imageKey, this.fit = BoxFit.contain})
      : _colorMapper = null;

  const CerqleBrandLogo.launcher({super.key, this.imageKey})
      : fit = BoxFit.contain,
        _colorMapper = const _TransparentLauncherBackground();

  final Key? imageKey;
  final BoxFit fit;
  final ColorMapper? _colorMapper;

  @override
  Widget build(BuildContext context) => SvgPicture.asset(
        _cerqleLogoAsset,
        key: imageKey,
        package: 'cerqle_chat',
        fit: fit,
        colorMapper: _colorMapper,
        excludeFromSemantics: true,
      );
}

class _TransparentLauncherBackground extends ColorMapper {
  const _TransparentLauncherBackground();

  @override
  Color substitute(
    String? id,
    String elementName,
    String attributeName,
    Color color,
  ) {
    if (elementName == 'rect' &&
        attributeName == 'fill' &&
        color == const Color(0xFF9B5FA8)) {
      return Colors.transparent;
    }
    return color;
  }
}
