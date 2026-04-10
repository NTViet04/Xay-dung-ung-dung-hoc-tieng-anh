import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../auth/controllers/auth_provider.dart';
import '../controllers/learner_tab_index.dart';

/// Thanh trên cố định kiểu web: logo, (màn rộng) Trang chủ · Chủ đề · Tiến độ, chuông, avatar.
/// Dùng chung cho các màn trong [LearnerShell] (`currentIndex` 0–2).
class FluidLearnerTopNav extends StatelessWidget implements PreferredSizeWidget {
  const FluidLearnerTopNav({
    super.key,
    required this.currentIndex,
    this.leading,
    this.extraActions,
  });

  /// 0 Trang chủ, 1 Chủ đề, 2 Tiến độ — khớp [LearnerShell].
  final int currentIndex;
  /// Nút quay lại / đóng (màn con như danh sách từ).
  final Widget? leading;
  final List<Widget>? extraActions;

  static const _breakShowLinks = 720.0;

  void _go(BuildContext context, int index) {
    if (index == currentIndex) return;
    // Nếu đang ở route con (flashcards/quiz/...), quay về route gốc trước khi đổi tab để tránh state lạc.
    Navigator.of(context).popUntil((route) => route.isFirst);
    context.read<LearnerTabIndex>().goTo(index);
  }

  void _openMobileSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetCtx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _MobileNavTile(
                icon: Icons.home_outlined,
                label: 'Trang chủ',
                selected: currentIndex == 0,
                onTap: () {
                  Navigator.pop(sheetCtx);
                  _go(context, 0);
                },
              ),
              _MobileNavTile(
                icon: Icons.topic_outlined,
                label: 'Chủ đề',
                selected: currentIndex == 1,
                onTap: () {
                  Navigator.pop(sheetCtx);
                  _go(context, 1);
                },
              ),
              _MobileNavTile(
                icon: Icons.insights_outlined,
                label: 'Tiến độ',
                selected: currentIndex == 2,
                onTap: () {
                  Navigator.pop(sheetCtx);
                  _go(context, 2);
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(64);

  void _openAccountDialog(BuildContext context) {
    final auth = context.read<AuthProvider>();
    final u = auth.user;
    final name = u?.username ?? 'Tài khoản';
    final role = u?.isAdmin == true ? 'Admin' : 'Học viên';
    final level = u?.level ?? 1;
    final xp = u?.xp ?? 0;

    showDialog<void>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text(
            'Tài khoản',
            style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w900),
          ),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: AppColors.surfaceContainerHighest,
                      child: Icon(
                        Icons.person_rounded,
                        color: AppColors.primaryContainer,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: GoogleFonts.plusJakartaSans(
                              fontWeight: FontWeight.w900,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            role,
                            style: GoogleFonts.spaceGrotesk(
                              fontWeight: FontWeight.w800,
                              fontSize: 11,
                              letterSpacing: 1.1,
                              color: AppColors.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _InfoRow(label: 'Cấp độ', value: '$level'),
                const SizedBox(height: 8),
                _InfoRow(label: 'XP', value: '$xp'),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Đóng'),
            ),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFEF4444),
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                Navigator.pop(ctx);
                await auth.logout();
                if (context.mounted) {
                  Navigator.of(context).popUntil((r) => r.isFirst);
                  showAppSnackBar(
                    context,
                    'Bạn đã đăng xuất.',
                    kind: AppSnackKind.success,
                  );
                }
              },
              icon: const Icon(Icons.logout_rounded, size: 18),
              label: const Text('Đăng xuất'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    final showLinks = w >= _breakShowLinks;

    // Nền đục — trên web, Material trong suốt đôi khi gây hit-test / layer lạ.
    return Material(
      color: const Color(0xFFF8FAFC),
      elevation: 0,
      shadowColor: AppColors.primary.withValues(alpha: 0.06),
      child: SafeArea(
        bottom: false,
        child: Container(
          height: 64,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: AppColors.outlineVariant.withValues(alpha: 0.25),
              ),
            ),
          ),
          child: Row(
            children: [
              leading ?? const SizedBox.shrink(),
              if (!showLinks)
                IconButton(
                  tooltip: 'Menu',
                  onPressed: () => _openMobileSheet(context),
                  icon: const Icon(Icons.menu_rounded),
                  color: const Color(0xFF64748B),
                ),
              Expanded(
                child: showLinks
                    ? Row(
                        children: [
                          Text(
                            'The Fluid Scholar',
                            style: GoogleFonts.plusJakartaSans(
                              fontWeight: FontWeight.w900,
                              fontSize: w >= 400 ? 20 : 17,
                              letterSpacing: -0.8,
                              color: const Color(0xFF4F46E5),
                            ),
                          ),
                          Expanded(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                _NavPill(
                                  label: 'Trang chủ',
                                  selected: currentIndex == 0,
                                  onTap: () => _go(context, 0),
                                ),
                                _NavPill(
                                  label: 'Chủ đề',
                                  selected: currentIndex == 1,
                                  onTap: () => _go(context, 1),
                                ),
                                _NavPill(
                                  label: 'Tiến độ',
                                  selected: currentIndex == 2,
                                  onTap: () => _go(context, 2),
                                ),
                              ],
                            ),
                          ),
                        ],
                      )
                    : Text(
                        'The Fluid Scholar',
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w900,
                          fontSize: w >= 400 ? 20 : 17,
                          letterSpacing: -0.8,
                          color: const Color(0xFF4F46E5),
                        ),
                      ),
              ),
              IconButton(
                tooltip: 'Thông báo',
                onPressed: () {
                  showAppSnackBar(
                    context,
                    'Chưa có thông báo mới.',
                    kind: AppSnackKind.info,
                  );
                },
                icon: const Icon(Icons.notifications_outlined),
                color: const Color(0xFF64748B),
              ),
              InkWell(
                onTap: () => _openAccountDialog(context),
                borderRadius: BorderRadius.circular(999),
                child: CircleAvatar(
                  radius: 18,
                  backgroundColor: AppColors.surfaceContainerHighest,
                  child: Icon(
                    Icons.person_rounded,
                    color: AppColors.primaryContainer,
                    size: 22,
                  ),
                ),
              ),
              if (extraActions != null) ...extraActions!,
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontWeight: FontWeight.w700,
              color: AppColors.onSurfaceVariant,
            ),
          ),
        ),
        Text(
          value,
          style: GoogleFonts.robotoMono(
            fontWeight: FontWeight.w800,
            color: AppColors.onSurface,
          ),
        ),
      ],
    );
  }
}

class _MobileNavTile extends StatelessWidget {
  const _MobileNavTile({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(
        icon,
        color: selected ? const Color(0xFF4F46E5) : const Color(0xFF64748B),
      ),
      title: Text(
        label,
        style: GoogleFonts.plusJakartaSans(
          fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
          color: selected ? const Color(0xFF4F46E5) : AppColors.onSurface,
        ),
      ),
      selected: selected,
      selectedTileColor: const Color(0xFF4F46E5).withValues(alpha: 0.08),
      onTap: onTap,
    );
  }
}

class _NavPill extends StatelessWidget {
  const _NavPill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                  color: selected
                      ? const Color(0xFF4F46E5)
                      : const Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 4),
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                height: 2,
                width: selected ? 28 : 0,
                decoration: BoxDecoration(
                  color: const Color(0xFF4F46E5),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
