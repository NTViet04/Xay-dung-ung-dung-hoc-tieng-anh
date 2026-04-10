import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../auth/controllers/auth_provider.dart';
import '../../../../core/constants/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/json_convert.dart';
import '../../../../data/models/topic_model.dart';
import '../../../../data/repositories/progress_repository.dart';
import '../../../../data/repositories/user_vocabulary_repository.dart';
import '../../../../data/repositories/topics_repository.dart';
import '../../../../data/repositories/vocabularies_repository.dart';
import '../../controllers/learner_tab_index.dart';
import '../../theme/learner_decorations.dart';
import '../../widgets/fluid_learner_page_footer.dart';
import '../../widgets/fluid_learner_top_nav.dart';

/// Trang chủ — bố cục theo `home_screen/code.html` (The Fluid Scholar).
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeSnapshot {
  _HomeSnapshot({
    required this.topics,
    required this.continueTopic,
    required this.continueTotalWords,
    required this.continueMasteredWords,
    required this.continueTouchedWords,
    required this.continueLessonProgress,
    required this.continueStartIndex,
  });

  final List<TopicModel> topics;
  final TopicModel? continueTopic;
  final int continueTotalWords;
  final int continueMasteredWords;
  /// Số từ đã có tương tác (learning / review / mastered), không phải chỉ mastered.
  final int continueTouchedWords;
  /// (vocab_progress_pct + quiz_best) / 200 — cần cả ôn từ và quiz mới lên 100%.
  final double continueLessonProgress;
  final int continueStartIndex;
}

class _HomeScreenState extends State<HomeScreen> {
  Future<_HomeSnapshot>? _future;
  LearnerTabIndex? _learnerTabs;

  static const _kWorkspaceImage =
      'https://lh3.googleusercontent.com/aida-public/AB6AXuApcObIb1caj1zzxfAqrXdNfEPCl1r5ppSlw6K24g2m1-ANtpacAMMUmgQmJNFSPHxg14RdjRuPISxZRVcyImHbN_6esOUGxCVu_QDTJFm9ALyq536EOqgl8e_fMqWHCheELyyIxP1TBusSHawlddecMIR1EobZP1s45-oxlYK2vubrFxI0R2nnduHw3RDjSoM9K0IQsQnSu3XMwYG5S6HScWcxoyANXlnsWO47BNKKRqS9j-Ar7Wxok9Utl4uXClEWIdyJNwW5uNk';

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
    if (_learnerTabs?.index != 0) {
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

  Future<_HomeSnapshot> _load() async {
    final topicsRepo = context.read<TopicsRepository>();
    final vocabRepo = context.read<VocabulariesRepository>();
    final uvRepo = context.read<UserVocabularyRepository>();
    final progressRepo = context.read<ProgressRepository>();
    final topics = await topicsRepo.fetchTopics();

    TopicModel? continueTopic;
    var continueTotal = 0;
    var continueMastered = 0;
    var continueTouched = 0;
    var continueLessonProgress = 0.0;
    var continueStartIndex = 0;

    if (topics.isNotEmpty) {
      // Ưu tiên chủ đề có hoạt động gần nhất (từ vựng), fallback về chủ đề đầu tiên.
      int? recentVocabId;
      DateTime? recentTs;
      final statusByVid = <int, String>{};
      try {
        final mine = await uvRepo.fetchMine();
        for (final row in mine) {
          final vid = parseJsonInt(row['vocab_id']);
          if (vid != null) {
            statusByVid[vid] = '${row['status']}';
          }
          final tsRaw = row['last_review'];
          DateTime? ts;
          if (tsRaw is String) {
            ts = DateTime.tryParse(tsRaw);
          }
          if (ts == null) {
            continue;
          }
          if (recentTs == null || ts.isAfter(recentTs)) {
            recentTs = ts;
            recentVocabId = vid;
          }
        }
      } catch (_) {}

      try {
        final all = await vocabRepo.fetchAll();
        final vocabTopic = <int, int>{};
        final counts = <int, int>{};
        for (final v in all) {
          vocabTopic[v.id] = v.topicId;
          counts[v.topicId] = (counts[v.topicId] ?? 0) + 1;
        }

        final masteredCount = <int, int>{};
        for (final e in statusByVid.entries) {
          if (e.value != 'mastered') {
            continue;
          }
          final tid = vocabTopic[e.key];
          if (tid == null) {
            continue;
          }
          masteredCount[tid] = (masteredCount[tid] ?? 0) + 1;
        }

        final tid = recentVocabId != null ? vocabTopic[recentVocabId] : null;
        if (tid != null) {
          for (final t in topics) {
            if (t.id == tid) {
              continueTopic = t;
              break;
            }
          }
        }
        final ct = continueTopic ?? topics.first;
        continueTopic = ct;
        continueTotal = counts[ct.id] ?? 0;
        continueMastered = masteredCount[ct.id] ?? 0;

        try {
          final list = await vocabRepo.fetchByTopic(ct.id);
          for (final v in list) {
            final s = statusByVid[v.id];
            if (s != null && s != 'new') {
              continueTouched++;
            }
          }
          if (recentVocabId != null && tid == ct.id) {
            final idx = list.indexWhere((v) => v.id == recentVocabId);
            continueStartIndex = idx >= 0 ? idx : 0;
          }
        } catch (_) {}

        try {
          final rows = await progressRepo.fetchMyTopicProgress();
          var vocabPct = 0;
          var quizPct = 0;
          for (final r in rows) {
            if ((parseJsonInt(r['topic_id']) ?? 0) == ct.id) {
              vocabPct = parseJsonInt(r['vocab_progress_pct']) ?? 0;
              quizPct = parseJsonInt(r['quiz_best_score']) ?? 0;
              break;
            }
          }
          continueLessonProgress = (vocabPct + quizPct) / 200.0;
        } catch (_) {
          continueLessonProgress = continueTotal > 0
              ? (continueMastered / continueTotal).clamp(0.0, 1.0) * 0.5
              : 0.0;
        }
      } catch (_) {
        // API từ vựng lỗi không làm mất cả trang chủ.
        continueTopic = topics.first;
        continueTotal = 0;
        continueMastered = 0;
        continueTouched = 0;
        continueLessonProgress = 0;
        continueStartIndex = 0;
      }
    }

    return _HomeSnapshot(
      topics: topics,
      continueTopic: continueTopic,
      continueTotalWords: continueTotal,
      continueMasteredWords: continueMastered,
      continueTouchedWords: continueTouched,
      continueLessonProgress:
          continueLessonProgress.clamp(0.0, 1.0),
      continueStartIndex: continueStartIndex,
    );
  }

  Future<void> _openQuiz(BuildContext context, int topicId) async {
    await Navigator.pushNamed(
      context,
      AppRoutes.learnerQuiz,
      arguments: {'topicId': topicId},
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final xp = auth.user?.xp ?? 0;
    final level = auth.user?.level ?? 1;
    final name = auth.user?.username ?? 'bạn';
    final streak = (level * 2 + (xp % 7)).clamp(1, 99);
    final dailyPct = ((xp % 500) / 500 * 100).round().clamp(5, 95);
    final wordsToGoal = math.max(1, ((100 - dailyPct) / 15).ceil().clamp(1, 12));
    final quickReviewCount = math.min(8, math.max(1, (xp % 8) + 1));

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: FluidLearnerTopNav(
        currentIndex: 0,
        extraActions: auth.user?.isAdmin == true
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
      body: FutureBuilder<_HomeSnapshot>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final data = snap.data ??
              _HomeSnapshot(
                topics: [],
                continueTopic: null,
                continueTotalWords: 0,
                continueMasteredWords: 0,
                continueTouchedWords: 0,
                continueLessonProgress: 0,
                continueStartIndex: 0,
              );
          final topics = data.topics;
          final featured = data.continueTopic;
          final reco = topics.take(4).toList();
          final totalWords = data.continueTotalWords > 0
              ? data.continueTotalWords
              : 1;
          final studied =
              data.continueTouchedWords.clamp(0, totalWords);
          final lessonProgress = data.continueLessonProgress.clamp(0.0, 1.0);

          final screenW = MediaQuery.sizeOf(context).width;

          return RefreshIndicator(
            onRefresh: () async {
              setState(() => _future = _load());
              await _future;
            },
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.fromLTRB(
                20,
                8,
                20,
                24 + MediaQuery.paddingOf(context).bottom,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _HeroGreeting(
                    name: name,
                    streak: streak,
                    xp: xp,
                    wide: screenW >= 640,
                  ),
                        const SizedBox(height: 20),
                        _DailyGoalBanner(
                          dailyPct: dailyPct,
                          wordsToGoal: wordsToGoal,
                        ),
                        const SizedBox(height: 28),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Tiếp tục học',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.5,
                              ),
                            ),
                            TextButton(
                              onPressed: () => context
                                  .read<LearnerTabIndex>()
                                  .goTo(1),
                              child: Text(
                                'XEM TẤT CẢ',
                                style: GoogleFonts.spaceGrotesk(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 12,
                                  letterSpacing: 1.2,
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        if (featured != null)
                          LayoutBuilder(
                            builder: (context, inner) {
                              final wide = inner.maxWidth >= 900;
                              final continueCard = _ContinueLearningCard(
                                topic: featured,
                                studied: studied,
                                totalWords: totalWords,
                                progress: lessonProgress,
                                imageUrl: _kWorkspaceImage,
                                onResume: () => Navigator.pushNamed(
                                  context,
                                  AppRoutes.learnerFlashcards,
                                  arguments: {
                                    'topicId': featured.id,
                                    'topicName': featured.name,
                                    'startIndex': data.continueStartIndex,
                                  },
                                ),
                                onOpenTopic: () => Navigator.pushNamed(
                                  context,
                                  AppRoutes.learnerVocabulary,
                                  arguments: {
                                    'topicId': featured.id,
                                    'topicName': featured.name,
                                  },
                                ),
                              );
                              final side = Column(
                                children: [
                                  _RecentBadgeCard(xp: xp),
                                  const SizedBox(height: 16),
                                  _QuickReviewCard(
                                    readyCount: quickReviewCount,
                                    onStartQuiz: topics.isEmpty
                                        ? null
                                        : () => _openQuiz(
                                              context,
                                              topics.first.id,
                                            ),
                                  ),
                                ],
                              );
                              if (wide) {
                                return Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(flex: 2, child: continueCard),
                                    const SizedBox(width: 24),
                                    Expanded(flex: 1, child: side),
                                  ],
                                );
                              }
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  continueCard,
                                  const SizedBox(height: 16),
                                  side,
                                ],
                              );
                            },
                          )
                        else
                          Text(
                            snap.hasError
                                ? 'Không tải được chủ đề.'
                                : 'Chưa có chủ đề. Thêm trong khu vực quản trị.',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        const SizedBox(height: 32),
                        Text(
                          'Chủ đề gợi ý',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 16),
                        if (reco.isEmpty &&
                            snap.connectionState == ConnectionState.done)
                          Text(
                            'Chưa có dữ liệu.',
                            style: Theme.of(context).textTheme.bodyMedium,
                          )
                        else
                          LayoutBuilder(
                            builder: (context, inner) {
                              final cols = inner.maxWidth >= 900
                                  ? 4
                                  : inner.maxWidth >= 520
                                      ? 2
                                      : 2;
                              return GridView.count(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                crossAxisCount: cols,
                                mainAxisSpacing: 14,
                                crossAxisSpacing: 14,
                                childAspectRatio: cols >= 4 ? 1.05 : 1.1,
                                children: [
                                  for (var i = 0; i < reco.length; i++)
                                    _TopicMiniCard(
                                      topic: reco[i],
                                      color: _accent(i),
                                      icon: _topicIcon(i),
                                      onTap: () => Navigator.pushNamed(
                                        context,
                                        AppRoutes.learnerVocabulary,
                                        arguments: {
                                          'topicId': reco[i].id,
                                          'topicName': reco[i].name,
                                        },
                                      ),
                                    ),
                                ],
                              );
                            },
                          ),
                  const SizedBox(height: 28),
                  const FluidLearnerPageFooter(),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  static Color _accent(int i) {
    const c = [
      Color(0xFFDBEAFE),
      Color(0xFFE9D5FF),
      Color(0xFFD1FAE5),
      Color(0xFFFFE4E6),
    ];
    return c[i % c.length];
  }

  static IconData _topicIcon(int i) {
    const icons = [
      Icons.restaurant_rounded,
      Icons.apartment_rounded,
      Icons.biotech_rounded,
      Icons.theater_comedy_rounded,
    ];
    return icons[i % icons.length];
  }
}

class _HeroGreeting extends StatelessWidget {
  const _HeroGreeting({
    required this.name,
    required this.streak,
    required this.xp,
    required this.wide,
  });

  final String name;
  final int streak;
  final int xp;
  final bool wide;

  static String _formatInt(int n) {
    return n.toString().replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (m) => '${m[1]},',
        );
  }

  @override
  Widget build(BuildContext context) {
    final titleStyle = GoogleFonts.plusJakartaSans(
      fontSize: wide ? 44 : 32,
      fontWeight: FontWeight.w900,
      height: 1.05,
      letterSpacing: -1.2,
      color: AppColors.onSurface,
    );

    final stats = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _StatPill(
          icon: Icons.local_fire_department_rounded,
          iconBg: AppColors.tertiaryFixed,
          iconColor: const Color(0xFFEA580C),
          value: '$streak',
          label: 'CHUỖI NGÀY',
          valueColor: const Color(0xFFEA580C),
        ),
        const SizedBox(width: 12),
        _StatPill(
          icon: Icons.star_rounded,
          iconBg: AppColors.secondaryFixed.withValues(alpha: 0.45),
          iconColor: AppColors.secondary,
          value: _formatInt(xp),
          label: 'ĐIỂM XP',
          valueColor: AppColors.secondary,
        ),
      ],
    );

    if (wide) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Xin chào, $name!', style: titleStyle),
                const SizedBox(height: 10),
                Text(
                  'Bạn đang học rất tốt hôm nay — giữ momentum nhé!',
                  style: GoogleFonts.inter(
                    fontSize: 17,
                    height: 1.45,
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          stats,
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Xin chào, $name!', style: titleStyle),
        const SizedBox(height: 10),
        Text(
          'Bạn đang học rất tốt hôm nay — giữ momentum nhé!',
          style: GoogleFonts.inter(
            fontSize: 15,
            height: 1.45,
            color: AppColors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 18),
        stats,
      ],
    );
  }
}

class _StatPill extends StatelessWidget {
  const _StatPill({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.value,
    required this.label,
    required this.valueColor,
  });

  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String value;
  final String label;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.outlineVariant.withValues(alpha: 0.12),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryContainer.withValues(alpha: 0.06),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: iconBg,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 24),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: GoogleFonts.robotoMono(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: valueColor,
                ),
              ),
              Text(
                label,
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.3,
                  color: const Color(0xFF653E00),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DailyGoalBanner extends StatelessWidget {
  const _DailyGoalBanner({
    required this.dailyPct,
    required this.wordsToGoal,
  });

  final int dailyPct;
  final int wordsToGoal;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: LearnerDecorations.primaryHero(radius: 20),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            right: -30,
            bottom: -30,
            child: Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF818CF8).withValues(alpha: 0.22),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Tiến độ mục tiêu hôm nay',
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 18,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.22),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '$dailyPct%',
                      style: GoogleFonts.robotoMono(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: dailyPct / 100,
                  minHeight: 12,
                  backgroundColor: Colors.white.withValues(alpha: 0.22),
                  color: AppColors.secondaryFixed,
                ),
              ),
              const SizedBox(height: 12),
              Text.rich(
                TextSpan(
                  style: GoogleFonts.inter(
                    color: const Color(0xFFE9D5FF),
                    fontSize: 14,
                    height: 1.4,
                  ),
                  children: [
                    const TextSpan(text: 'Chỉ còn '),
                    TextSpan(
                      text: '$wordsToGoal từ nữa',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const TextSpan(text: ' là đạt mục tiêu trong ngày!'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ContinueLearningCard extends StatelessWidget {
  const _ContinueLearningCard({
    required this.topic,
    required this.studied,
    required this.totalWords,
    required this.progress,
    required this.imageUrl,
    required this.onResume,
    required this.onOpenTopic,
  });

  final TopicModel topic;
  final int studied;
  final int totalWords;
  final double progress;
  final String imageUrl;
  final VoidCallback onResume;
  final VoidCallback onOpenTopic;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceContainerLowest,
      elevation: 6,
      shadowColor: Colors.black26,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onOpenTopic,
        borderRadius: BorderRadius.circular(20),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: LayoutBuilder(
            builder: (context, c) {
              final row = c.maxWidth >= 520;
              final img = Stack(
                fit: StackFit.expand,
                children: [
                  Image.network(
                    imageUrl,
                    fit: BoxFit.cover,
                    color: Colors.white.withValues(alpha: 0.92),
                    colorBlendMode: BlendMode.saturation,
                    errorBuilder: (context, e, st) => Container(
                      color: AppColors.surfaceContainerHighest,
                      child: Icon(
                        Icons.work_outline_rounded,
                        size: 56,
                        color: AppColors.primaryContainer,
                      ),
                    ),
                  ),
                  Container(color: AppColors.primary.withValues(alpha: 0.22)),
                ],
              );
              final body = Container(
                color: AppColors.surfaceContainerLow,
                padding: const EdgeInsets.all(22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE2DFFF),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        'CHỦ ĐỀ',
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                          color: AppColors.primaryContainer,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      topic.name,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      topic.description ??
                          'Ôn tập từ vựng và làm quiz LexiFlow theo chủ đề.',
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        color: AppColors.onSurfaceVariant,
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Tiến độ',
                          style: GoogleFonts.robotoMono(
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          '${(progress * 100).round()}% · $studied/$totalWords đã ôn',
                          style: GoogleFonts.robotoMono(
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Gồm % ôn từ (trọng số) và điểm quiz tốt nhất — đủ cả hai mới 100%.',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        height: 1.35,
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        value: progress.clamp(0.0, 1.0),
                        minHeight: 8,
                        backgroundColor: AppColors.surfaceContainerHighest,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          backgroundColor: AppColors.primary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed: onResume,
                        icon: const Icon(Icons.play_arrow_rounded),
                        label: const Text('Tiếp tục bài học'),
                      ),
                    ),
                  ],
                ),
              );

              if (row) {
                // Không dùng IntrinsicHeight + Expanded (Flutter không hỗ trợ — web có thể trắng màn).
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 5,
                      child: SizedBox(
                        height: 300,
                        child: img,
                      ),
                    ),
                    Expanded(flex: 6, child: body),
                  ],
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(height: 200, child: img),
                  body,
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _RecentBadgeCard extends StatelessWidget {
  const _RecentBadgeCard({required this.xp});

  final int xp;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppColors.outlineVariant.withValues(alpha: 0.15),
        ),
      ),
      constraints: const BoxConstraints(minHeight: 180),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Huy hiệu gần đây',
            style: GoogleFonts.plusJakartaSans(
              fontWeight: FontWeight.w800,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              CircleAvatar(
                radius: 30,
                backgroundColor: const Color(0xFFFFFBEB),
                child: Icon(
                  Icons.workspace_premium_rounded,
                  color: Colors.amber.shade800,
                  size: 34,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Học nhanh',
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w800,
                        fontSize: 17,
                      ),
                    ),
                    Text(
                      '${math.min(50, xp ~/ 20)} từ trong tuần này',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.onSurfaceVariant,
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
  }
}

class _QuickReviewCard extends StatelessWidget {
  const _QuickReviewCard({
    required this.readyCount,
    required this.onStartQuiz,
  });

  final int readyCount;
  final VoidCallback? onStartQuiz;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.secondaryFixed.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppColors.secondary.withValues(alpha: 0.12),
        ),
      ),
      constraints: const BoxConstraints(minHeight: 180, maxHeight: 180),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Ôn nhanh',
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  color: AppColors.secondary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '$readyCount từ đang sẵn sàng cho ôn tập spaced repetition.',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  height: 1.45,
                  color: AppColors.secondary,
                ),
              ),
            ],
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: onStartQuiz,
              icon: const Icon(Icons.arrow_forward_rounded, size: 18),
              label: Text(
                'BẮT ĐẦU QUIZ',
                style: GoogleFonts.spaceGrotesk(
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                  fontSize: 12,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TopicMiniCard extends StatelessWidget {
  const _TopicMiniCard({
    required this.topic,
    required this.color,
    required this.icon,
    required this.onTap,
  });

  final TopicModel topic;
  final Color color;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceContainerLowest,
      borderRadius: BorderRadius.circular(16),
      elevation: 1,
      shadowColor: Colors.black12,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: AppColors.primaryContainer, size: 26),
              ),
              const SizedBox(height: 12),
              Text(
                topic.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Chủ đề từ vựng',
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
