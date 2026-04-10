import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/json_convert.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../../../data/repositories/admin_repository.dart';
import '../../../auth/controllers/auth_provider.dart';
import '../../shell/admin_scaffold.dart';
import '../../widgets/admin_page_footer.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final _searchCtrl = TextEditingController();
  Future<Map<String, dynamic>>? _future;
  int _ledgerPage = 0;
  static const _ledgerLimit = 8;
  String _searchApplied = '';
  bool _chartThisWeek = true;

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

  Future<Map<String, dynamic>> _load() {
    return context.read<AdminRepository>().dashboardStats(
          ledgerPage: _ledgerPage,
          ledgerLimit: _ledgerLimit,
          search: _searchApplied.isEmpty ? null : _searchApplied,
        );
  }

  Future<void> _reload() async {
    setState(() {
      _future = _load();
    });
    await _future;
  }

  static String _fmtInt(num n) {
    final s = n.round().toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) {
        buf.write(',');
      }
      buf.write(s[i]);
    }
    return buf.toString();
  }

  static String _fmtTs(dynamic raw) {
    DateTime? d;
    if (raw is String) {
      d = DateTime.tryParse(raw);
    }
    if (d == null) {
      return '$raw';
    }
    String p2(int x) => x.toString().padLeft(2, '0');
    return '${d.year}.${p2(d.month)}.${p2(d.day)} ${p2(d.hour)}:${p2(d.minute)}:${p2(d.second)}';
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.user;

    return AdminScaffold(
      title: 'Tổng quan',
      showInnerHeader: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _DashboardTopBar(
            searchController: _searchCtrl,
            displayName: user?.username ?? 'Admin',
            roleLabel: user?.isAdmin == true ? 'QUẢN TRỊ VIÊN CAO CẤP' : 'QUẢN TRỊ',
            onSearch: () {
              setState(() {
                _searchApplied = _searchCtrl.text.trim();
                _ledgerPage = 0;
                _future = _load();
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
                  content: Text(
                    'Cài đặt máy chủ sẽ bổ sung trong bản sau.',
                  ),
                ),
              );
            },
          ),
          Expanded(
            child: FutureBuilder<Map<String, dynamic>>(
              future: _future,
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snap.hasError) {
                  final msg = snap.error is ApiException
                      ? (snap.error as ApiException).message
                      : '${snap.error}';
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(msg, textAlign: TextAlign.center),
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
                final d = snap.data ?? {};
                return RefreshIndicator(
                  onRefresh: _reload,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                    child: _DashboardBody(
                      data: d,
                      chartThisWeek: _chartThisWeek,
                      onChartWeekChanged: (v) {
                        setState(() => _chartThisWeek = v);
                      },
                      ledgerPage: _ledgerPage,
                      ledgerLimit: _ledgerLimit,
                      onLedgerPrev: () {
                        if (_ledgerPage <= 0) {
                          return;
                        }
                        setState(() {
                          _ledgerPage--;
                          _future = _load();
                        });
                      },
                      onLedgerNext: () {
                        final total = parseJsonInt(d['ledger_total_all']) ?? 0;
                        final maxPage = total <= 0
                            ? 0
                            : (total - 1) ~/ _ledgerLimit;
                        if (_ledgerPage >= maxPage) {
                          return;
                        }
                        setState(() {
                          _ledgerPage++;
                          _future = _load();
                        });
                      },
                      onAuditLog: () {
                        showAppSnackBar(
                          context,
                          'Bảng bên dưới là nhật ký học tập gần đây từ máy chủ.',
                          kind: AppSnackKind.info,
                        );
                      },
                      fmtInt: _fmtInt,
                      fmtTs: _fmtTs,
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

class _DashboardTopBar extends StatelessWidget {
  const _DashboardTopBar({
    required this.searchController,
    required this.displayName,
    required this.roleLabel,
    required this.onSearch,
    required this.onNotifications,
    required this.onSettings,
  });

  final TextEditingController searchController;
  final String displayName;
  final String roleLabel;
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
                    hintText: 'Tìm kiếm phân tích hoặc học viên…',
                    prefixIcon: const Icon(Icons.search_rounded,
                        color: Color(0xFF94A3B8)),
                    filled: true,
                    fillColor: const Color(0xFFF1F5F9).withValues(alpha: 0.7),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(999),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
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
            const SizedBox(width: 8),
            Container(
              width: 1,
              height: 36,
              color: const Color(0xFFE2E8F0),
            ),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  displayName,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppColors.onSurface,
                  ),
                ),
                Text(
                  roleLabel,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.4,
                    color: AppColors.primaryContainer,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 12),
            CircleAvatar(
              radius: 20,
              backgroundColor: AppColors.primaryContainer.withValues(alpha: 0.2),
              child: Text(
                displayName.isNotEmpty
                    ? displayName[0].toUpperCase()
                    : 'A',
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w900,
                  color: AppColors.primaryContainer,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DashboardBody extends StatelessWidget {
  const _DashboardBody({
    required this.data,
    required this.chartThisWeek,
    required this.onChartWeekChanged,
    required this.ledgerPage,
    required this.ledgerLimit,
    required this.onLedgerPrev,
    required this.onLedgerNext,
    required this.onAuditLog,
    required this.fmtInt,
    required this.fmtTs,
  });

  final Map<String, dynamic> data;
  final bool chartThisWeek;
  final void Function(bool thisWeek) onChartWeekChanged;
  final int ledgerPage;
  final int ledgerLimit;
  final VoidCallback onLedgerPrev;
  final VoidCallback onLedgerNext;
  final VoidCallback onAuditLog;
  final String Function(num) fmtInt;
  final String Function(dynamic) fmtTs;

  @override
  Widget build(BuildContext context) {
    final users = data['users'];
    final learners =
        users is Map ? (parseJsonInt(users['learners']) ?? 0) : 0;
    final growth = parseJsonDouble(data['user_growth_percent']) ?? 0.0;
    final topics = parseJsonInt(data['topics']) ?? 0;
    final topicsNew = parseJsonInt(data['topics_new_30d']) ?? 0;
    final vocabs = parseJsonInt(data['vocabularies']) ?? 0;
    final vocabNew = parseJsonInt(data['vocab_new_30d']) ?? 0;
    final activeWeek = parseJsonInt(data['active_learners_week']) ?? 0;
    final badgeExtra = parseJsonInt(data['learners_badge_extra']) ?? 0;
    final recentNames = (data['recent_learner_usernames'] as List<dynamic>?)
            ?.map((e) => '$e')
            .toList() ??
        <String>[];

    final actThis = _parseActivity(data['activity_this_week']);
    final actLast = _parseActivity(data['activity_last_week']);
    final chartData = chartThisWeek ? actThis : actLast;

    final mastery = data['mastery'];
    String masteryMsg = '';
    int masteryPct = 0;
    if (mastery is Map) {
      masteryMsg = '${mastery['message'] ?? ''}';
      masteryPct = parseJsonInt(mastery['percent']) ?? 0;
    }

    final ledger = (data['ledger'] as List<dynamic>?) ?? [];
    final ledgerTotal = parseJsonInt(data['ledger_total_all']) ?? 0;
    final activitiesToday = parseJsonInt(data['activities_today']) ?? 0;

    final maxPage = ledgerTotal > 0
        ? ((ledgerTotal - 1) / ledgerLimit).floor()
        : 0;
    final canPrev = ledgerPage > 0;
    final canNext = ledgerPage < maxPage;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Tổng quan hệ thống',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 32,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.8,
            color: AppColors.onSurface,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Chào mừng trở lại. Đây là trạng thái hiện tại của Academic Atelier.',
          style: GoogleFonts.inter(
            fontSize: 17,
            height: 1.4,
            color: AppColors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 28),
        LayoutBuilder(
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
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              childAspectRatio: cols == 4 ? 1.45 : 1.55,
              children: [
                _StatCard(
                  icon: Icons.group_rounded,
                  iconBg: const Color(0xFFEEF2FF),
                  iconColor: AppColors.primaryContainer,
                  label: 'Tổng người học hoạt động',
                  value: fmtInt(learners),
                  trailing: '+${growth.toStringAsFixed(1)}%',
                  trailingStyle: GoogleFonts.robotoMono(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.secondary,
                  ),
                  watermark: Icons.group_rounded,
                ),
                _StatCard(
                  icon: Icons.category_rounded,
                  iconBg: const Color(0xFFFFF7ED),
                  iconColor: const Color(0xFFD97706),
                  label: 'Chủ đề học thuật',
                  value: fmtInt(topics),
                  trailing: '$topicsNew mới (30 ngày)',
                  trailingStyle: GoogleFonts.robotoMono(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppColors.onSurfaceVariant,
                  ),
                  watermark: Icons.category_rounded,
                ),
                _StatCard(
                  icon: Icons.menu_book_rounded,
                  iconBg: const Color(0xFFF0FDF4),
                  iconColor: const Color(0xFF16A34A),
                  label: 'Kho từ vựng',
                  value: fmtInt(vocabs),
                  trailing: '+$vocabNew từ (30 ngày)',
                  trailingStyle: GoogleFonts.robotoMono(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.secondary,
                  ),
                  watermark: Icons.menu_book_rounded,
                ),
                _StatCard(
                  icon: Icons.bolt_rounded,
                  iconBg: const Color(0xFFFEF2F2),
                  iconColor: const Color(0xFFDC2626),
                  label: 'Người học trong tuần (quiz)',
                  value: fmtInt(activeWeek),
                  trailing: '',
                  trailingStyle: GoogleFonts.robotoMono(fontSize: 12),
                  watermark: Icons.bolt_rounded,
                  extraAvatars: recentNames,
                  badgePlus: badgeExtra > 0 ? '+$badgeExtra' : null,
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 28),
        LayoutBuilder(
          builder: (context, c) {
            if (c.maxWidth >= 960) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 2,
                    child: _ActivityPulseCard(
                      data: chartData,
                      thisWeek: chartThisWeek,
                      onToggle: onChartWeekChanged,
                    ),
                  ),
                  const SizedBox(width: 24),
                  Expanded(
                    child: _MasteryCard(
                      percent: masteryPct,
                      message: masteryMsg,
                    ),
                  ),
                ],
              );
            }
            return Column(
              children: [
                _ActivityPulseCard(
                  data: chartData,
                  thisWeek: chartThisWeek,
                  onToggle: onChartWeekChanged,
                ),
                const SizedBox(height: 20),
                _MasteryCard(
                  percent: masteryPct,
                  message: masteryMsg,
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 28),
        _LedgerSection(
          ledger: ledger,
          ledgerTotal: ledgerTotal,
          activitiesToday: activitiesToday,
          ledgerPage: ledgerPage,
          ledgerLimit: ledgerLimit,
          canPrev: canPrev,
          canNext: canNext,
          onPrev: onLedgerPrev,
          onNext: onLedgerNext,
          onAuditLog: onAuditLog,
          fmtTs: fmtTs,
        ),
      ],
    );
  }

  static List<int> _parseActivity(dynamic raw) {
    if (raw is! List) {
      return List.filled(7, 0);
    }
    return List.generate(7, (i) {
      if (i >= raw.length) {
        return 0;
      }
      return parseJsonInt(raw[i]) ?? 0;
    });
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.label,
    required this.value,
    required this.trailing,
    required this.trailingStyle,
    required this.watermark,
    this.extraAvatars,
    this.badgePlus,
  });

  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String label;
  final String value;
  final String trailing;
  final TextStyle trailingStyle;
  final IconData watermark;
  final List<String>? extraAvatars;
  final String? badgePlus;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: AppColors.onSurface.withValues(alpha: 0.06),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned(
            right: -16,
            bottom: -16,
            child: Icon(
              watermark,
              size: 120,
              color: AppColors.onSurface.withValues(alpha: 0.05),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: iconBg,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, color: iconColor, size: 26),
                  ),
                  const Spacer(),
                  if (trailing.isNotEmpty)
                    Text(trailing, style: trailingStyle),
                  if (extraAvatars != null && extraAvatars!.isNotEmpty)
                    Row(
                      children: [
                        for (var i = 0;
                            i < extraAvatars!.length && i < 3;
                            i++)
                          Align(
                            widthFactor: i == 0 ? 1 : 0.75,
                            child: CircleAvatar(
                              radius: 12,
                              backgroundColor: const Color(0xFFE2E8F0),
                              child: Text(
                                extraAvatars![i].isNotEmpty
                                    ? extraAvatars![i][0].toUpperCase()
                                    : '?',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ),
                        if (badgePlus != null)
                          Container(
                            width: 26,
                            height: 26,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: const Color(0xFFE2E8F0),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                            child: Text(
                              badgePlus!,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 8,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                      ],
                    ),
                ],
              ),
              const Spacer(),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                value,
                style: GoogleFonts.robotoMono(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: AppColors.onSurface,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActivityPulseCard extends StatelessWidget {
  const _ActivityPulseCard({
    required this.data,
    required this.thisWeek,
    required this.onToggle,
  });

  final List<int> data;
  final bool thisWeek;
  final void Function(bool thisWeek) onToggle;

  static const _days = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];

  @override
  Widget build(BuildContext context) {
    final maxV = data.isEmpty ? 1 : data.reduce((a, b) => a > b ? a : b);
    final scale = maxV > 0 ? maxV : 1;
    final now = DateTime.now();
    final weekdayMon = now.weekday - 1;
    final highlightIndex = weekdayMon.clamp(0, 6);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: AppColors.onSurface.withValues(alpha: 0.06),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
            child: Row(
              children: [
                Text(
                  'Nhịp độ hoạt động',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const Spacer(),
                _WeekChip(
                  label: 'TUẦN NÀY',
                  selected: thisWeek,
                  onTap: () => onToggle(true),
                ),
                const SizedBox(width: 8),
                _WeekChip(
                  label: 'TUẦN TRƯỚC',
                  selected: !thisWeek,
                  onTap: () => onToggle(false),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
            child: SizedBox(
              height: 200,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: List.generate(7, (i) {
                  final v = i < data.length ? data[i] : 0;
                  final h = (v / scale).clamp(0.0, 1.0);
                  final isHi = i == highlightIndex && thisWeek;
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Expanded(
                            child: LayoutBuilder(
                              builder: (context, c) {
                                final barH = c.maxHeight * h;
                                return Stack(
                                  alignment: Alignment.bottomCenter,
                                  children: [
                                    Container(
                                      width: double.infinity,
                                      height: c.maxHeight,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF0ECF9),
                                        borderRadius: const BorderRadius.vertical(
                                          top: Radius.circular(8),
                                        ),
                                      ),
                                    ),
                                    Container(
                                      width: double.infinity,
                                      height: barH < 4 ? 4.0 : barH,
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          begin: Alignment.bottomCenter,
                                          end: Alignment.topCenter,
                                          colors: [
                                            AppColors.primaryContainer,
                                            AppColors.primaryContainer
                                                .withValues(alpha: 0.55),
                                          ],
                                        ),
                                        borderRadius: const BorderRadius.vertical(
                                          top: Radius.circular(8),
                                        ),
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            _days[i],
                            style: GoogleFonts.robotoMono(
                              fontSize: 10,
                              fontWeight:
                                  isHi ? FontWeight.w800 : FontWeight.w500,
                              color: isHi
                                  ? AppColors.primaryContainer
                                  : const Color(0xFF94A3B8),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WeekChip extends StatelessWidget {
  const _WeekChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? AppColors.primaryContainer.withValues(alpha: 0.12)
          : Colors.transparent,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Text(
            label,
            style: GoogleFonts.robotoMono(
              fontSize: 9,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.3,
              color: selected
                  ? AppColors.primaryContainer
                  : const Color(0xFF94A3B8),
            ),
          ),
        ),
      ),
    );
  }
}

class _MasteryCard extends StatelessWidget {
  const _MasteryCard({
    required this.percent,
    required this.message,
  });

  final int percent;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(26),
      decoration: BoxDecoration(
        color: AppColors.primaryContainer,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryContainer.withValues(alpha: 0.35),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned(
            right: -40,
            bottom: -40,
            child: Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.06),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Thành tựu tinh thông',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                message.isEmpty
                    ? 'Dữ liệu tinh thông đang được tổng hợp từ tiến độ từ vựng và điểm quiz.'
                    : message,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  height: 1.5,
                  color: const Color(0xFFE2DFFF),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '$percent',
                    style: GoogleFonts.robotoMono(
                      fontSize: 48,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      height: 1,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8, left: 4),
                    child: Text(
                      '%',
                      style: GoogleFonts.robotoMono(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.secondaryFixed.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.trending_up_rounded,
                          size: 14,
                          color: AppColors.secondaryFixed,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'TỐC ĐỘ',
                          style: GoogleFonts.robotoMono(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            color: AppColors.secondaryFixed,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LedgerSection extends StatelessWidget {
  const _LedgerSection({
    required this.ledger,
    required this.ledgerTotal,
    required this.activitiesToday,
    required this.ledgerPage,
    required this.ledgerLimit,
    required this.canPrev,
    required this.canNext,
    required this.onPrev,
    required this.onNext,
    required this.onAuditLog,
    required this.fmtTs,
  });

  final List<dynamic> ledger;
  final int ledgerTotal;
  final int activitiesToday;
  final int ledgerPage;
  final int ledgerLimit;
  final bool canPrev;
  final bool canNext;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final VoidCallback onAuditLog;
  final String Function(dynamic) fmtTs;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: AppColors.onSurface.withValues(alpha: 0.06),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Nhật ký học tập gần đây',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Theo dõi trực tiếp tương tác học viên (quiz, từ đã thuộc).',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                FilledButton.tonal(
                  onPressed: onAuditLog,
                  child: Text(
                    'Xem nhật ký kiểm tra',
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(
                const Color(0xFFF8FAFC).withValues(alpha: 0.9),
              ),
              columns: [
                DataColumn(
                  label: Text(
                    'HỌC VIÊN / NGƯỜI DÙNG',
                    style: GoogleFonts.robotoMono(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'HÀNH ĐỘNG / THÀNH TỰU',
                    style: GoogleFonts.robotoMono(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'THỜI GIAN',
                    style: GoogleFonts.robotoMono(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                ),
                DataColumn(
                  label: Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      'HIỆU SUẤT',
                      style: GoogleFonts.robotoMono(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                  ),
                ),
              ],
              rows: [
                for (final raw in ledger)
                  if (raw is Map)
                    DataRow(
                      cells: [
                        DataCell(_UserCell(
                          username: '${raw['username'] ?? ''}',
                          userId: parseJsonInt(raw['user_id']) ?? 0,
                          role: '${raw['role'] ?? ''}',
                        )),
                        DataCell(_ActionCell(
                          action: '${raw['action'] ?? ''}',
                          dotColor: '${raw['dot_color'] ?? 'green'}',
                        )),
                        DataCell(
                          Text(
                            fmtTs(raw['timestamp']),
                            style: GoogleFonts.robotoMono(
                              fontSize: 12,
                              color: const Color(0xFF64748B),
                            ),
                          ),
                        ),
                        DataCell(
                          Align(
                            alignment: Alignment.centerRight,
                            child: _PerfCell(
                              label: '${raw['performance_label'] ?? ''}',
                              colorKey: '${raw['performance_color'] ?? 'green'}',
                            ),
                          ),
                        ),
                      ],
                    ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            color: const Color(0xFFF8FAFC).withValues(alpha: 0.85),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'HIỂN THỊ ${ledger.length} / $ledgerTotal HOẠT ĐỘNG • HÔM NAY: $activitiesToday',
                    style: GoogleFonts.robotoMono(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.4,
                      color: const Color(0xFF94A3B8),
                    ),
                  ),
                ),
                IconButton(
                  onPressed: canPrev ? onPrev : null,
                  icon: const Icon(Icons.chevron_left_rounded),
                  color: const Color(0xFF64748B),
                ),
                IconButton(
                  onPressed: canNext ? onNext : null,
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

class _UserCell extends StatelessWidget {
  const _UserCell({
    required this.username,
    required this.userId,
    required this.role,
  });

  final String username;
  final int userId;
  final String role;

  @override
  Widget build(BuildContext context) {
    final idLabel =
        role == 'admin' ? 'NV-$userId' : 'USR-${userId.toString().padLeft(5, '0')}';
    return Row(
      children: [
        CircleAvatar(
          radius: 18,
          backgroundColor: AppColors.primaryContainer.withValues(alpha: 0.15),
          child: Text(
            username.isNotEmpty ? username[0].toUpperCase() : '?',
            style: GoogleFonts.plusJakartaSans(
              fontWeight: FontWeight.w900,
              color: AppColors.primaryContainer,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              username,
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w800,
                fontSize: 13,
              ),
            ),
            Text(
              idLabel,
              style: GoogleFonts.robotoMono(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: role == 'admin'
                    ? const Color(0xFF92400E)
                    : AppColors.primaryContainer,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ActionCell extends StatelessWidget {
  const _ActionCell({required this.action, required this.dotColor});

  final String action;
  final String dotColor;

  @override
  Widget build(BuildContext context) {
    Color c;
    switch (dotColor) {
      case 'blue':
        c = AppColors.primaryContainer;
        break;
      case 'orange':
        c = const Color(0xFFF59E0B);
        break;
      default:
        c = AppColors.secondary;
    }
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: c, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            action,
            style: GoogleFonts.inter(fontSize: 13),
          ),
        ),
      ],
    );
  }
}

class _PerfCell extends StatelessWidget {
  const _PerfCell({required this.label, required this.colorKey});

  final String label;
  final String colorKey;

  @override
  Widget build(BuildContext context) {
    Color c;
    switch (colorKey) {
      case 'green':
        c = AppColors.secondary;
        break;
      case 'blue':
        c = AppColors.primaryContainer;
        break;
      case 'orange':
        c = const Color(0xFFD97706);
        break;
      default:
        c = const Color(0xFF94A3B8);
    }
    return Text(
      label,
      textAlign: TextAlign.right,
      style: GoogleFonts.robotoMono(
        fontSize: 12,
        fontWeight: FontWeight.w800,
        color: c,
      ),
    );
  }
}

