import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_routes.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/json_convert.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../../../data/models/topic_model.dart';
import '../../../../data/models/vocabulary_model.dart';
import '../../../../data/repositories/progress_repository.dart';
import '../../../../data/repositories/quiz_repository.dart';
import '../../../../data/repositories/topics_repository.dart';
import '../../../../data/repositories/user_vocabulary_repository.dart';
import '../../../../data/repositories/vocabularies_repository.dart';
import '../../../auth/controllers/auth_provider.dart';
import '../../controllers/learner_tab_index.dart';
import '../../widgets/fluid_learner_page_footer.dart';
import '../../widgets/fluid_learner_top_nav.dart';

/// Đồng bộ `backend/src/controllers/progressController.js` (LEFT JOIN — không có dòng = 0).
double _uvStatusWeight(String? s) {
  switch (s) {
    case 'mastered':
      return 1;
    case 'review':
      return 0.5;
    case 'learning':
      return 0.25;
    case 'new':
      return 0;
    default:
      return 0;
  }
}

/// Danh sách chủ đề — bố cục theo `topic_list/code.html` (Curated Pathways + lưới thẻ).
class TopicListScreen extends StatefulWidget {
  const TopicListScreen({super.key});

  @override
  State<TopicListScreen> createState() => _TopicListScreenState();
}

class _TopicListScreenState extends State<TopicListScreen> {
  Future<_TopicListData>? _future;
  LearnerTabIndex? _learnerTabs;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _learnerTabs = context.read<LearnerTabIndex>();
      _learnerTabs!.addListener(_onLearnerTabChanged);
    });
  }

  void _onLearnerTabChanged() {
    if (!mounted) {
      return;
    }
    if (_learnerTabs?.index != 1) {
      return;
    }
    setState(() => _future = _load());
  }

  @override
  void dispose() {
    _learnerTabs?.removeListener(_onLearnerTabChanged);
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _future ??= _load();
  }

  Future<void> _refresh() async {
    setState(() {
      _future = _load();
    });
    await _future;
  }

  Future<_TopicListData> _load() async {
    final topicsRepo = context.read<TopicsRepository>();
    final progressRepo = context.read<ProgressRepository>();

    final topics = await topicsRepo.fetchTopics();
    try {
      final rows = await progressRepo.fetchMyTopicProgress();
      final counts = <int, int>{};
      final topicMastered = <int, int>{};
      final vocabPct = <int, int>{};
      final bestScore = <int, int>{};
      for (final r in rows) {
        final tid = parseJsonInt(r['topic_id']);
        if (tid == null) {
          continue;
        }
        counts[tid] = parseJsonInt(r['vocab_total']) ?? 0;
        topicMastered[tid] = parseJsonInt(r['vocab_mastered']) ?? 0;
        vocabPct[tid] = parseJsonInt(r['vocab_progress_pct']) ?? 0;
        bestScore[tid] = parseJsonInt(r['quiz_best_score']) ?? 0;
      }
      return _TopicListData(
        topics: topics,
        topicWordCounts: counts,
        topicBestScore: bestScore,
        topicMasteredCount: topicMastered,
        topicVocabProgressPct: vocabPct,
      );
    } catch (_) {
      return _loadProgressFallback(topics);
    }
  }

  /// Khi GET /progress/topics lỗi — gom từ API từ vựng + quiz (cùng logic server).
  Future<_TopicListData> _loadProgressFallback(List<TopicModel> topics) async {
    final quizRepo = context.read<QuizRepository>();
    final vocabRepo = context.read<VocabulariesRepository>();
    final uvRepo = context.read<UserVocabularyRepository>();
    final counts = <int, int>{};
    final vocabTopic = <int, int>{};
    final topicMastered = <int, int>{};
    final topicVocabPct = <int, int>{};
    try {
      final all = await vocabRepo.fetchAll();
      for (final VocabularyModel v in all) {
        counts[v.topicId] = (counts[v.topicId] ?? 0) + 1;
        vocabTopic[v.id] = v.topicId;
      }
      final mine = await uvRepo.fetchMine();
      final statusByVid = <int, String>{};
      for (final row in mine) {
        final vid = parseJsonInt(row['vocab_id']);
        if (vid != null) {
          statusByVid[vid] = '${row['status']}';
        }
        if ('${row['status']}' != 'mastered') {
          continue;
        }
        if (vid == null) {
          continue;
        }
        final tid = vocabTopic[vid];
        if (tid == null) {
          continue;
        }
        topicMastered[tid] = (topicMastered[tid] ?? 0) + 1;
      }
      for (final tid in counts.keys) {
        final wc = counts[tid] ?? 0;
        if (wc <= 0) {
          continue;
        }
        var sum = 0.0;
        for (final VocabularyModel v in all) {
          if (v.topicId != tid) {
            continue;
          }
          sum += _uvStatusWeight(statusByVid[v.id]);
        }
        topicVocabPct[tid] = (sum / wc * 100).round().clamp(0, 100);
      }
    } catch (_) {}
    final bestScore = <int, int>{};
    try {
      final results = await quizRepo.fetchMyResults();
      for (final r in results) {
        final tid = parseJsonInt(r['topic_id']);
        if (tid == null) {
          continue;
        }
        final sc = parseJsonInt(r['score']) ?? 0;
        bestScore[tid] = math.max(bestScore[tid] ?? 0, sc);
      }
    } catch (_) {}
    return _TopicListData(
      topics: topics,
      topicWordCounts: counts,
      topicBestScore: bestScore,
      topicMasteredCount: topicMastered,
      topicVocabProgressPct: topicVocabPct,
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final xp = auth.user?.xp ?? 0;
    final level = auth.user?.level ?? 1;
    final streakDays = (level * 2 + (xp % 7)).clamp(1, 99);
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: FluidLearnerTopNav(
        currentIndex: 1,
        extraActions: [
          if (auth.user?.isAdmin == true)
            IconButton(
              tooltip: 'Admin',
              icon: const Icon(Icons.admin_panel_settings_outlined),
              onPressed: () =>
                  Navigator.pushNamed(context, AppRoutes.adminDashboard),
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
          IconButton(
            tooltip: 'Làm mới',
            onPressed: _refresh,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: FutureBuilder<_TopicListData>(
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
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(msg, textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: _refresh,
                      child: const Text('Thử lại'),
                    ),
                  ],
                ),
              ),
            );
          }
          final data = snap.data!;
          final list = data.topics;
          return RefreshIndicator(
            onRefresh: _refresh,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                  sliver: SliverToBoxAdapter(
                    child: _HeroBanner(streakDays: streakDays),
                  ),
                ),
                if (list.isEmpty)
                  const SliverFillRemaining(
                    child: Center(child: Text('Chưa có chủ đề.')),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                    sliver: SliverGrid(
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: MediaQuery.sizeOf(context).width >= 1024
                            ? 3
                            : MediaQuery.sizeOf(context).width >= 720
                                ? 2
                                : 1,
                        mainAxisSpacing: 18,
                        crossAxisSpacing: 18,
                        childAspectRatio: MediaQuery.sizeOf(context).width >= 1024
                            ? 1.12
                            : MediaQuery.sizeOf(context).width >= 720
                                ? 1.05
                                : 1.28,
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (context, i) {
                          if (i == list.length) {
                            return _CustomTopicPlaceholder(
                              onTap: () {
                                showAppSnackBar(
                                  context,
                                  'Tùy chỉnh chủ đề sẽ có trong bản cập nhật sau.',
                                  kind: AppSnackKind.info,
                                );
                              },
                            );
                          }
                          final t = list[i];
                          final totalWords = data.topicWordCounts[t.id] ?? 0;
                          final mastered =
                              data.topicMasteredCount[t.id] ?? 0;
                          final vocabPct = data.topicVocabProgressPct[t.id] ?? 0;
                          final quizPct =
                              (data.topicBestScore[t.id] ?? 0).clamp(0, 100);
                          final pct = totalWords > 0
                              ? math.max(vocabPct, quizPct)
                              : quizPct;

                          return _TopicGridCard(
                            topic: t,
                            progressPct: pct,
                            totalWords: totalWords,
                            mastered: mastered,
                            accent: _TopicGridCard.accentFor(i),
                            icon: _TopicGridCard.iconFor(i),
                            onVocabulary: () async {
                              await Navigator.pushNamed(
                                context,
                                AppRoutes.learnerVocabulary,
                                arguments: {
                                  'topicId': t.id,
                                  'topicName': t.name,
                                },
                              );
                              if (context.mounted) {
                                await _refresh();
                              }
                            },
                            onQuiz: () async {
                              await Navigator.pushNamed(
                                context,
                                AppRoutes.learnerQuiz,
                                arguments: {'topicId': t.id},
                              );
                              if (context.mounted) {
                                await _refresh();
                              }
                            },
                          );
                        },
                        childCount: list.length + 1,
                      ),
                    ),
                  ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.only(
                      bottom: 8 + MediaQuery.paddingOf(context).bottom,
                    ),
                    child: const FluidLearnerPageFooter(),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _TopicListData {
  _TopicListData({
    required this.topics,
    required this.topicWordCounts,
    required this.topicBestScore,
    required this.topicMasteredCount,
    required this.topicVocabProgressPct,
  });

  final List<TopicModel> topics;
  final Map<int, int> topicWordCounts;
  final Map<int, int> topicBestScore;
  /// Số từ `mastered` theo `user_vocabulary` trong chủ đề.
  final Map<int, int> topicMasteredCount;
  /// % từ vựng có trọng số (đồng bộ API).
  final Map<int, int> topicVocabProgressPct;
}

class _HeroBanner extends StatelessWidget {
  const _HeroBanner({required this.streakDays});

  final int streakDays;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final showArt = c.maxWidth >= 980;
        return Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppColors.primaryContainer,
            borderRadius: BorderRadius.circular(20),
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              if (showArt)
                Positioned(
                  right: 0,
                  top: 0,
                  bottom: 0,
                  child: Opacity(
                    opacity: 0.18,
                    child: SizedBox(
                      width: c.maxWidth * 0.36,
                      child: FittedBox(
                        fit: BoxFit.cover,
                        alignment: Alignment.centerLeft,
                        child: Icon(
                          Icons.auto_stories_rounded,
                          size: 520,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'LỘ TRÌNH BIÊN SOẠN',
                          style: GoogleFonts.spaceGrotesk(
                            color: Colors.white.withValues(alpha: 0.78),
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.4,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Học tiếng Anh theo ngữ cảnh',
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.white,
                            fontSize: 34,
                            fontWeight: FontWeight.w900,
                            height: 1.05,
                            letterSpacing: -0.8,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Chọn chủ đề phù hợp với mục tiêu. Lộ trình biên soạn giúp bạn học từ vựng tần suất cao và áp dụng đúng ngữ cảnh.',
                          style: GoogleFonts.inter(
                            color: Colors.white.withValues(alpha: 0.82),
                            fontSize: 14,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 18),
                        FilledButton.tonal(
                          onPressed: () {},
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: AppColors.primary,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            'Chuỗi ngày: $streakDays ngày',
                            style: GoogleFonts.plusJakartaSans(
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _TopicGridCard extends StatelessWidget {
  const _TopicGridCard({
    required this.topic,
    required this.progressPct,
    required this.totalWords,
    required this.mastered,
    required this.accent,
    required this.icon,
    required this.onVocabulary,
    required this.onQuiz,
  });

  final TopicModel topic;
  final int progressPct;
  final int totalWords;
  final int mastered;
  final Color accent;
  final IconData icon;
  final VoidCallback onVocabulary;
  final VoidCallback onQuiz;

  static Color accentFor(int i) {
    const c = [
      Color(0xFFE0E7FF),
      Color(0xFFD1FAE5),
      Color(0xFFEDE9FE),
      Color(0xFFE0F2FE),
      Color(0xFFFCE7F3),
    ];
    return c[i % c.length];
  }

  static IconData iconFor(int i) {
    const icons = [
      Icons.business_center_rounded,
      Icons.flight_takeoff_rounded,
      Icons.biotech_rounded,
      Icons.memory_rounded,
      Icons.local_hospital_rounded,
    ];
    return icons[i % icons.length];
  }

  bool get _mastered => progressPct >= 100;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceContainerLowest,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: accent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: AppColors.primaryContainer),
                  ),
                  const Spacer(),
                  if (_mastered)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.secondary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.check_circle_rounded,
                            size: 14,
                            color: AppColors.secondary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'MASTERED',
                            style: GoogleFonts.spaceGrotesk(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              color: AppColors.secondary,
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    Text(
                      '$progressPct%',
                      style: GoogleFonts.robotoMono(
                        fontWeight: FontWeight.w700,
                        color: AppColors.primaryContainer,
                      ),
                    ),
                ],
              ),
              if (!_mastered)
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    'TIẾN ĐỘ',
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 8,
                      fontWeight: FontWeight.w700,
                      color: AppColors.onSurfaceVariant,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              const SizedBox(height: 10),
              Text(
                topic.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 6),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      flex: 2,
                      child: Text(
                        topic.description ??
                            'Từ vựng theo chủ đề, có quiz LexiFlow.',
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.onSurfaceVariant,
                              height: 1.35,
                            ),
                      ),
                    ),
                    Expanded(
                      flex: 3,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          FilledButton.tonal(
                            onPressed: onVocabulary,
                            style: FilledButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 14,
                              ),
                              minimumSize: const Size(double.infinity, 48),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Text(
                              'Từ vựng',
                              style: GoogleFonts.plusJakartaSans(
                                fontWeight: FontWeight.w800,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          OutlinedButton(
                            onPressed: onQuiz,
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 14,
                              ),
                              minimumSize: const Size(double.infinity, 48),
                              side: BorderSide(
                                color: AppColors.primaryContainer.withValues(
                                  alpha: 0.45,
                                ),
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Text(
                              'Quiz',
                              style: GoogleFonts.plusJakartaSans(
                                fontWeight: FontWeight.w800,
                                fontSize: 14,
                                color: AppColors.primaryContainer,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: (progressPct / 100).clamp(0, 1),
                  minHeight: 6,
                  backgroundColor: AppColors.surfaceContainerHighest,
                  color: _mastered ? AppColors.secondary : AppColors.primary,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Text(
                    '$totalWords từ',
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                  const Spacer(),
                  Text(
                    '$mastered đã nắm',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: AppColors.secondary,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ],
              ),
            ],
          ),
        ),
    );
  }
}

class _CustomTopicPlaceholder extends StatelessWidget {
  const _CustomTopicPlaceholder({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceContainerLowest,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: AppColors.outlineVariant,
              width: 1.6,
            ),
          ),
          child: Column(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLow,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.add_circle_outline_rounded,
                  size: 34,
                  color: AppColors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Chủ đề tùy chỉnh',
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Tải văn bản hoặc URL để tạo danh sách tập trung riêng.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.onSurfaceVariant,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
