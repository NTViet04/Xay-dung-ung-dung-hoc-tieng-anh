import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../auth/controllers/auth_provider.dart';
import '../../theme/learner_decorations.dart';
import '../../widgets/fluid_learner_page_footer.dart';
import '../../widgets/fluid_learner_top_nav.dart';

class LearnerProfileTabScreen extends StatelessWidget {
  const LearnerProfileTabScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final u = auth.user;

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: FluidLearnerTopNav(
        currentIndex: 3,
        extraActions: u?.isAdmin == true
            ? [
                IconButton(
                  tooltip: 'Admin',
                  icon: const Icon(Icons.admin_panel_settings_outlined),
                  onPressed: () =>
                      Navigator.pushNamed(context, AppRoutes.adminDashboard),
                ),
              ]
            : null,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: LearnerDecorations.cardSurface(radius: 20),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 36,
                  backgroundColor: AppColors.surfaceContainerHighest,
                  child: Icon(
                    Icons.person_rounded,
                    size: 40,
                    color: AppColors.primaryContainer,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        u?.username ?? '—',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Level ${u?.level ?? 0} · ${u?.xp ?? 0} XP · ${u?.role ?? ''}',
                        style: Theme.of(context).textTheme.labelMedium?.copyWith(
                              color: AppColors.onSurfaceVariant,
                            ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          ListTile(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            leading: const Icon(Icons.logout_rounded),
            title: const Text('Đăng xuất'),
            onTap: () async {
              await context.read<AuthProvider>().logout();
            },
          ),
          SizedBox(height: 16 + MediaQuery.paddingOf(context).bottom),
          const FluidLearnerPageFooter(),
        ],
      ),
    );
  }
}
