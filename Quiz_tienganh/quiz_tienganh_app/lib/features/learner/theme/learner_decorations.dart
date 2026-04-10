import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

/// Shadow / gradient theo thiết kế HTML (Fluid Scholar).
abstract final class LearnerDecorations {
  static List<BoxShadow> ambientCard({Color? tint}) => [
        BoxShadow(
          color: (tint ?? AppColors.primaryContainer).withValues(alpha: 0.08),
          blurRadius: 24,
          offset: const Offset(0, 6),
        ),
      ];

  static BoxDecoration cardSurface({
    Color? color,
    double radius = 16,
  }) {
    return BoxDecoration(
      color: color ?? AppColors.surfaceContainerLowest,
      borderRadius: BorderRadius.circular(radius),
      boxShadow: ambientCard(),
    );
  }

  static BoxDecoration primaryHero({double radius = 20}) {
    return BoxDecoration(
      borderRadius: BorderRadius.circular(radius),
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          AppColors.primary,
          AppColors.primaryContainer,
        ],
      ),
    );
  }

  static BoxDecoration softBorder() {
    return BoxDecoration(
      borderRadius: BorderRadius.circular(16),
      border: Border.all(
        color: AppColors.outlineVariant.withValues(alpha: 0.12),
      ),
    );
  }
}
