import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_routes.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../../../data/models/vocabulary_model.dart';
import '../../../../data/repositories/user_vocabulary_repository.dart';
import '../../../../data/repositories/vocabularies_repository.dart';
import '../../../auth/controllers/auth_provider.dart';
import '../../widgets/fluid_learner_page_footer.dart';
import '../../widgets/fluid_learner_top_nav.dart';

/// Danh sách từ theo chủ đề — theo `vocabulary_list/code.html`.
/// `arguments`: `{ topicId: int, topicName?: String }`
class VocabularyListScreen extends StatefulWidget {
  const VocabularyListScreen({super.key});

  @override
  State<VocabularyListScreen> createState() => _VocabularyListScreenState();
}

class _VocabListLoad {
  const _VocabListLoad({
    required this.words,
    required this.statusByVocabId,
  });

  final List<VocabularyModel> words;
  final Map<int, String> statusByVocabId;
}

class _VocabularyListScreenState extends State<VocabularyListScreen> {
  Future<_VocabListLoad>? _future;
  int? _topicId;
  String _title = 'Từ vựng';
  final _search = TextEditingController();
  String _query = '';
  int _page = 0;
  static const _pageSize = 8;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map) {
      final tid = args['topicId'];
      if (tid is num) {
        _topicId = tid.toInt();
      }
      final name = args['topicName'];
      if (name is String && name.isNotEmpty) {
        _title = name;
      }
    }
    if (_topicId != null) {
      _future ??= _loadData();
    }
  }

  Future<_VocabListLoad> _loadData() async {
    final tid = _topicId!;
    final vocabRepo = context.read<VocabulariesRepository>();
    final uvRepo = context.read<UserVocabularyRepository>();
    final words = await vocabRepo.fetchByTopic(tid);
    final statusByVocabId = <int, String>{};
    try {
      final mine = await uvRepo.fetchMine();
      for (final row in mine) {
        final vid = (row['vocab_id'] as num?)?.toInt();
        if (vid == null) {
          continue;
        }
        statusByVocabId[vid] = '${row['status'] ?? 'new'}';
      }
    } catch (_) {}
    return _VocabListLoad(words: words, statusByVocabId: statusByVocabId);
  }

  Future<void> _refresh() async {
    if (_topicId == null) {
      return;
    }
    setState(() {
      _future = _loadData();
    });
    await _future;
  }

  String _uiStatus(VocabularyModel v, Map<int, String> m) {
    final s = m[v.id];
    switch (s) {
      case 'mastered':
        return 'learned';
      case 'learning':
      case 'review':
        return 'learning';
      default:
        return 'new';
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    if (_topicId == null) {
      return Scaffold(
        backgroundColor: AppColors.surface,
        appBar: const _VocabularyAppBarSimple(title: 'Từ vựng'),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Chọn chủ đề từ tab Chủ đề để xem từ vựng.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: FluidLearnerTopNav(
        currentIndex: 1,
        leading: IconButton(
          tooltip: 'Quay lại',
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_rounded),
          color: const Color(0xFF64748B),
        ),
        extraActions: [
          IconButton(
            tooltip: 'Làm mới',
            onPressed: _refresh,
            icon: const Icon(Icons.refresh_rounded),
            color: const Color(0xFF64748B),
          ),
          IconButton(
            tooltip: 'Cài đặt',
            onPressed: () {
              showAppSnackBar(
                context,
                'Tài khoản nằm trong icon người (góc phải).',
                kind: AppSnackKind.info,
              );
            },
            icon: const Icon(Icons.settings_outlined),
            color: const Color(0xFF64748B),
          ),
          if (auth.user?.isAdmin == true)
            IconButton(
              tooltip: 'Admin',
              icon: const Icon(Icons.admin_panel_settings_outlined),
              onPressed: () =>
                  Navigator.pushNamed(context, AppRoutes.adminDashboard),
            ),
        ],
      ),
      body: FutureBuilder<_VocabListLoad>(
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
                child: Text(msg, textAlign: TextAlign.center),
              ),
            );
          }
          final data = snap.data!;
          final all = data.words;
          final st = data.statusByVocabId;
          if (all.isEmpty) {
            return const Center(child: Text('Chưa có từ trong chủ đề này.'));
          }

          final filtered = _query.isEmpty
              ? all
              : all
                  .where((w) =>
                      w.word.toLowerCase().contains(_query.toLowerCase()) ||
                      w.meaning.toLowerCase().contains(_query.toLowerCase()))
                  .toList();
          final learned = all
              .where((e) => _uiStatus(e, st) != 'new')
              .length;
          String statusFor(VocabularyModel v) => _uiStatus(v, st);

          if (filtered.isEmpty) {
            return RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                children: [
                  _TopicHeroBanner(
                    title: _title,
                    total: all.length,
                    learned: learned,
                  ),
                  const SizedBox(height: 20),
                  _SearchFilterRow(
                    searchController: _search,
                    topicTitle: _title,
                    showAddButton: auth.user?.isAdmin == true,
                    onQueryChanged: (q) {
                      setState(() {
                        _query = q;
                        _page = 0;
                      });
                    },
                    onFilter: () {
                      showAppSnackBar(
                        context,
                        'Lọc theo trạng thái sẽ bổ sung sau.',
                        kind: AppSnackKind.info,
                      );
                    },
                    onAddWord: () {
                      Navigator.pushNamed(context, AppRoutes.adminVocabulary);
                    },
                  ),
                  const SizedBox(height: 32),
                  const Center(child: Text('Không có từ khớp tìm kiếm.')),
                ],
              ),
            );
          }

          final start = _page * _pageSize;
          final end = (start + _pageSize) > filtered.length
              ? filtered.length
              : start + _pageSize;
          final pageItems = start < filtered.length
              ? filtered.sublist(start, end)
              : <VocabularyModel>[];
          final hasMore = end < filtered.length;

          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
              children: [
                _TopicHeroBanner(
                  title: _title,
                  total: all.length,
                  learned: learned,
                ),
                const SizedBox(height: 20),
                _SearchFilterRow(
                  searchController: _search,
                  topicTitle: _title,
                  showAddButton: auth.user?.isAdmin == true,
                  onQueryChanged: (q) {
                    setState(() {
                      _query = q;
                      _page = 0;
                    });
                  },
                  onFilter: () {
                    showAppSnackBar(
                      context,
                      'Lọc theo trạng thái sẽ bổ sung sau.',
                      kind: AppSnackKind.info,
                    );
                  },
                  onAddWord: () {
                    Navigator.pushNamed(context, AppRoutes.adminVocabulary);
                  },
                ),
                const SizedBox(height: 20),
                _VocabularyTable(
                  words: pageItems,
                  allWords: all,
                  statusFor: statusFor,
                  onRowTap: (v, indexInAll) async {
                    await Navigator.pushNamed(
                      context,
                      AppRoutes.learnerFlashcards,
                      arguments: {
                        'topicId': _topicId,
                        'topicName': _title,
                        'startIndex': indexInAll,
                      },
                    );
                    if (context.mounted) {
                      await _refresh();
                    }
                  },
                ),
                if (hasMore) ...[
                  const SizedBox(height: 28),
                  Center(
                    child: _NextPageButton(
                      onPressed: () => setState(() => _page++),
                    ),
                  ),
                ],
                SizedBox(height: 16 + MediaQuery.paddingOf(context).bottom),
                const FluidLearnerPageFooter(),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _VocabularyAppBarSimple extends StatelessWidget
    implements PreferredSizeWidget {
  const _VocabularyAppBarSimple({required this.title});

  final String title;

  @override
  Size get preferredSize => const Size.fromHeight(56);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: Text(title),
      backgroundColor: Colors.white.withValues(alpha: 0.88),
    );
  }
}

class _TopicHeroBanner extends StatelessWidget {
  const _TopicHeroBanner({
    required this.title,
    required this.total,
    required this.learned,
  });

  final String title;
  final int total;
  final int learned;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.primaryContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      clipBehavior: Clip.antiAlias,
      child: LayoutBuilder(
        builder: (context, c) {
          final row = c.maxWidth >= 720;
          final textBlock = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    'Chủ đề',
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 13,
                      color: const Color(0xFFE2DFFF),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 18,
                    color: const Color(0xFFE2DFFF).withValues(alpha: 0.8),
                  ),
                  Text(
                    'Từ vựng',
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 13,
                      color: const Color(0xFFE2DFFF),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: row ? 40 : 30,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  height: 1.05,
                  letterSpacing: -0.8,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Làm chủ bộ từ vựng thiết yếu cho mục tiêu của bạn — từ ôn tập đến flashcard LexiFlow.',
                style: GoogleFonts.inter(
                  fontSize: 15,
                  height: 1.5,
                  color: Colors.white.withValues(alpha: 0.9),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$total',
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        'TỔNG TỪ',
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                          color: Colors.white.withValues(alpha: 0.65),
                        ),
                      ),
                    ],
                  ),
                  Container(
                    width: 1,
                    height: 36,
                    margin: const EdgeInsets.symmetric(horizontal: 20),
                    color: Colors.white.withValues(alpha: 0.22),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$learned',
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          color: AppColors.secondaryFixed,
                        ),
                      ),
                      Text(
                        'ĐÃ ÔN TẬP',
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                          color: Colors.white.withValues(alpha: 0.65),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          );

          final art = Transform.rotate(
            angle: 0.05,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: row ? 200 : double.infinity,
                height: row ? 200 : 160,
                color: Colors.white.withValues(alpha: 0.12),
                alignment: Alignment.center,
                child: Icon(
                  Icons.map_rounded,
                  size: 72,
                  color: Colors.white.withValues(alpha: 0.35),
                ),
              ),
            ),
          );

          if (row) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(child: textBlock),
                const SizedBox(width: 20),
                art,
              ],
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              textBlock,
              const SizedBox(height: 20),
              art,
            ],
          );
        },
      ),
    );
  }
}

class _SearchFilterRow extends StatelessWidget {
  const _SearchFilterRow({
    required this.searchController,
    required this.topicTitle,
    required this.showAddButton,
    required this.onQueryChanged,
    required this.onFilter,
    required this.onAddWord,
  });

  final TextEditingController searchController;
  final String topicTitle;
  final bool showAddButton;
  final void Function(String) onQueryChanged;
  final VoidCallback onFilter;
  final VoidCallback onAddWord;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final row = c.maxWidth >= 720;
        final field = TextField(
          controller: searchController,
          onChanged: onQueryChanged,
          decoration: InputDecoration(
            hintText: 'Tìm từ vựng $topicTitle…',
            prefixIcon: const Icon(Icons.search_rounded),
            filled: true,
            fillColor: AppColors.surfaceContainerLow,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
          ),
        );
        final filterBtn = OutlinedButton.icon(
          onPressed: onFilter,
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            backgroundColor: AppColors.surfaceContainerHighest,
            foregroundColor: AppColors.onSurface,
            side: BorderSide.none,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          icon: const Icon(Icons.filter_list_rounded, size: 20),
          label: Text(
            'Lọc',
            style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w800),
          ),
        );
        final addBtn = FilledButton.icon(
          onPressed: onAddWord,
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          icon: const Icon(Icons.add_rounded, size: 22),
          label: Text(
            'Thêm từ',
            style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w800),
          ),
        );
        if (row) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: field),
              const SizedBox(width: 12),
              filterBtn,
              if (showAddButton) ...[
                const SizedBox(width: 10),
                addBtn,
              ],
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            field,
            const SizedBox(height: 12),
            showAddButton
                ? Row(
                    children: [
                      Expanded(child: filterBtn),
                      const SizedBox(width: 10),
                      Expanded(child: addBtn),
                    ],
                  )
                : filterBtn,
          ],
        );
      },
    );
  }
}

class _VocabularyTable extends StatelessWidget {
  const _VocabularyTable({
    required this.words,
    required this.allWords,
    required this.statusFor,
    required this.onRowTap,
  });

  final List<VocabularyModel> words;
  final List<VocabularyModel> allWords;
  final String Function(VocabularyModel) statusFor;
  final void Function(VocabularyModel v, int indexInAll) onRowTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: LayoutBuilder(
        builder: (context, c) {
          final wide = c.maxWidth >= 800;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (wide)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: AppColors.outlineVariant.withValues(alpha: 0.35),
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 4,
                        child: Text(
                          'TỪ & PHIÊN ÂM',
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.2,
                            color: const Color(0xFF777587),
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 5,
                        child: Text(
                          'NGHĨA & VÍ DỤ',
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.2,
                            color: const Color(0xFF777587),
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 140,
                        child: Text(
                          'TRẠNG THÁI',
                          textAlign: TextAlign.right,
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.2,
                            color: const Color(0xFF777587),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              for (var i = 0; i < words.length; i++) ...[
                if (i > 0)
                  Divider(
                    height: 1,
                    color: AppColors.outlineVariant.withValues(alpha: 0.25),
                  ),
                _WordTableRow(
                  v: words[i],
                  status: statusFor(words[i]),
                  wide: wide,
                  onTap: () {
                    final idx =
                        allWords.indexWhere((e) => e.id == words[i].id);
                    onRowTap(words[i], idx >= 0 ? idx : 0);
                  },
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _WordTableRow extends StatelessWidget {
  const _WordTableRow({
    required this.v,
    required this.status,
    required this.wide,
    required this.onTap,
  });

  final VocabularyModel v;
  final String status;
  final bool wide;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final pill = _statusPill(status);
    final wordCol = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Material(
          color: AppColors.primary.withValues(alpha: 0.06),
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: () {
              showAppSnackBar(
                context,
                'Phát âm (TTS) sẽ bổ sung sau.',
                kind: AppSnackKind.info,
              );
            },
            child: const Padding(
              padding: EdgeInsets.all(10),
              child: Icon(
                Icons.volume_up_rounded,
                size: 20,
                color: AppColors.primary,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                v.word,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.onSurface,
                ),
              ),
              if (v.pronunciation != null && v.pronunciation!.isNotEmpty)
                Text(
                  v.pronunciation!,
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                    color: const Color(0xFF777587),
                  ),
                ),
            ],
          ),
        ),
      ],
    );

    final meaningCol = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          v.meaning,
          style: GoogleFonts.inter(
            fontSize: 14,
            height: 1.45,
            color: AppColors.onSurfaceVariant,
          ),
        ),
        if (v.example != null && v.example!.trim().isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            '"${v.example}"',
            style: GoogleFonts.inter(
              fontSize: 13,
              height: 1.45,
              fontStyle: FontStyle.italic,
              color: AppColors.primaryContainer,
            ),
          ),
        ],
      ],
    );

    final statusCol = Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        if (wide) ...[
          pill,
          const SizedBox(width: 12),
        ],
        _StatusCheckIcon(status: status),
      ],
    );

    return Material(
      color: AppColors.surfaceContainerLowest,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          child: wide
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 4, child: wordCol),
                    const SizedBox(width: 12),
                    Expanded(flex: 5, child: meaningCol),
                    const SizedBox(width: 12),
                    SizedBox(width: 140, child: statusCol),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    wordCol,
                    const SizedBox(height: 14),
                    meaningCol,
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        pill,
                        const Spacer(),
                        _StatusCheckIcon(status: status),
                      ],
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _statusPill(String status) {
    switch (status) {
      case 'learned':
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: AppColors.secondaryFixed,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            'ĐÃ HỌC',
            style: GoogleFonts.spaceGrotesk(
              fontSize: 9,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.6,
              color: const Color(0xFF007432),
            ),
          ),
        );
      case 'learning':
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: AppColors.tertiaryFixed,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            'ĐANG HỌC',
            style: GoogleFonts.spaceGrotesk(
              fontSize: 9,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.6,
              color: const Color(0xFF653E00),
            ),
          ),
        );
      default:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            'MỚI',
            style: GoogleFonts.spaceGrotesk(
              fontSize: 9,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.6,
              color: AppColors.onSurfaceVariant,
            ),
          ),
        );
    }
  }
}

class _StatusCheckIcon extends StatelessWidget {
  const _StatusCheckIcon({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final learned = status == 'learned';
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: learned ? AppColors.secondary : Colors.transparent,
        border: Border.all(
          color: learned ? AppColors.secondary : AppColors.outlineVariant,
          width: 2,
        ),
      ),
      child: Icon(
        Icons.check_circle_rounded,
        size: 20,
        color: learned ? Colors.white : AppColors.outlineVariant,
      ),
    );
  }
}

class _NextPageButton extends StatelessWidget {
  const _NextPageButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Xem trang tiếp theo',
                style: GoogleFonts.spaceGrotesk(
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                  letterSpacing: 0.4,
                ),
              ),
              const SizedBox(width: 10),
              const Icon(Icons.arrow_forward_rounded, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
