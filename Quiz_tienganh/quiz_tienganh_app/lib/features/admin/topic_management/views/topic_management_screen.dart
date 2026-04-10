import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../data/models/topic_model.dart';
import '../../../../data/repositories/admin_repository.dart';
import '../../../../data/repositories/topics_repository.dart';
import '../../../auth/controllers/auth_provider.dart';
import '../../shell/admin_scaffold.dart';
import '../../widgets/admin_delete_dialog.dart';
import '../../widgets/admin_page_footer.dart';
import '../topic_description_codec.dart';

class _TopicPageData {
  const _TopicPageData({required this.topics, required this.stats});

  final List<TopicModel> topics;
  final Map<String, dynamic> stats;
}

class TopicManagementScreen extends StatefulWidget {
  const TopicManagementScreen({super.key});

  @override
  State<TopicManagementScreen> createState() => _TopicManagementScreenState();
}

class _TopicManagementScreenState extends State<TopicManagementScreen> {
  final _searchCtrl = TextEditingController();
  Future<_TopicPageData>? _future;
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

  Future<_TopicPageData> _load() async {
    final topicsRepo = context.read<TopicsRepository>();
    final adminRepo = context.read<AdminRepository>();
    final topics = await topicsRepo.fetchTopics();
    final stats = await adminRepo.topicManagementSummary();
    return _TopicPageData(topics: topics, stats: stats);
  }

  Future<void> _reload() async {
    setState(() {
      _future = _load();
    });
    await _future;
  }

  Future<void> _openCurate({TopicModel? editing}) async {
    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      barrierColor: const Color(0xFF0F172A).withValues(alpha: 0.6),
      builder: (ctx) => _TopicCurateDialog(editing: editing),
    );
    if (ok == true && mounted) {
      await _reload();
    }
  }

  Future<void> _delete(TopicModel t) async {
    final confirmed = await showAdminDeleteDialog(
      context: context,
      title: 'Xóa chủ đề?',
      message:
          'Thao tác này không thể hoàn tác. Mọi từ vựng thuộc chủ đề cũng sẽ bị xóa theo quy tắc máy chủ (CASCADE).',
      highlight: t.name,
      confirmLabel: 'Xóa vĩnh viễn',
    );
    if (!confirmed || !mounted) {
      return;
    }
    try {
      await context.read<TopicsRepository>().deleteTopic(t.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã xóa chủ đề.')),
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

  List<TopicModel> _filtered(List<TopicModel> all) {
    final q = _searchApplied.trim().toLowerCase();
    if (q.isEmpty) {
      return all;
    }
    return all.where((t) {
      final (_, body) = TopicDescriptionCodec.parse(t.description);
      final blob = '${t.name} $body ${t.description ?? ''}'.toLowerCase();
      return blob.contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return AdminScaffold(
      title: 'Quản lý chủ đề',
      showInnerHeader: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _TopicModuleHeader(
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
            onHelp: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Tìm kiếm lọc theo tên và mô tả chủ đề.'),
                ),
              );
            },
          ),
          Expanded(
            child: FutureBuilder<_TopicPageData>(
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
                final topics = data.topics;
                final stats = data.stats;
                final totalTopics =
                    (stats['total_topics'] as num?)?.toInt() ?? topics.length;
                final totalVocabs =
                    (stats['total_vocabularies'] as num?)?.toInt() ?? 0;
                final mastery =
                    (stats['mastery_percent'] as num?)?.toInt() ?? 0;

                final filtered = _filtered(topics);
                final totalF = filtered.length;
                final maxPage = totalF <= 0 ? 0 : (totalF - 1) ~/ _pageSize;
                final safePage = _page.clamp(0, maxPage);
                final start = safePage * _pageSize;
                final pageItems = start < totalF
                    ? filtered.sublist(
                        start,
                        start + _pageSize > totalF
                            ? totalF
                            : start + _pageSize,
                      )
                    : <TopicModel>[];

                return RefreshIndicator(
                  onRefresh: _reload,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _PageHeaderRow(
                          onAdd: () => _openCurate(),
                        ),
                        const SizedBox(height: 28),
                        _KpiRow(
                          totalTopics: totalTopics,
                          totalVocabularies: totalVocabs,
                          masteryPercent: mastery,
                        ),
                        const SizedBox(height: 28),
                        _TopicCatalogTable(
                          topics: pageItems,
                          totalFiltered: totalF,
                          page: safePage,
                          pageSize: _pageSize,
                          onEdit: (t) => _openCurate(editing: t),
                          onDelete: _delete,
                          onPrev: safePage > 0
                              ? () => setState(() => _page = safePage - 1)
                              : null,
                          onNext: safePage < maxPage
                              ? () => setState(() => _page = safePage + 1)
                              : null,
                          onFilter: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Bộ lọc nâng cao sẽ bổ sung sau.'),
                              ),
                            );
                          },
                          onExport: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Xuất CSV sẽ bổ sung sau.'),
                              ),
                            );
                          },
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

class _TopicModuleHeader extends StatelessWidget {
  const _TopicModuleHeader({
    required this.searchController,
    required this.displayName,
    required this.onSearch,
    required this.onNotifications,
    required this.onHelp,
  });

  final TextEditingController searchController;
  final String displayName;
  final VoidCallback onSearch;
  final VoidCallback onNotifications;
  final VoidCallback onHelp;

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
                    hintText: 'Tìm chủ đề…',
                    prefixIcon: const Icon(Icons.search_rounded,
                        color: Color(0xFF94A3B8)),
                    filled: true,
                    fillColor: const Color(0xFFF1F5F9).withValues(alpha: 0.85),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(999),
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
              tooltip: 'Trợ giúp',
              onPressed: onHelp,
              icon: const Icon(Icons.help_outline_rounded),
              color: const Color(0xFF64748B),
            ),
            Container(
              width: 1,
              height: 32,
              color: const Color(0xFFE2E8F0),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  displayName,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  'Quản trị hệ thống',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 9,
                    color: const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 10),
            CircleAvatar(
              radius: 18,
              backgroundColor:
                  AppColors.primaryContainer.withValues(alpha: 0.2),
              child: Text(
                displayName.isNotEmpty
                    ? displayName[0].toUpperCase()
                    : 'A',
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w900,
                  color: AppColors.primaryContainer,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PageHeaderRow extends StatelessWidget {
  const _PageHeaderRow({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final row = c.maxWidth >= 720;
        final left = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'KHO HỌC LIỆU',
                  style: GoogleFonts.robotoMono(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1,
                    color: const Color(0xFF94A3B8),
                  ),
                ),
                const Icon(Icons.chevron_right_rounded,
                    size: 14, color: Color(0xFF94A3B8)),
                Text(
                  'THƯ VIỆN CHỦ ĐỀ',
                  style: GoogleFonts.robotoMono(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1,
                    color: AppColors.primaryContainer,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              'Quản lý chủ đề',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 34,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.8,
                color: AppColors.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tổ chức chương trình theo cụm chủ đề. Các chủ đề là xương sống cho hành trình từ vựng của học viên.',
              style: GoogleFonts.inter(
                fontSize: 13,
                height: 1.5,
                color: AppColors.onSurfaceVariant,
              ),
            ),
          ],
        );
        final btn = FilledButton.icon(
          onPressed: onAdd,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            elevation: 4,
            shadowColor: AppColors.primaryContainer.withValues(alpha: 0.35),
          ),
          icon: const Icon(Icons.add_rounded, size: 22),
          label: Text(
            'Thêm chủ đề mới',
            style: GoogleFonts.plusJakartaSans(
              fontWeight: FontWeight.w800,
              fontSize: 14,
            ),
          ),
        );
        if (row) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(child: left),
              btn,
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            left,
            const SizedBox(height: 20),
            btn,
          ],
        );
      },
    );
  }
}

class _KpiRow extends StatelessWidget {
  const _KpiRow({
    required this.totalTopics,
    required this.totalVocabularies,
    required this.masteryPercent,
  });

  final int totalTopics;
  final int totalVocabularies;
  final int masteryPercent;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final w = c.maxWidth;
        final cols = w >= 1000 ? 3 : (w >= 520 ? 2 : 1);
        return GridView.count(
          crossAxisCount: cols,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 14,
          crossAxisSpacing: 14,
          childAspectRatio: cols == 3 ? 1.55 : 1.45,
          children: [
            _KpiCard(
              icon: Icons.category_rounded,
              iconBg: const Color(0xFFEEF2FF),
              iconColor: AppColors.primaryContainer,
              chip: 'CHỦ ĐỀ HOẠT ĐỘNG',
              chipColor: AppColors.primaryContainer,
              value: '$totalTopics',
              caption: 'Tổng số chủ đề đang xuất bản trên hệ thống.',
            ),
            _KpiCard(
              icon: Icons.menu_book_rounded,
              iconBg: const Color(0xFFD1FAE5),
              iconColor: const Color(0xFF059669),
              chip: 'ĐỘ SÂU TỪ VỰNG',
              chipColor: const Color(0xFF059669),
              value: _fmtInt(totalVocabularies),
              caption: 'Số mục từ đã gán vào các chủ đề.',
            ),
            _KpiCard(
              icon: Icons.trending_up_rounded,
              iconBg: const Color(0xFFFEF3C7),
              iconColor: const Color(0xFFD97706),
              chip: 'TƯƠNG TÁC',
              chipColor: const Color(0xFFD97706),
              value: '$masteryPercent%',
              caption: 'Tỷ lệ từ đạt trạng thái «đã thuộc» trên toàn hệ thống.',
            ),
          ],
        );
      },
    );
  }

  static String _fmtInt(int n) {
    final s = n.toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) {
        buf.write(',');
      }
      buf.write(s[i]);
    }
    return buf.toString();
  }
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.chip,
    required this.chipColor,
    required this.value,
    required this.caption,
  });

  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String chip;
  final Color chipColor;
  final String value;
  final String caption;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: AppColors.onSurface.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
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
                  color: chipColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  chip,
                  style: GoogleFonts.robotoMono(
                    fontSize: 8,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.4,
                    color: chipColor,
                  ),
                ),
              ),
            ],
          ),
          const Spacer(),
          Text(
            value,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            caption,
            style: GoogleFonts.inter(
              fontSize: 11,
              height: 1.35,
              color: const Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }
}

class _TopicCatalogTable extends StatelessWidget {
  const _TopicCatalogTable({
    required this.topics,
    required this.totalFiltered,
    required this.page,
    required this.pageSize,
    required this.onEdit,
    required this.onDelete,
    required this.onPrev,
    required this.onNext,
    required this.onFilter,
    required this.onExport,
  });

  final List<TopicModel> topics;
  final int totalFiltered;
  final int page;
  final int pageSize;
  final void Function(TopicModel) onEdit;
  final void Function(TopicModel) onDelete;
  final VoidCallback? onPrev;
  final VoidCallback? onNext;
  final VoidCallback onFilter;
  final VoidCallback onExport;

  static String _initials(String name) {
    final p = name.trim().split(RegExp(r'\s+')).where((e) => e.isNotEmpty);
    final buf = StringBuffer();
    for (final w in p.take(2)) {
      buf.write(w[0].toUpperCase());
    }
    return buf.isEmpty ? '?' : buf.toString();
  }

  @override
  Widget build(BuildContext context) {
    final from = totalFiltered == 0 ? 0 : page * pageSize + 1;
    final to = (page + 1) * pageSize > totalFiltered
        ? totalFiltered
        : (page + 1) * pageSize;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(18),
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
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            color: AppColors.surfaceContainerHighest.withValues(alpha: 0.35),
            child: Row(
              children: [
                Text(
                  'Danh mục chương trình',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const Spacer(),
                IconButton(
                  tooltip: 'Lọc',
                  onPressed: onFilter,
                  icon: const Icon(Icons.filter_list_rounded),
                  color: const Color(0xFF94A3B8),
                ),
                IconButton(
                  tooltip: 'Xuất',
                  onPressed: onExport,
                  icon: const Icon(Icons.download_rounded),
                  color: const Color(0xFF94A3B8),
                ),
              ],
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 880),
              child: DataTable(
                headingRowHeight: 48,
                dataRowMinHeight: 64,
                dataRowMaxHeight: 88,
                headingRowColor: WidgetStateProperty.all(
                  Colors.white.withValues(alpha: 0.5),
                ),
                columns: [
                  DataColumn(
                    label: Text(
                      'CHỦ ĐỀ',
                      style: GoogleFonts.robotoMono(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.6,
                        color: const Color(0xFF94A3B8),
                      ),
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      'MÔ TẢ & PHẠM VI',
                      style: GoogleFonts.robotoMono(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.6,
                        color: const Color(0xFF94A3B8),
                      ),
                    ),
                  ),
                  DataColumn(
                    label: Center(
                      child: Text(
                        'SỐ TỪ',
                        style: GoogleFonts.robotoMono(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.6,
                          color: const Color(0xFF94A3B8),
                        ),
                      ),
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      'TRẠNG THÁI',
                      style: GoogleFonts.robotoMono(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.6,
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
                          letterSpacing: 0.6,
                          color: const Color(0xFF94A3B8),
                        ),
                      ),
                    ),
                  ),
                ],
                rows: [
                  for (final t in topics)
                    DataRow(
                      cells: [
                        DataCell(
                          Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: AppColors.primaryContainer
                                      .withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  _initials(t.name),
                                  style: GoogleFonts.plusJakartaSans(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 12,
                                    color: AppColors.primaryContainer,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    t.name,
                                    style: GoogleFonts.plusJakartaSans(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 13,
                                    ),
                                  ),
                                  Text(
                                    'ID: TOP-${t.id.toString().padLeft(3, '0')}',
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
                          Builder(
                            builder: (context) {
                              final (cat, body) =
                                  TopicDescriptionCodec.parse(t.description);
                              final short =
                                  body.isEmpty ? cat : body;
                              final clip = short.length > 80
                                  ? '${short.substring(0, 80)}…'
                                  : short;
                              return Text(
                                clip,
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  color: const Color(0xFF475569),
                                ),
                              );
                            },
                          ),
                        ),
                        DataCell(
                          Center(
                            child: Text(
                              '${t.wordCount}',
                              style: GoogleFonts.robotoMono(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                                color: AppColors.primaryContainer,
                              ),
                            ),
                          ),
                        ),
                        DataCell(
                          _StatusPill(active: t.wordCount > 0),
                        ),
                        DataCell(
                          Align(
                            alignment: Alignment.centerRight,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  tooltip: 'Sửa',
                                  onPressed: () => onEdit(t),
                                  icon: const Icon(Icons.edit_rounded),
                                  color: const Color(0xFF94A3B8),
                                ),
                                IconButton(
                                  tooltip: 'Xóa',
                                  onPressed: () => onDelete(t),
                                  icon: const Icon(Icons.delete_outline_rounded),
                                  color: AppColors.error.withValues(alpha: 0.85),
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
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              border: Border(
                top: BorderSide(
                  color: const Color(0xFFE2E8F0).withValues(alpha: 0.9),
                ),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'HIỂN THỊ $from–$to TRÊN $totalFiltered CHỦ ĐỀ',
                    style: GoogleFonts.robotoMono(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.4,
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

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.active});

  final bool active;

  @override
  Widget build(BuildContext context) {
    if (active) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFFECFDF5),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          'HOẠT ĐỘNG',
          style: GoogleFonts.robotoMono(
            fontSize: 9,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.3,
            color: const Color(0xFF047857),
          ),
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        'NHÁP',
        style: GoogleFonts.robotoMono(
          fontSize: 9,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.3,
          color: const Color(0xFF64748B),
        ),
      ),
    );
  }
}

class _TopicCurateDialog extends StatefulWidget {
  const _TopicCurateDialog({this.editing});

  final TopicModel? editing;

  @override
  State<_TopicCurateDialog> createState() => _TopicCurateDialogState();
}

class _TopicCurateDialogState extends State<_TopicCurateDialog> {
  late final TextEditingController _titleCtrl;
  late final TextEditingController _descCtrl;
  late String _category;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final e = widget.editing;
    if (e != null) {
      final (cat, body) = TopicDescriptionCodec.parse(e.description);
      _titleCtrl = TextEditingController(text: e.name);
      _descCtrl = TextEditingController(text: body);
      _category = TopicDescriptionCodec.categoryOptions.contains(cat)
          ? cat
          : 'Chung';
    } else {
      _titleCtrl = TextEditingController();
      _descCtrl = TextEditingController();
      _category = 'Học thuật';
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _titleCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng nhập tên chủ đề.')),
      );
      return;
    }
    final repo = context.read<TopicsRepository>();
    setState(() => _saving = true);
    try {
      final desc = TopicDescriptionCodec.compose(_category, _descCtrl.text);
      if (widget.editing == null) {
        await repo.createTopic(
          name: name,
          description: desc.isEmpty ? null : desc,
        );
      } else {
        await repo.updateTopic(
          widget.editing!.id,
          name: name,
          description: desc,
        );
      }
      if (mounted) {
        Navigator.pop(context, true);
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message)),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final edit = widget.editing;
    final wc = edit?.wordCount ?? 0;

    return Center(
      child: SingleChildScrollView(
        child: Material(
          color: Colors.transparent,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.onSurface.withValues(alpha: 0.12),
                    blurRadius: 40,
                    offset: const Offset(0, 20),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.fromLTRB(22, 18, 12, 18),
                    color: AppColors.primaryContainer,
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Thông tin chủ đề',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                edit == null
                                    ? 'Tạo mục mới trong kho học liệu.'
                                    : 'Cập nhật nội dung chủ đề trong thư viện.',
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  color: const Color(0xFFE2DFFF),
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed:
                              _saving ? null : () => Navigator.pop(context),
                          icon: const Icon(Icons.close_rounded),
                          color: Colors.white.withValues(alpha: 0.75),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'TÊN CHỦ ĐỀ',
                          style: GoogleFonts.robotoMono(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                            color: const Color(0xFF94A3B8),
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _titleCtrl,
                          decoration: InputDecoration(
                            hintText: 'Ví dụ: Tâm lý học nhận thức',
                            filled: true,
                            fillColor: AppColors.surfaceContainerHighest,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),
                        Text(
                          'MÔ TẢ CHI TIẾT',
                          style: GoogleFonts.robotoMono(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                            color: const Color(0xFF94A3B8),
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _descCtrl,
                          minLines: 4,
                          maxLines: 8,
                          decoration: InputDecoration(
                            hintText:
                                'Mô tả phạm vi ngôn ngữ và mục tiêu học của chủ đề…',
                            filled: true,
                            fillColor: AppColors.surfaceContainerHighest,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.all(16),
                          ),
                        ),
                        const SizedBox(height: 18),
                        LayoutBuilder(
                          builder: (context, c) {
                            if (c.maxWidth >= 480) {
                              return Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(child: _categoryField()),
                                  const SizedBox(width: 16),
                                  Expanded(child: _wordCountField(wc)),
                                ],
                              );
                            }
                            return Column(
                              children: [
                                _categoryField(),
                                const SizedBox(height: 16),
                                _wordCountField(wc),
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: 28),
                        Row(
                          children: [
                            TextButton(
                              onPressed:
                                  _saving ? null : () => Navigator.pop(context),
                              child: Text(
                                'Hủy bỏ',
                                style: GoogleFonts.plusJakartaSans(
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFF94A3B8),
                                ),
                              ),
                            ),
                            const Spacer(),
                            FilledButton(
                              onPressed: _saving ? null : _save,
                              style: FilledButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 28,
                                  vertical: 16,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                elevation: 3,
                                shadowColor: AppColors.primaryContainer
                                    .withValues(alpha: 0.35),
                              ),
                              child: _saving
                                  ? const SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : Text(
                                      'Lưu thông tin',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _categoryField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'PHÂN LOẠI',
          style: GoogleFonts.robotoMono(
            fontSize: 9,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.8,
            color: const Color(0xFF94A3B8),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(14),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _category,
              isExpanded: true,
              borderRadius: BorderRadius.circular(12),
              items: [
                for (final o in TopicDescriptionCodec.categoryOptions)
                  DropdownMenuItem(value: o, child: Text(o)),
              ],
              onChanged: _saving
                  ? null
                  : (v) {
                      if (v != null) {
                        setState(() => _category = v);
                      }
                    },
            ),
          ),
        ),
      ],
    );
  }

  Widget _wordCountField(int wc) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'SỐ LƯỢNG TỪ',
          style: GoogleFonts.robotoMono(
            fontSize: 9,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.8,
            color: const Color(0xFF94A3B8),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Text(
            '$wc',
            style: GoogleFonts.robotoMono(
              fontWeight: FontWeight.w600,
              fontSize: 15,
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          widget.editing == null
              ? 'Sau khi lưu, thêm từ trong mục Quản lý từ vựng.'
              : 'Cập nhật khi thêm/xóa từ trong Quản lý từ vựng.',
          style: GoogleFonts.inter(
            fontSize: 10,
            color: const Color(0xFF94A3B8),
            height: 1.3,
          ),
        ),
      ],
    );
  }
}
