import 'package:flutter/material.dart';

import '../theme/example_theme.dart';

class ExampleHeroCard extends StatelessWidget {
  const ExampleHeroCard({super.key});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: cerqleSurface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: cerqleBorder),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0F0F172A),
              blurRadius: 20,
              offset: Offset(0, 10),
            ),
          ],
        ),
        child: const Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Cerqle Chat SDK',
                    style: TextStyle(
                      color: cerqleTextPrimary,
                      fontSize: 24,
                      height: 1.12,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'A native Flutter support experience with flexible '
                    'presentation modes.',
                    style: TextStyle(
                      color: cerqleTextSecondary,
                      fontSize: 14,
                      height: 1.45,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: 18),
            _HeroMark(),
          ],
        ),
      );
}

class _HeroMark extends StatelessWidget {
  const _HeroMark();

  @override
  Widget build(BuildContext context) => Container(
        width: 58,
        height: 58,
        decoration: BoxDecoration(
          color: cerqlePrimary,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(
          Icons.chat_bubble_rounded,
          color: Colors.white,
          size: 27,
        ),
      );
}
