import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../data/repositories/admin_repository.dart';
import '../../../auth/controllers/auth_provider.dart';
import '../../shell/admin_scaffold.dart';
import '../../widgets/admin_delete_dialog.dart';
import '../../widgets/admin_page_footer.dart';
import 'user_detail_modal.dart';

class _UserPageData {
  const _UserPageData({required this.users, required this.stats});

  final List<Map<String, dynamic>> users;
  final Map<String, dynamic> stats;
}

class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

String _fmtIntVi(num n) {
  final x = n.round();
  final s = x.toString();
  final buf = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) {
      buf.write(',');
    }
    buf.write(s[i]);
  }
  return buf.toString();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  final _searchCtrl = TextEditingController();
  Future<_UserPageData>? _future;
  String _searchApplied = '';
  int _page = 0;
  static const _pageSize = 8;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _future ??= _load();
  }

  Future<_UserPageData> _load() async {
    final admin = context.read<AdminRepository>();
    final users = await admin.fetchUsers();
    final stats = await admin.userManagementSummary();
    return _UserPageData(users: users, stats: stats);
  }

  Future<void> _reload() async {
    setState(() {
      _future = _load();
    });
    await _future;
  }

  List<Map<String, dynamic>> _filtered(List<Map<String, dynamic>> all) {
    final q = _searchApplied.trim().toLowerCase();
    if (q.isEmpty) {
      return all;
    }
    return all.where((r) {
      final id = '${r['id'] ?? ''}';
      final un = '${r['username'] ?? ''}'.toLowerCase();
      return un.contains(q) || id.contains(q);
    }).toList();
  }

  static String _fmtDate(dynamic raw) {
    final d = DateTime.tryParse('${raw ?? ''}');
    if (d == null) {
      return '—';
    }
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  static String _initials(String name) {
    final p = name.trim().split(RegExp(r'\s+')).where((e) => e.isNotEmpty);
    final buf = StringBuffer();
    for (final w in p.take(2)) {
      buf.write(w[0].toUpperCase());
    }
    return buf.isEmpty ? '?' : buf.toString();
  }

  Future<void> _addUser() async {
    final userCtrl = TextEditingController();
    final passCtrl = TextEditingController();
    String role = 'learner';
    final ok = await showDialog<bool>(
      context: context,
      barrierColor: const Color(0xFF0F172A).withValues(alpha: 0.55),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setLocal) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            title: Text(
              'Thêm người dùng',
              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: userCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Tên đăng nhập',
                    ),
                  ),
                  TextField(
                    controller: passCtrl,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Mật khẩu (≥ 6 ký tự)',
                    ),
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Vai trò',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  DropdownButton<String>(
                    value: role,
                    isExpanded: true,
                    items: const [
                      DropdownMenuItem(value: 'learner', child: Text('Học viên')),
                      DropdownMenuItem(value: 'admin', child: Text('Quản trị')),
                    ],
                    onChanged: (v) {
                      if (v != null) {
                        setLocal(() => role = v);
                      }
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Hủy'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Tạo'),
              ),
            ],
          );
        },
      ),
    );
    if (ok != true || !mounted) {
      return;
    }
    try {
      await context.read<AdminRepository>().createUser(
            username: userCtrl.text.trim(),
            password: passCtrl.text,
            role: role,
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã tạo tài khoản.')),
        );
      }
      await _reload();
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message)),
        );
      }
    }
  }

  Future<void> _delete(int id, String name) async {
    final ok = await showAdminDeleteDialog(
      context: context,
      title: 'Xóa người dùng?',
      message:
          'Tài khoản và dữ liệu liên quan (theo quy tắc máy chủ) sẽ bị xóa vĩnh viễn.',
      highlight: name,
      confirmLabel: 'Xóa vĩnh viễn',
    );
    if (!ok || !mounted) {
      return;
    }
    try {
      await context.read<AdminRepository>().deleteUser(id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã xóa người dùng.')),
        );
      }
      await _reload();
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final myId = auth.user?.id;

    return AdminScaffold(
      title: 'Quản lý người dùng',
      showInnerHeader: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _UserTopBar(
            searchController: _searchCtrl,
            displayName: auth.user?.username ?? 'Admin',
            onSearch: () {
              setState(() {
                _searchApplied = _searchCtrl.text.trim();
                _page = 0;
              });
            },
            onNotifications: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Không có thông báo mới.')),
              );
            },
            onSettings: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Cài đặt hệ thống sẽ bổ sung sau.'),
                ),
              );
            },
          ),
          Expanded(
            child: FutureBuilder<_UserPageData>(
              future: _future,
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snap.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('${snap.error}', textAlign: TextAlign.center),
                          const SizedBox(height: 16),
                          FilledButton(
                            onPressed: _reload,
                            child: const Text('Thử lại'),
                          ),
                        ],
                      ),
                    ),
                  );
                }
                final data = snap.data!;
                final users = data.users;
                final st = data.stats;
                final totalLearners =
                    (st['total_learners'] as num?)?.toInt() ?? 0;
                final activeWeek =
                    (st['active_this_week'] as num?)?.toInt() ?? 0;
                final totalXp = (st['total_xp_sum'] as num?)?.toInt() ?? 0;
                final pending =
                    (st['pending_reports'] as num?)?.toInt() ?? 0;
                final avgLvl =
                    (st['avg_level_learners'] as num?)?.toDouble() ?? 0;

                final filtered = _filtered(users);
                final totalF = filtered.length;
                final maxPage =
                    totalF <= 0 ? 0 : (totalF - 1) ~/ _pageSize;
                final safePage = _page.clamp(0, maxPage);
                final start = safePage * _pageSize;
                final pageItems = start < totalF
                    ? filtered.sublist(
                        start,
                        start + _pageSize > totalF
                            ? totalF
                            : start + _pageSize,
                      )
                    : <Map<String, dynamic>>[];

                return RefreshIndicator(
                  onRefresh: _reload,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _HeaderActions(
                          onExport: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Xuất danh sách CSV sẽ bổ sung sau.',
                                ),
                              ),
                            );
                          },
                          onAdd: _addUser,
                        ),
                        const SizedBox(height: 24),
                        _KpiGrid(
                          totalLearners: totalLearners,
                          activeWeek: activeWeek,
                          totalXp: totalXp,
                          pending: pending,
                          avgLevel: avgLvl,
                        ),
                        const SizedBox(height: 24),
                        _UserTableCard(
                          rows: pageItems,
                          totalFiltered: totalF,
                          safePage: safePage,
                          pageSize: _pageSize,
                          maxPage: maxPage,
                          myId: myId,
                          fmtDate: _fmtDate,
                          initials: _initials,
                          fmtInt: _fmtIntVi,
                          onView: (id) {
                            showDialog<void>(
                              context: context,
                              barrierDismissible: true,
                              barrierColor:
                                  const Color(0xFF0F172A).withValues(alpha: 0.45),
                              builder: (ctx) => UserDetailModal(
                                userId: id,
                                onChanged: _reload,
                              ),
                            );
                          },
                          onDelete: (id, name) => _delete(id, name),
                          onPrev: safePage > 0
                              ? () => setState(() => _page = safePage - 1)
                              : null,
                          onNext: safePage < maxPage
                              ? () => setState(() => _page = safePage + 1)
                              : null,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const AdminPageFooter(),
        ],
      ),
    );
  }
}

class _UserTopBar extends StatelessWidget {
  const _UserTopBar({
    required this.searchController,
    required this.displayName,
    required this.onSearch,
    required this.onNotifications,
    required this.onSettings,
  });

  final TextEditingController searchController;
  final String displayName;
  final VoidCallback onSearch;
  final VoidCallback onNotifications;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.88),
      elevation: 1,
      shadowColor: AppColors.primary.withValues(alpha: 0.06),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        child: Row(
          children: [
            Expanded(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: TextField(
                  controller: searchController,
                  onSubmitted: (_) => onSearch(),
                  decoration: InputDecoration(
                    hintText: 'Tìm theo tên hoặc ID…',
                    prefixIcon: const Icon(Icons.search_rounded,
                        color: Color(0xFF94A3B8)),
                    filled: true,
                    fillColor: const Color(0xFFF1F5F9).withValues(alpha: 0.85),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    isDense: true,
                  ),
                ),
              ),
            ),
            IconButton(
              tooltip: 'Tìm',
              onPressed: onSearch,
              icon: const Icon(Icons.search_rounded),
              color: const Color(0xFF64748B),
            ),
            IconButton(
              tooltip: 'Thông báo',
              onPressed: onNotifications,
              icon: const Icon(Icons.notifications_outlined),
              color: const Color(0xFF64748B),
            ),
            IconButton(
              tooltip: 'Cài đặt',
              onPressed: onSettings,
              icon: const Icon(Icons.settings_outlined),
              color: const Color(0xFF64748B),
            ),
            Container(
              width: 1,
              height: 32,
              color: const Color(0xFFE2E8F0),
            ),
            const SizedBox(width: 12),
            CircleAvatar(
              radius: 16,
              backgroundColor:
                  AppColors.primaryContainer.withValues(alpha: 0.2),
              child: Text(
                displayName.isNotEmpty ? displayName[0].toUpperCase() : 'A',
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w900,
                  color: AppColors.primaryContainer,
                  fontSize: 13,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              displayName,
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeaderActions extends StatelessWidget {
  const _HeaderActions({
    required this.onExport,
    required this.onAdd,
  });

  final VoidCallback onExport;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final row = c.maxWidth >= 720;
        final title = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Quản lý người dùng',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 30,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.6,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Theo dõi, xem chi tiết và quản lý tài khoản học viên.',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: AppColors.onSurfaceVariant,
              ),
            ),
          ],
        );
        final actions = Wrap(
          spacing: 10,
          runSpacing: 10,
          alignment: WrapAlignment.end,
          children: [
            OutlinedButton.icon(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Báo cáo cần xử lý: xem cột KPI «Cần theo dõi».',
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.flag_outlined, size: 18),
              label: Text(
                'Danh sách báo cáo',
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primaryContainer,
                side: BorderSide(
                  color: AppColors.primaryContainer.withValues(alpha: 0.35),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            OutlinedButton.icon(
              onPressed: onExport,
              icon: const Icon(Icons.file_download_outlined, size: 18),
              label: Text(
                'Xuất danh sách',
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primaryContainer,
                side: BorderSide(
                  color: AppColors.primaryContainer.withValues(alpha: 0.25),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.person_add_rounded, size: 20),
              label: Text(
                'Thêm người dùng',
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        );
        if (row) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(child: title),
              actions,
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            title,
            const SizedBox(height: 16),
            actions,
          ],
        );
      },
    );
  }
}

class _KpiGrid extends StatelessWidget {
  const _KpiGrid({
    required this.totalLearners,
    required this.activeWeek,
    required this.totalXp,
    required this.pending,
    required this.avgLevel,
  });

  final int totalLearners;
  final int activeWeek;
  final int totalXp;
  final int pending;
  final double avgLevel;

  @override
  Widget build(BuildContext context) {
    String xpLabel;
    if (totalXp >= 1000000) {
      xpLabel = '${(totalXp / 1000000).toStringAsFixed(1)}M';
    } else if (totalXp >= 1000) {
      xpLabel = '${(totalXp / 1000).toStringAsFixed(1)}k';
    } else {
      xpLabel = '$totalXp';
    }

    return LayoutBuilder(
      builder: (context, c) {
        final w = c.maxWidth;
        final cols = w >= 1100
            ? 4
            : w >= 700
                ? 2
                : 1;
        return GridView.count(
          crossAxisCount: cols,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: cols == 4 ? 1.45 : 1.55,
          children: [
            _KpiCard(
              icon: Icons.group_rounded,
              iconBg: AppColors.primaryContainer.withValues(alpha: 0.12),
              iconColor: AppColors.primaryContainer,
              chip: 'HỌC VIÊN',
              chipColor: AppColors.secondary,
              title: 'Tổng đăng ký',
              value: _fmtIntVi(totalLearners),
              caption: 'Số tài khoản vai trò học viên.',
            ),
            _KpiCard(
              icon: Icons.bolt_rounded,
              iconBg: const Color(0xFFFFF7ED),
              iconColor: const Color(0xFFC2410C),
              chip: 'TUẦN NÀY',
              chipColor: AppColors.secondary,
              title: 'Hoạt động (7 ngày)',
              value: _fmtIntVi(activeWeek),
              caption: 'Học viên có làm quiz trong tuần.',
            ),
            _KpiCard(
              icon: Icons.military_tech_rounded,
              iconBg: AppColors.secondary.withValues(alpha: 0.1),
              iconColor: AppColors.secondary,
              chip: 'TB CẤP ${avgLevel.toStringAsFixed(1)}',
              chipColor: AppColors.onSurfaceVariant,
              title: 'Tổng XP hệ thống',
              value: xpLabel,
              caption: 'Cộng dồn XP mọi tài khoản.',
            ),
            _KpiCard(
              icon: Icons.flag_rounded,
              iconBg: AppColors.error.withValues(alpha: 0.1),
              iconColor: AppColors.error,
              chip: 'CẦN THEO DÕI',
              chipColor: AppColors.error,
              title: 'Bài quiz điểm thấp',
              value: '$pending',
              caption: 'Lượt quiz < 55% (30 ngày).',
            ),
          ],
        );
      },
    );
  }
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.chip,
    required this.chipColor,
    required this.title,
    required this.value,
    required this.caption,
  });

  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String chip;
  final Color chipColor;
  final String title;
  final String value;
  final String caption;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: iconColor, size: 22),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: chipColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  chip,
                  style: GoogleFonts.robotoMono(
                    fontSize: 8,
                    fontWeight: FontWeight.w800,
                    color: chipColor,
                  ),
                ),
              ),
            ],
          ),
          const Spacer(),
          Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: AppColors.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: GoogleFonts.robotoMono(
              fontSize: 24,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            caption,
            style: GoogleFonts.inter(
              fontSize: 10,
              color: const Color(0xFF64748B),
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }
}

class _UserTableCard extends StatelessWidget {
  const _UserTableCard({
    required this.rows,
    required this.totalFiltered,
    required this.safePage,
    required this.pageSize,
    required this.maxPage,
    required this.myId,
    required this.fmtDate,
    required this.initials,
    required this.fmtInt,
    required this.onView,
    required this.onDelete,
    required this.onPrev,
    required this.onNext,
  });

  final List<Map<String, dynamic>> rows;
  final int totalFiltered;
  final int safePage;
  final int pageSize;
  final int maxPage;
  final int? myId;
  final String Function(dynamic) fmtDate;
  final String Function(String) initials;
  final String Function(num) fmtInt;
  final void Function(int id) onView;
  final void Function(int id, String name) onDelete;
  final VoidCallback? onPrev;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    final from = totalFiltered == 0 ? 0 : safePage * pageSize + 1;
    final to = (safePage + 1) * pageSize > totalFiltered
        ? totalFiltered
        : (safePage + 1) * pageSize;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppColors.outlineVariant.withValues(alpha: 0.35),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.onSurface.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            color: AppColors.surfaceContainerLow.withValues(alpha: 0.5),
            child: Row(
              children: [
                Text(
                  'Hoạt động học viên gần đây',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Bộ lọc sẽ bổ sung sau.')),
                    );
                  },
                  icon: const Icon(Icons.filter_list_rounded),
                  color: const Color(0xFF94A3B8),
                ),
                IconButton(
                  onPressed: () {},
                  icon: const Icon(Icons.more_vert_rounded),
                  color: const Color(0xFF94A3B8),
                ),
              ],
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 920),
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(
                  AppColors.surfaceContainerLow.withValues(alpha: 0.4),
                ),
                columns: [
                  DataColumn(
                    label: Text(
                      'TÊN & ID',
                      style: GoogleFonts.robotoMono(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF94A3B8),
                      ),
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      'CẤP ĐỘ',
                      style: GoogleFonts.robotoMono(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF94A3B8),
                      ),
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      'TỔNG XP',
                      style: GoogleFonts.robotoMono(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF94A3B8),
                      ),
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      'NGÀY THAM GIA',
                      style: GoogleFonts.robotoMono(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF94A3B8),
                      ),
                    ),
                  ),
                  DataColumn(
                    label: Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        'THAO TÁC',
                        style: GoogleFonts.robotoMono(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF94A3B8),
                        ),
                      ),
                    ),
                  ),
                ],
                rows: [
                  for (final r in rows)
                    DataRow(
                      cells: [
                        DataCell(
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 18,
                                backgroundColor: AppColors.primaryContainer
                                    .withValues(alpha: 0.15),
                                child: Text(
                                  initials('${r['username'] ?? ''}'),
                                  style: GoogleFonts.plusJakartaSans(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 12,
                                    color: AppColors.primaryContainer,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    '${r['username']}',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 13,
                                    ),
                                  ),
                                  Text(
                                    '#USR-${'${r['id']}'.padLeft(5, '0')}',
                                    style: GoogleFonts.robotoMono(
                                      fontSize: 9,
                                      color: const Color(0xFF94A3B8),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        DataCell(
                          _LevelPill(level: (r['level'] as num?)?.toInt() ?? 1),
                        ),
                        DataCell(
                          Text(
                            fmtInt((r['xp'] as num?) ?? 0),
                            style: GoogleFonts.robotoMono(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        DataCell(
                          Text(
                            fmtDate(r['created_at']),
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              color: AppColors.onSurfaceVariant,
                            ),
                          ),
                        ),
                        DataCell(
                          Align(
                            alignment: Alignment.centerRight,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                TextButton(
                                  onPressed: () => onView(
                                    (r['id'] as num).toInt(),
                                  ),
                                  child: Text(
                                    'Xem chi tiết',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 12,
                                      color: AppColors.primaryContainer,
                                    ),
                                  ),
                                ),
                                if ((r['id'] as num).toInt() != myId)
                                  IconButton(
                                    tooltip: 'Xóa',
                                    onPressed: () => onDelete(
                                      (r['id'] as num).toInt(),
                                      '${r['username']}',
                                    ),
                                    icon: Icon(
                                      Icons.delete_outline_rounded,
                                      color: AppColors.error
                                          .withValues(alpha: 0.85),
                                      size: 20,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              border: Border(
                top: BorderSide(
                  color: AppColors.outlineVariant.withValues(alpha: 0.5),
                ),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'HIỂN THỊ $from–$to / $totalFiltered NGƯỜI DÙNG',
                    style: GoogleFonts.robotoMono(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.3,
                      color: const Color(0xFF94A3B8),
                    ),
                  ),
                ),
                IconButton(
                  onPressed: onPrev,
                  icon: const Icon(Icons.chevron_left_rounded),
                  color: const Color(0xFF64748B),
                ),
                IconButton(
                  onPressed: onNext,
                  icon: const Icon(Icons.chevron_right_rounded),
                  color: const Color(0xFF64748B),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LevelPill extends StatelessWidget {
  const _LevelPill({required this.level});

  final int level;

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;
    Color dot;
    if (level >= 40) {
      bg = AppColors.primaryContainer.withValues(alpha: 0.15);
      fg = AppColors.primaryContainer;
      dot = AppColors.primaryContainer;
    } else if (level >= 15) {
      bg = AppColors.tertiaryFixed.withValues(alpha: 0.35);
      fg = const Color(0xFF653E00);
      dot = const Color(0xFF92400E);
    } else if (level >= 5) {
      bg = AppColors.secondaryFixed.withValues(alpha: 0.22);
      fg = const Color(0xFF007432);
      dot = AppColors.secondary;
    } else {
      bg = AppColors.surfaceContainerHighest;
      fg = AppColors.onSurfaceVariant;
      dot = AppColors.outlineVariant;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            'Cấp $level',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }
}
