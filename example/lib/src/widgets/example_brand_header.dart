import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../theme/example_theme.dart';

class ExampleBrandHeader extends StatelessWidget {
  const ExampleBrandHeader({super.key});

  @override
  Widget build(BuildContext context) => const Row(
        children: [
          _BrandMark(),
          SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Cerqle',
                style: TextStyle(
                  color: cerqleTextPrimary,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                'FLUTTER CHAT SDK',
                style: TextStyle(
                  color: cerqleTextMuted,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
        ],
      );
}

class _BrandMark extends StatelessWidget {
  const _BrandMark();

  @override
  Widget build(BuildContext context) => Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: cerqlePrimarySoft,
          shape: BoxShape.circle,
          border: Border.all(color: cerqleBorder),
        ),
        child: ClipOval(
          child: SvgPicture.asset(
            'assets/images/cerqle-icon-purple-bg.svg',
            package: 'cerqle_chat',
            fit: BoxFit.cover,
          ),
        ),
      );
}
