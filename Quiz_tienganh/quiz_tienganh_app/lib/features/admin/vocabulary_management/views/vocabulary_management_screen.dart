import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../data/models/topic_model.dart';
import '../../../../data/models/vocabulary_model.dart';
import '../../../../data/repositories/admin_repository.dart';
import '../../../../data/repositories/topics_repository.dart';
import '../../../../data/repositories/vocabularies_repository.dart';
import '../../../auth/controllers/auth_provider.dart';
import '../../shell/admin_scaffold.dart';
import '../../widgets/admin_delete_dialog.dart';
import '../../widgets/admin_page_footer.dart';

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

class _VocabPageData {
  const _VocabPageData({
    required this.topics,
    required this.vocabs,
    required this.stats,
  });

  final List<TopicModel> topics;
  final List<VocabularyModel> vocabs;
  final Map<String, dynamic> stats;
}

class VocabularyManagementScreen extends StatefulWidget {
  const VocabularyManagementScreen({super.key});

  @override
  State<VocabularyManagementScreen> createState() =>
      _VocabularyManagementScreenState();
}

class _VocabularyManagementScreenState
    extends State<VocabularyManagementScreen> {
  final _searchCtrl = TextEditingController();
  Future<_VocabPageData>? _future;
  String _searchApplied = '';
  int? _topicFilterId;
  String? _difficultyFilter;
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

  Future<_VocabPageData> _load() async {
    final vocabRepo = context.read<VocabulariesRepository>();
    final topicsRepo = context.read<TopicsRepository>();
    final adminRepo = context.read<AdminRepository>();
    final topics = await topicsRepo.fetchTopics();
    final stats = await adminRepo.vocabularyManagementSummary();
    final vocabs = await vocabRepo.fetchAll(
      topicId: _topicFilterId,
      difficulty: _difficultyFilter,
      q: _searchApplied.trim().isEmpty ? null : _searchApplied.trim(),
    );
    return _VocabPageData(topics: topics, vocabs: vocabs, stats: stats);
  }

  Future<void> _reload() async {
    setState(() {
      _future = _load();
    });
    await _future;
  }

  void _resetFilters() {
    setState(() {
      _topicFilterId = null;
      _difficultyFilter = null;
      _searchCtrl.clear();
      _searchApplied = '';
      _page = 0;
      _future = _load();
    });
  }

  Future<void> _openEditor({VocabularyModel? editing}) async {
    final topics = await context.read<TopicsRepository>().fetchTopics();
    if (!mounted) {
      return;
    }
    if (topics.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cần có ít nhất một chủ đề trước khi thêm từ.'),
        ),
      );
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      barrierColor: const Color(0xFF0F172A).withValues(alpha: 0.55),
      builder: (ctx) => _VocabEditorDialog(
        topics: topics,
        editing: editing,
      ),
    );
    if (ok == true && mounted) {
      await _reload();
    }
  }

  Future<void> _delete(VocabularyModel v) async {
    final confirmed = await showAdminDeleteDialog(
      context: context,
      title: 'Xóa từ vựng?',
      message:
          'Từ sẽ bị gỡ khỏi mọi tiến độ học viên liên quan (theo quy tắc máy chủ).',
      highlight: v.word,
      confirmLabel: 'Xóa vĩnh viễn',
    );
    if (!confirmed || !mounted) {
      return;
    }
    try {
      await context.read<VocabulariesRepository>().delete(v.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã xóa từ vựng.')),
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

    return AdminScaffold(
      title: 'Quản lý từ vựng',
      showInnerHeader: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _VocabTopBar(
            searchController: _searchCtrl,
            displayName: auth.user?.username ?? 'Admin',
            onSearch: () {
              setState(() {
                _searchApplied = _searchCtrl.text.trim();
                _page = 0;
                _future = _load();
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
                  content: Text(
                    'Tìm theo từ, nghĩa hoặc phiên âm. Dùng bộ lọc chủ đề và độ khó.',
                  ),
                ),
              );
            },
          ),
          Expanded(
            child: FutureBuilder<_VocabPageData>(
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
                final vocabs = data.vocabs;
                final stats = data.stats;
                final totalLib =
                    (stats['total_library'] as num?)?.toInt() ?? vocabs.length;
                final addedToday =
                    (stats['added_today'] as num?)?.toInt() ?? 0;
                final masteryPct =
                    (stats['mastery_percent'] as num?)?.toDouble() ?? 0;

                final totalF = vocabs.length;
                final maxPage =
                    totalF <= 0 ? 0 : (totalF - 1) ~/ _pageSize;
                final safePage = _page.clamp(0, maxPage);
                final start = safePage * _pageSize;
                final pageItems = start < totalF
                    ? vocabs.sublist(
                        start,
                        start + _pageSize > totalF
                            ? totalF
                            : start + _pageSize,
                      )
                    : <VocabularyModel>[];

                return RefreshIndicator(
                  onRefresh: _reload,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _TitleAndAddRow(onAdd: () => _openEditor()),
                        const SizedBox(height: 24),
                        _FiltersAndKpiBlock(
                          topics: data.topics,
                          topicFilterId: _topicFilterId,
                          difficultyFilter: _difficultyFilter,
                          totalLibrary: totalLib,
                          addedToday: addedToday,
                          masteryPercent: masteryPct,
                          onTopicChanged: (id) {
                            setState(() {
                              _topicFilterId = id;
                              _page = 0;
                              _future = _load();
                            });
                          },
                          onDifficultyChanged: (d) {
                            setState(() {
                              _difficultyFilter = d;
                              _page = 0;
                              _future = _load();
                            });
                          },
                          onReset: _resetFilters,
                          onFilterIcon: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Bộ lọc nâng cao: dùng chủ đề + độ khó + ô tìm kiếm.',
                                ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 24),
                        _VocabTableSection(
                          rows: pageItems,
                          totalFiltered: totalF,
                          safePage: safePage,
                          maxPage: maxPage,
                          pageSize: _pageSize,
                          onEdit: (v) => _openEditor(editing: v),
                          onDelete: _delete,
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

class _VocabTopBar extends StatelessWidget {
  const _VocabTopBar({
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
                constraints: const BoxConstraints(maxWidth: 520),
                child: TextField(
                  controller: searchController,
                  onSubmitted: (_) => onSearch(),
                  decoration: InputDecoration(
                    hintText: 'Tìm nhanh từ, nghĩa hoặc phiên âm…',
                    prefixIcon: const Icon(
                      Icons.search_rounded,
                      color: Color(0xFF94A3B8),
                    ),
                    filled: true,
                    fillColor: const Color(0xFFF1F5F9).withValues(alpha: 0.85),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
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
                  'Biên tập viên',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 9,
                    color: const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 10),
            CircleAvatar(
              radius: 20,
              backgroundColor: const Color(0xFFE2DFFF),
              child: Text(
                displayName.isNotEmpty
                    ? displayName[0].toUpperCase()
                    : 'A',
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w800,
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

class _TitleAndAddRow extends StatelessWidget {
  const _TitleAndAddRow({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final narrow = c.maxWidth < 640;
        final row = Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'QUẢN LÝ',
                        style: GoogleFonts.robotoMono(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF94A3B8),
                          letterSpacing: 0.6,
                        ),
                      ),
                      const Icon(
                        Icons.chevron_right_rounded,
                        size: 14,
                        color: Color(0xFF94A3B8),
                      ),
                      Text(
                        'TỪ VỰNG',
                        style: GoogleFonts.robotoMono(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primaryContainer,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Kho từ vựng',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: AppColors.onSurface,
                      height: 1.1,
                    ),
                  ),
                ],
              ),
            ),
            if (!narrow) const SizedBox(width: 16),
            FilledButton.icon(
              onPressed: onAdd,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primaryContainer,
                foregroundColor: AppColors.onPrimary,
                padding: const EdgeInsets.symmetric(
                  horizontal: 22,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                elevation: 3,
                shadowColor: AppColors.primary.withValues(alpha: 0.25),
              ),
              icon: const Icon(Icons.add_rounded, size: 20),
              label: Text(
                'Thêm từ mới',
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        );
        if (narrow) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              row,
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: onAdd,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primaryContainer,
                  foregroundColor: AppColors.onPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Thêm từ mới'),
              ),
            ],
          );
        }
        return row;
      },
    );
  }
}

class _FiltersAndKpiBlock extends StatelessWidget {
  const _FiltersAndKpiBlock({
    required this.topics,
    required this.topicFilterId,
    required this.difficultyFilter,
    required this.totalLibrary,
    required this.addedToday,
    required this.masteryPercent,
    required this.onTopicChanged,
    required this.onDifficultyChanged,
    required this.onReset,
    required this.onFilterIcon,
  });

  final List<TopicModel> topics;
  final int? topicFilterId;
  final String? difficultyFilter;
  final int totalLibrary;
  final int addedToday;
  final double masteryPercent;
  final void Function(int?) onTopicChanged;
  final void Function(String?) onDifficultyChanged;
  final VoidCallback onReset;
  final VoidCallback onFilterIcon;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final wide = c.maxWidth >= 900;
        if (wide) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 3,
                child: _FilterCard(
                  topics: topics,
                  topicFilterId: topicFilterId,
                  difficultyFilter: difficultyFilter,
                  onTopicChanged: onTopicChanged,
                  onDifficultyChanged: onDifficultyChanged,
                  onReset: onReset,
                  onFilterIcon: onFilterIcon,
                ),
              ),
              const SizedBox(width: 24),
              Expanded(
                flex: 1,
                child: _TotalLibraryKpi(
                  total: totalLibrary,
                  addedToday: addedToday,
                  masteryPercent: masteryPercent,
                ),
              ),
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _FilterCard(
              topics: topics,
              topicFilterId: topicFilterId,
              difficultyFilter: difficultyFilter,
              onTopicChanged: onTopicChanged,
              onDifficultyChanged: onDifficultyChanged,
              onReset: onReset,
              onFilterIcon: onFilterIcon,
            ),
            const SizedBox(height: 16),
            _TotalLibraryKpi(
              total: totalLibrary,
              addedToday: addedToday,
              masteryPercent: masteryPercent,
            ),
          ],
        );
      },
    );
  }
}

class _FilterCard extends StatelessWidget {
  const _FilterCard({
    required this.topics,
    required this.topicFilterId,
    required this.difficultyFilter,
    required this.onTopicChanged,
    required this.onDifficultyChanged,
    required this.onReset,
    required this.onFilterIcon,
  });

  final List<TopicModel> topics;
  final int? topicFilterId;
  final String? difficultyFilter;
  final void Function(int?) onTopicChanged;
  final void Function(String?) onDifficultyChanged;
  final VoidCallback onReset;
  final VoidCallback onFilterIcon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.7)),
      ),
      child: Wrap(
        spacing: 20,
        runSpacing: 16,
        crossAxisAlignment: WrapCrossAlignment.end,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'LỌC THEO CHỦ ĐỀ',
                style: GoogleFonts.robotoMono(
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF64748B),
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 6),
              SizedBox(
                width: 220,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: DropdownButton<int?>(
                    value: topicFilterId,
                    isExpanded: true,
                    underline: const SizedBox.shrink(),
                    items: [
                      const DropdownMenuItem<int?>(
                        value: null,
                        child: Text('Tất cả chủ đề'),
                      ),
                      ...topics.map(
                        (t) => DropdownMenuItem<int?>(
                          value: t.id,
                          child: Text(
                            t.name,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
                    onChanged: onTopicChanged,
                  ),
                ),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'ĐỘ KHÓ (CEFR)',
                style: GoogleFonts.robotoMono(
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF64748B),
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _DiffChip(
                    label: 'B1',
                    selected: difficultyFilter == 'B1',
                    onTap: () => onDifficultyChanged(
                      difficultyFilter == 'B1' ? null : 'B1',
                    ),
                  ),
                  const SizedBox(width: 8),
                  _DiffChip(
                    label: 'B2',
                    selected: difficultyFilter == 'B2',
                    onTap: () => onDifficultyChanged(
                      difficultyFilter == 'B2' ? null : 'B2',
                    ),
                  ),
                  const SizedBox(width: 8),
                  _DiffChip(
                    label: 'C1',
                    selected: difficultyFilter == 'C1',
                    onTap: () => onDifficultyChanged(
                      difficultyFilter == 'C1' ? null : 'C1',
                    ),
                  ),
                ],
              ),
            ],
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextButton(
                onPressed: onReset,
                child: Text(
                  'Đặt lại bộ lọc',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF64748B),
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Gợi ý lọc',
                onPressed: onFilterIcon,
                icon: const Icon(Icons.filter_list_rounded),
                color: const Color(0xFF64748B),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DiffChip extends StatelessWidget {
  const _DiffChip({
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
          ? AppColors.primaryContainer
          : Colors.white,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected
                  ? AppColors.primaryContainer
                  : const Color(0xFFE2E8F0),
            ),
          ),
          child: Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: selected ? Colors.white : const Color(0xFF475569),
            ),
          ),
        ),
      ),
    );
  }
}

class _TotalLibraryKpi extends StatelessWidget {
  const _TotalLibraryKpi({
    required this.total,
    required this.addedToday,
    required this.masteryPercent,
  });

  final int total;
  final int addedToday;
  final double masteryPercent;

  @override
  Widget build(BuildContext context) {
    final fill = (masteryPercent / 100).clamp(0.0, 1.0);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF4F46E5), Color(0xFF3525CD)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.22),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'TỔNG KHO TỪ',
            style: GoogleFonts.robotoMono(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              color: Colors.white.withValues(alpha: 0.85),
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                _fmtIntVi(total),
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                addedToday > 0 ? '+$addedToday hôm nay' : '+0 hôm nay',
                style: GoogleFonts.robotoMono(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.secondaryFixed,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: fill,
              minHeight: 6,
              backgroundColor: Colors.white.withValues(alpha: 0.2),
              valueColor: const AlwaysStoppedAnimation<Color>(
                AppColors.secondaryFixed,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tiến độ thuần thục toàn hệ: ${masteryPercent.toStringAsFixed(0)}%',
            style: GoogleFonts.inter(
              fontSize: 10,
              color: Colors.white.withValues(alpha: 0.75),
            ),
          ),
        ],
      ),
    );
  }
}

class _VocabTableSection extends StatelessWidget {
  const _VocabTableSection({
    required this.rows,
    required this.totalFiltered,
    required this.safePage,
    required this.maxPage,
    required this.pageSize,
    required this.onEdit,
    required this.onDelete,
    required this.onPrev,
    required this.onNext,
  });

  final List<VocabularyModel> rows;
  final int totalFiltered;
  final int safePage;
  final int maxPage;
  final int pageSize;
  final void Function(VocabularyModel) onEdit;
  final void Function(VocabularyModel) onDelete;
  final VoidCallback? onPrev;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    final start = totalFiltered == 0 ? 0 : safePage * pageSize + 1;
    final end = (safePage * pageSize + rows.length).clamp(0, totalFiltered);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFF1F5F9)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 920),
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(
                  const Color(0xFFF8FAFC),
                ),
                columns: [
                  DataColumn(
                    label: Text(
                      'TỪ / PHIÊN ÂM',
                      style: GoogleFonts.robotoMono(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF94A3B8),
                        letterSpacing: 0.6,
                      ),
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      'NGHĨA & VÍ DỤ',
                      style: GoogleFonts.robotoMono(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF94A3B8),
                        letterSpacing: 0.6,
                      ),
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      'CHỦ ĐỀ',
                      style: GoogleFonts.robotoMono(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF94A3B8),
                        letterSpacing: 0.6,
                      ),
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      'ĐỘ THÀNH THẠO',
                      style: GoogleFonts.robotoMono(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF94A3B8),
                        letterSpacing: 0.6,
                      ),
                    ),
                  ),
                  DataColumn(
                    label: Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        'THAO TÁC',
                        style: GoogleFonts.robotoMono(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF94A3B8),
                          letterSpacing: 0.6,
                        ),
                      ),
                    ),
                  ),
                ],
                rows: rows.map((v) {
                  return DataRow(
                    cells: [
                      DataCell(
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              v.word,
                              style: GoogleFonts.plusJakartaSans(
                                fontWeight: FontWeight.w800,
                                fontSize: 15,
                                color: const Color(0xFF4338CA),
                              ),
                            ),
                            if (v.pronunciation != null &&
                                v.pronunciation!.isNotEmpty)
                              Text(
                                v.pronunciation!,
                                style: GoogleFonts.robotoMono(
                                  fontSize: 10,
                                  fontStyle: FontStyle.italic,
                                  color: const Color(0xFF94A3B8),
                                ),
                              ),
                          ],
                        ),
                      ),
                      DataCell(
                        SizedBox(
                          width: 260,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                v.meaning,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  color: AppColors.onSurfaceVariant,
                                ),
                              ),
                              if (v.example != null &&
                                  v.example!.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(
                                  '"${v.example}"',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    fontStyle: FontStyle.italic,
                                    color: const Color(0xFF94A3B8),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      DataCell(_TopicPill(name: v.topicName ?? '—')),
                      DataCell(_MasteryCell(label: v.masteryLabel)),
                      DataCell(
                        Align(
                          alignment: Alignment.centerRight,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                tooltip: 'Sửa',
                                onPressed: () => onEdit(v),
                                icon: const Icon(Icons.edit_outlined, size: 20),
                                color: const Color(0xFF94A3B8),
                              ),
                              IconButton(
                                tooltip: 'Xóa',
                                onPressed: () => onDelete(v),
                                icon: const Icon(Icons.delete_outline, size: 20),
                                color: AppColors.error,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: const BoxDecoration(
              border: Border(
                top: BorderSide(color: Color(0xFFF1F5F9)),
              ),
              color: Color(0xFFFAFBFC),
            ),
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 12,
              runSpacing: 8,
              children: [
                Text(
                  totalFiltered == 0
                      ? 'Không có mục nào'
                      : 'Hiển thị $start–$end trong $totalFiltered mục',
                  style: GoogleFonts.robotoMono(
                    fontSize: 11,
                    color: const Color(0xFF64748B),
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _PageNavButton(
                      label: 'Trước',
                      enabled: onPrev != null,
                      onTap: onPrev,
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      child: Text(
                        maxPage < 0
                            ? '0 / 0'
                            : 'Trang ${safePage + 1} / ${maxPage + 1}',
                        style: GoogleFonts.robotoMono(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF475569),
                        ),
                      ),
                    ),
                    _PageNavButton(
                      label: 'Sau',
                      enabled: onNext != null,
                      onTap: onNext,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TopicPill extends StatelessWidget {
  const _TopicPill({required this.name});

  final String name;

  static const _palette = <Color>[
    Color(0xFFEEF2FF),
    Color(0xFFFFF7ED),
    Color(0xFFE0F2FE),
    Color(0xFFDCFCE7),
    Color(0xFFFCE7F3),
  ];

  static const _fg = <Color>[
    Color(0xFF4338CA),
    Color(0xFFC2410C),
    Color(0xFF0369A1),
    Color(0xFF15803D),
    Color(0xFFBE185D),
  ];

  @override
  Widget build(BuildContext context) {
    var h = 0;
    for (final c in name.codeUnits) {
      h = (h + c) % _palette.length;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: _palette[h],
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: _fg[h].withValues(alpha: 0.15)),
      ),
      child: Text(
        name.toUpperCase(),
        style: GoogleFonts.robotoMono(
          fontSize: 9,
          fontWeight: FontWeight.w800,
          color: _fg[h],
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

class _MasteryCell extends StatelessWidget {
  const _MasteryCell({required this.label});

  final String? label;

  int get _dots {
    switch (label) {
      case 'Low':
        return 1;
      case 'Med':
        return 2;
      case 'High':
        return 3;
      case 'Expert':
        return 4;
      default:
        return 2;
    }
  }

  String get _vi {
    switch (label) {
      case 'Low':
        return 'Thấp';
      case 'Med':
        return 'Trung bình';
      case 'High':
        return 'Cao';
      case 'Expert':
        return 'Xuất sắc';
      default:
        return '—';
    }
  }

  @override
  Widget build(BuildContext context) {
    final n = _dots;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(4, (i) {
            final on = i < n;
            return Container(
              margin: EdgeInsets.only(left: i == 0 ? 0 : 3),
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: on ? AppColors.secondary : const Color(0xFFE2E8F0),
              ),
            );
          }),
        ),
        const SizedBox(width: 8),
        Text(
          _vi,
          style: GoogleFonts.robotoMono(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF64748B),
          ),
        ),
      ],
    );
  }
}

class _PageNavButton extends StatelessWidget {
  const _PageNavButton({
    required this.label,
    required this.enabled,
    required this.onTap,
  });

  final String label;
  final bool enabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: enabled ? Colors.white : const Color(0xFFF8FAFC),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: enabled
                  ? const Color(0xFFE2E8F0)
                  : const Color(0xFFF1F5F9),
            ),
          ),
          child: Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: enabled
                  ? const Color(0xFF334155)
                  : const Color(0xFFCBD5E1),
            ),
          ),
        ),
      ),
    );
  }
}

class _VocabEditorDialog extends StatefulWidget {
  const _VocabEditorDialog({
    required this.topics,
    this.editing,
  });

  final List<TopicModel> topics;
  final VocabularyModel? editing;

  @override
  State<_VocabEditorDialog> createState() => _VocabEditorDialogState();
}

class _VocabEditorDialogState extends State<_VocabEditorDialog> {
  late final TextEditingController _word;
  late final TextEditingController _pron;
  late final TextEditingController _mean;
  late final TextEditingController _ex;
  late int? _topicId;
  late String _difficulty;

  @override
  void initState() {
    super.initState();
    final e = widget.editing;
    _word = TextEditingController(text: e?.word ?? '');
    _pron = TextEditingController(text: e?.pronunciation ?? '');
    _mean = TextEditingController(text: e?.meaning ?? '');
    _ex = TextEditingController(text: e?.example ?? '');
    _topicId = e?.topicId;
    if (_topicId == null && widget.topics.isNotEmpty) {
      _topicId = widget.topics.first.id;
    }
    _difficulty = e?.difficulty ?? 'B2';
  }

  @override
  void dispose() {
    _word.dispose();
    _pron.dispose();
    _mean.dispose();
    _ex.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final tid = _topicId;
    if (tid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Chọn chủ đề.')),
      );
      return;
    }
    final w = _word.text.trim();
    final m = _mean.text.trim();
    if (w.isEmpty || m.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Điền từ và nghĩa chính.')),
      );
      return;
    }
    final repo = context.read<VocabulariesRepository>();
    try {
      if (widget.editing == null) {
        await repo.create(
          word: w,
          meaning: m,
          topicId: tid,
          pronunciation: _pron.text.trim().isEmpty ? null : _pron.text.trim(),
          example: _ex.text.trim().isEmpty ? null : _ex.text.trim(),
          difficulty: _difficulty,
        );
      } else {
        await repo.update(
          widget.editing!.id,
          word: w,
          meaning: m,
          topicId: tid,
          pronunciation: _pron.text.trim().isEmpty ? null : _pron.text.trim(),
          example: _ex.text.trim().isEmpty ? null : _ex.text.trim(),
          difficulty: _difficulty,
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
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.editing != null;
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        isEdit ? 'Sửa mục từ vựng' : 'Mục từ vựng mới',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context, false),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                LayoutBuilder(
                  builder: (context, c) {
                    final twoCol = c.maxWidth > 520;
                    final wordField = TextField(
                      controller: _word,
                      decoration: InputDecoration(
                        labelText: 'Từ',
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    );
                    final pronField = TextField(
                      controller: _pron,
                      decoration: InputDecoration(
                        labelText: 'Phiên âm',
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    );
                    if (!twoCol) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          wordField,
                          const SizedBox(height: 12),
                          pronField,
                        ],
                      );
                    }
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: wordField),
                        const SizedBox(width: 16),
                        Expanded(child: pronField),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _mean,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: 'Nghĩa chính',
                    alignLabelWithHint: true,
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _ex,
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: 'Ví dụ (tuỳ chọn)',
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                LayoutBuilder(
                  builder: (context, c) {
                    final twoCol = c.maxWidth > 520;
                    final topicDd = Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Chủ đề (cụm)',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: DropdownButton<int>(
                            value: _topicId,
                            isExpanded: true,
                            underline: const SizedBox.shrink(),
                            items: widget.topics
                                .map(
                                  (t) => DropdownMenuItem(
                                    value: t.id,
                                    child: Text(
                                      t.name,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: (v) =>
                                setState(() => _topicId = v),
                          ),
                        ),
                      ],
                    );
                    final diffRow = Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'ĐỘ KHÓ',
                          style: GoogleFonts.robotoMono(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF64748B),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: ['B1', 'B2', 'C1'].map((d) {
                            final sel = _difficulty == d;
                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: _DiffChip(
                                label: d,
                                selected: sel,
                                onTap: () => setState(() => _difficulty = d),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    );
                    if (!twoCol) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          topicDd,
                          const SizedBox(height: 16),
                          diffRow,
                        ],
                      );
                    }
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: topicDd),
                        const SizedBox(width: 16),
                        Expanded(child: diffRow),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Huỷ'),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: _save,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primaryContainer,
                        foregroundColor: AppColors.onPrimary,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 28,
                          vertical: 14,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: Text(
                        isEdit ? 'Cập nhật' : 'Lưu mục',
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
        ),
      ),
    );
  }
}
