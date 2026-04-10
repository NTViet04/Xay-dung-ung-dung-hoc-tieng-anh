import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_colors.dart';

/// Top bar kiểu web mockup: logo + (tuỳ chọn) nút phải.
class FluidLearnerAppBar extends StatelessWidget implements PreferredSizeWidget {
  const FluidLearnerAppBar({
    super.key,
    this.subtitle,
    this.actions,
    this.leading,
  });

  final String? subtitle;
  final List<Widget>? actions;
  final Widget? leading;

  @override
  Size get preferredSize => const Size.fromHeight(56);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      leading: leading,
      automaticallyImplyLeading: leading != null,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'The Fluid Scholar',
            style: GoogleFonts.plusJakartaSans(
              fontWeight: FontWeight.w900,
              fontSize: 18,
              letterSpacing: -0.6,
              color: AppColors.primaryContainer,
            ),
          ),
          if (subtitle != null)
            Text(
              subtitle!,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: AppColors.onSurfaceVariant,
                  ),
            ),
        ],
      ),
      actions: [
        IconButton(
          tooltip: 'Thông báo',
          onPressed: () {},
          icon: const Icon(Icons.notifications_outlined),
          color: AppColors.onSurfaceVariant,
        ),
        Padding(
          padding: const EdgeInsets.only(right: 12),
          child: CircleAvatar(
            radius: 18,
            backgroundColor: AppColors.surfaceContainerHighest,
            child: Icon(Icons.person_rounded, color: AppColors.primaryContainer),
          ),
        ),
        ...?actions,
      ],
      backgroundColor: Colors.white.withValues(alpha: 0.88),
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      shadowColor: AppColors.primary.withValues(alpha: 0.06),
      scrolledUnderElevation: 0.5,
    );
  }
}
