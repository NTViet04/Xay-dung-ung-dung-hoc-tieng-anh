import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../auth/controllers/auth_provider.dart';

/// Khung admin: sidebar + nội đồng bộ thiết kế `admin_dashboard_overview/code.html`.
class AdminScaffold extends StatelessWidget {
  const AdminScaffold({
    required this.title,
    required this.child,
    super.key,
    this.showInnerHeader = true,
  });

  final String title;
  final Widget child;

  /// Khi `false`, vùng nội dung không có thanh tiêu đề nội bộ (dùng cho dashboard có header riêng).
  final bool showInnerHeader;

  @override
  Widget build(BuildContext context) {
    final routeName = ModalRoute.of(context)?.settings.name ?? '';
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _AdminSidebar(currentRoute: routeName),
          Expanded(
            child: ColoredBox(
              color: AppColors.surface,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (showInnerHeader)
                    Material(
                      color: Colors.white.withValues(alpha: 0.88),
                      elevation: 0,
                      child: SizedBox(
                        height: 64,
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            child: Text(
                              title,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                color: AppColors.onSurface,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  Expanded(child: child),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AdminSidebar extends StatelessWidget {
  const _AdminSidebar({required this.currentRoute});

  final String currentRoute;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 256,
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        border: Border(
          right: BorderSide(
            color: const Color(0xFFE2E8F0).withValues(alpha: 0.8),
          ),
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 16, 12, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Atelier Admin',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                        color: AppColors.primaryContainer,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Hệ thống học tiếng Anh',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
              _NavEntry(
                icon: Icons.dashboard_rounded,
                label: 'Tổng quan',
                route: AppRoutes.adminDashboard,
                currentRoute: currentRoute,
              ),
              _NavEntry(
                icon: Icons.category_rounded,
                label: 'Quản lý chủ đề',
                route: AppRoutes.adminTopics,
                currentRoute: currentRoute,
              ),
              _NavEntry(
                icon: Icons.menu_book_rounded,
                label: 'Quản lý từ vựng',
                route: AppRoutes.adminVocabulary,
                currentRoute: currentRoute,
              ),
              _NavEntry(
                icon: Icons.quiz_rounded,
                label: 'Câu hỏi quiz (TN)',
                route: AppRoutes.adminQuizQuestions,
                currentRoute: currentRoute,
              ),
              _NavEntry(
                icon: Icons.group_rounded,
                label: 'Quản lý người dùng',
                route: AppRoutes.adminUsers,
                currentRoute: currentRoute,
              ),
              const Spacer(),
              const Divider(height: 1, color: Color(0xFFE2E8F0)),
              const SizedBox(height: 12),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.secondaryFixed.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: AppColors.secondary,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'TRẠNG THÁI HỆ THỐNG: HOẠT ĐỘNG',
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.6,
                          color: AppColors.secondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              ListTile(
                leading: const Icon(Icons.settings_outlined,
                    color: Color(0xFF64748B)),
                title: Text(
                  'Cài đặt',
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: const Color(0xFF475569),
                  ),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                onTap: () {
                  showAppSnackBar(
                    context,
                    'Cài đặt máy chủ và thông báo sẽ bổ sung trong bản sau.',
                    kind: AppSnackKind.info,
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.logout_rounded,
                    color: Color(0xFF64748B)),
                title: Text(
                  'Đăng xuất',
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: const Color(0xFF475569),
                  ),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                onTap: () async {
                  await context.read<AuthProvider>().logout();
                  if (context.mounted) {
                    Navigator.of(context).pushNamedAndRemoveUntil(
                      AppRoutes.login,
                      (r) => false,
                    );
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavEntry extends StatelessWidget {
  const _NavEntry({
    required this.icon,
    required this.label,
    required this.route,
    required this.currentRoute,
  });

  final IconData icon;
  final String label;
  final String route;
  final String currentRoute;

  @override
  Widget build(BuildContext context) {
    final selected = currentRoute == route;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: selected
            ? AppColors.primaryContainer.withValues(alpha: 0.1)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: ListTile(
          leading: Icon(
            icon,
            color:
                selected ? AppColors.primaryContainer : const Color(0xFF64748B),
          ),
          title: Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontWeight: FontWeight.w600,
              fontSize: 14,
              color: selected
                  ? AppColors.primaryContainer
                  : const Color(0xFF475569),
            ),
          ),
          onTap: () {
            if (!selected) {
              Navigator.pushReplacementNamed(context, route);
            }
          },
        ),
      ),
    );
  }
}
