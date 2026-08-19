import 'package:flutter/material.dart';

import '../theme/example_theme.dart';

class IntegrationCard extends StatelessWidget {
  const IntegrationCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: cerqleSurface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: cerqleBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        splashColor: cerqleSecondary.withValues(alpha: 0.2),
        highlightColor: cerqleSecondary.withValues(alpha: 0.2),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: cerqleBackgroundAlt,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: cerqleSurfaceMuted),
                ),
                child: Icon(
                  icon,
                  color: cerqlePrimary,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: cerqleTextPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: cerqleTextMuted,
                        fontSize: 12,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: cerqlePrimarySoft,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.arrow_forward_rounded,
                  color: cerqlePrimary,
                  size: 18,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
