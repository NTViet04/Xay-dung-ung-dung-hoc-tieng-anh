import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/json_convert.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../../../data/models/topic_model.dart';
import '../../../../data/repositories/progress_repository.dart';
import '../../../../data/repositories/quiz_repository.dart';
import '../../../../data/repositories/topics_repository.dart';
import '../../../../data/repositories/user_vocabulary_repository.dart';
import '../../../../data/repositories/vocabularies_repository.dart';
import '../../../auth/controllers/auth_provider.dart';
import '../../controllers/learner_tab_index.dart';
import '../../theme/learner_decorations.dart';
import '../../widgets/fluid_learner_page_footer.dart';
import '../../widgets/fluid_learner_top_nav.dart';

/// Trọng số trùng backend `progressController` (LEFT JOIN — không có dòng = 0).
double _userVocabStatusWeight(String? s) {
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

/// Tiến độ & hồ sơ học tập — theo `profile_progress/code.html` (The Fluid Scholar).
class ProfileProgressScreen extends StatefulWidget {
  const ProfileProgressScreen({super.key});

  @override
  State<ProfileProgressScreen> createState() => _ProfileProgressScreenState();
}

class _ProfileData {
  _ProfileData({
    required this.topics,
    required this.results,
    required this.topicWordCounts,
    required this.topicBestScore,
    required this.topicMasteredCount,
    required this.topicVocabProgressPct,
    this.summary,
  });

  final List<TopicModel> topics;
  final List<Map<String, dynamic>> results;
  final Map<int, int> topicWordCounts;
  final Map<int, int> topicBestScore;
  final Map<int, int> topicMasteredCount;
  /// % từ vựng có trọng số (new/learning/review/mastered) — đồng bộ backend.
  final Map<int, int> topicVocabProgressPct;
  /// Từ GET /progress/summary — null nếu API lỗi (dùng ước lượng cục bộ).
  final Map<String, dynamic>? summary;
}

enum _TopicFilter { ongoing, mastered }

class _ProfileProgressScreenState extends State<ProfileProgressScreen> {
  Future<_ProfileData>? _future;
  _TopicFilter _topicFilter = _TopicFilter.ongoing;
  LearnerTabIndex? _learnerTabs;

  void _onLearnerTabChanged() {
    if (!mounted) {
      return;
    }
    if (_learnerTabs?.index != 2) {
      return;
    }
    setState(() {
      _future = _load();
    });
  }

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

  Future<_ProfileData> _load() async {
    final topicsRepo = context.read<TopicsRepository>();
    final quizRepo = context.read<QuizRepository>();
    final progressRepo = context.read<ProgressRepository>();
    final topics = await topicsRepo.fetchTopics();
    List<Map<String, dynamic>> results;
    try {
      results = await quizRepo.fetchMyResults();
    } catch (_) {
      results = [];
    }
    Map<String, dynamic>? summary;
    try {
      summary = await progressRepo.fetchMyProgressSummary();
    } catch (_) {
      summary = null;
    }
    try {
      final rows = await progressRepo.fetchMyTopicProgress();
      final counts = <int, int>{};
      final masteredCount = <int, int>{};
      final vocabPct = <int, int>{};
      final best = <int, int>{};
      for (final r in rows) {
        final tid = parseJsonInt(r['topic_id']);
        if (tid == null) {
          continue;
        }
        counts[tid] = parseJsonInt(r['vocab_total']) ?? 0;
        masteredCount[tid] = parseJsonInt(r['vocab_mastered']) ?? 0;
        vocabPct[tid] = parseJsonInt(r['vocab_progress_pct']) ?? 0;
        best[tid] = parseJsonInt(r['quiz_best_score']) ?? 0;
      }
      final base = _ProfileData(
        topics: topics,
        results: results,
        topicWordCounts: counts,
        topicBestScore: best,
        topicMasteredCount: masteredCount,
        topicVocabProgressPct: vocabPct,
        summary: null,
      );
      return _ProfileData(
        topics: topics,
        results: results,
        topicWordCounts: counts,
        topicBestScore: best,
        topicMasteredCount: masteredCount,
        topicVocabProgressPct: vocabPct,
        summary: summary ?? _localSummaryFromData(base),
      );
    } catch (_) {
      final fb = await _profileProgressFallback(topics, results);
      return _ProfileData(
        topics: fb.topics,
        results: fb.results,
        topicWordCounts: fb.topicWordCounts,
        topicBestScore: fb.topicBestScore,
        topicMasteredCount: fb.topicMasteredCount,
        topicVocabProgressPct: fb.topicVocabProgressPct,
        summary: summary ?? _localSummaryFromData(fb),
      );
    }
  }

  /// Khi không gọi được /progress/summary.
  Map<String, dynamic> _localSummaryFromData(_ProfileData d) {
    var topicsDone = 0;
    for (final t in d.topics) {
      final wc = d.topicWordCounts[t.id] ?? 0;
      final vp = d.topicVocabProgressPct[t.id] ?? 0;
      final qp = d.topicBestScore[t.id] ?? 0;
      final mastery = wc > 0 ? math.max(vp, qp) : qp;
      if (mastery >= 100) {
        topicsDone++;
      }
    }
    final words = _wordsLearnedEstimate(d);
    return {
      'words_mastered_total': words,
      'quiz_attempts_total': d.results.length,
      'topics_mastered_count': topicsDone,
      'topics_total': d.topics.length,
      'avg_quiz_score': _avgScore(d.results).round().clamp(0, 100),
      'streak_days': 0,
      'study_minutes_estimate':
          (d.results.length * 3 + words * 2).clamp(1, 999999),
    };
  }

  Future<_ProfileData> _profileProgressFallback(
    List<TopicModel> topics,
    List<Map<String, dynamic>> results,
  ) async {
    final vocabRepo = context.read<VocabulariesRepository>();
    final uvRepo = context.read<UserVocabularyRepository>();
    final counts = <int, int>{};
    final masteredCount = <int, int>{};
    final topicVocabPct = <int, int>{};
    try {
      final all = await vocabRepo.fetchAll();
      final vocabTopic = <int, int>{};
      for (final v in all) {
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
        if ('${row['status']}' == 'mastered') {
          final vidM = parseJsonInt(row['vocab_id']);
          if (vidM == null) {
            continue;
          }
          final topicId = vocabTopic[vidM];
          if (topicId != null) {
            masteredCount[topicId] = (masteredCount[topicId] ?? 0) + 1;
          }
        }
      }
      for (final tid in counts.keys) {
        final wc = counts[tid] ?? 0;
        if (wc <= 0) {
          continue;
        }
        var sum = 0.0;
        for (final v in all) {
          if (v.topicId != tid) {
            continue;
          }
          sum += _userVocabStatusWeight(statusByVid[v.id]);
        }
        topicVocabPct[tid] = (sum / wc * 100).round().clamp(0, 100);
      }
    } catch (_) {}
    final best = <int, int>{};
    for (final r in results) {
      final tid = parseJsonInt(r['topic_id']);
      if (tid == null) {
        continue;
      }
      final sc = parseJsonInt(r['score']) ?? 0;
      best[tid] = math.max(best[tid] ?? 0, sc);
    }
    return _ProfileData(
      topics: topics,
      results: results,
      topicWordCounts: counts,
      topicBestScore: best,
      topicMasteredCount: masteredCount,
      topicVocabProgressPct: topicVocabPct,
      summary: null,
    );
  }

  Future<void> _refresh() async {
    setState(() => _future = _load());
    await context.read<AuthProvider>().refreshProfile();
    await _future;
  }

  static String _formatInt(int n) {
    return n.toString().replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (m) => '${m[1]},',
        );
  }

  static double _avgScore(List<Map<String, dynamic>> results) {
    if (results.isEmpty) {
      return 0;
    }
    final sum = results.fold<double>(
      0,
      (a, r) => a + ((r['score'] as num?)?.toDouble() ?? 0),
    );
    return sum / results.length;
  }

  static int _wordsLearnedEstimate(_ProfileData d) {
    var n = 0;
    for (final t in d.topics) {
      n += d.topicMasteredCount[t.id] ?? 0;
    }
    return n;
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final u = auth.user;
    final xp = u?.xp ?? 0;
    final level = u?.level ?? 1;
    final name = u?.username ?? 'Bạn';

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: FluidLearnerTopNav(
        currentIndex: 2,
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
      body: FutureBuilder<_ProfileData>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text('${snap.error}', textAlign: TextAlign.center),
              ),
            );
          }
          final data = snap.data!;
          final s = data.summary ?? _localSummaryFromData(data);
          final wordsLearned =
              parseJsonInt(s['words_mastered_total']) ??
                  _wordsLearnedEstimate(data);
          final accuracyPct = parseJsonInt(s['avg_quiz_score']) ??
              (data.results.isEmpty
                  ? 0
                  : _avgScore(data.results).round().clamp(0, 100));
          final streakDays =
              (parseJsonInt(s['streak_days']) ?? 0).clamp(0, 365);
          final studyMinutes =
              (parseJsonInt(s['study_minutes_estimate']) ?? 1).clamp(1, 999999);
          final topicsDone =
              parseJsonInt(s['topics_mastered_count']) ?? 0;
          final topicsTot =
              parseJsonInt(s['topics_total']) ?? data.topics.length;

          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              children: [
                _ProfileHeroCard(
                  name: name,
                  level: level,
                  xp: xp,
                  xpFormatted: _formatInt(xp),
                  accuracyPct: accuracyPct,
                  joinedLabel: _joinedLabel(u?.id ?? 0),
                  onEditProfile: () {
                    showAppSnackBar(
                      context,
                      'Tài khoản nằm trong icon người (góc phải).',
                      kind: AppSnackKind.info,
                    );
                  },
                  onShare: () {
                    showAppSnackBar(
                      context,
                      'Chia sẻ tiến độ sẽ bổ sung sau.',
                      kind: AppSnackKind.info,
                    );
                  },
                ),
                const SizedBox(height: 20),
                LayoutBuilder(
                  builder: (context, c) {
                    final wide = c.maxWidth >= 900;
                    final statsRow = Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: _WordsStatCard(
                            value: _formatInt(wordsLearned),
                            caption: 'Từ đánh dấu mastered',
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _TimeStatCard(minutes: studyMinutes),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _StreakCard(days: streakDays),
                        ),
                      ],
                    );
                    final statsCol = Column(
                      children: [
                        _WordsStatCard(
                          value: _formatInt(wordsLearned),
                          caption: 'Từ đánh dấu mastered',
                        ),
                        const SizedBox(height: 12),
                        _TimeStatCard(minutes: studyMinutes),
                        const SizedBox(height: 12),
                        _StreakCard(days: streakDays),
                      ],
                    );
                    return wide ? statsRow : statsCol;
                  },
                ),
                const SizedBox(height: 16),
                LayoutBuilder(
                  builder: (context, c) {
                    final wide = c.maxWidth >= 720;
                    final row = Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: _QuizMasteryCard(
                            topicsDone: topicsDone,
                            topicsTotal: topicsTot,
                            avgQuizScore: accuracyPct,
                          ),
                        ),
                        const SizedBox(width: 16),
                        const Expanded(child: _BadgesRowCard()),
                      ],
                    );
                    final col = Column(
                      children: [
                        _QuizMasteryCard(
                          topicsDone: topicsDone,
                          topicsTotal: topicsTot,
                          avgQuizScore: accuracyPct,
                        ),
                        const SizedBox(height: 16),
                        const _BadgesRowCard(),
                      ],
                    );
                    return wide ? row : col;
                  },
                ),
                const SizedBox(height: 28),
                _TopicMasteryHeader(
                  ongoing: _topicFilter == _TopicFilter.ongoing,
                  onSelectOngoing: () =>
                      setState(() => _topicFilter = _TopicFilter.ongoing),
                  onSelectMastered: () =>
                      setState(() => _topicFilter = _TopicFilter.mastered),
                ),
                const SizedBox(height: 16),
                ..._buildTopicTiles(context, data),
                SizedBox(height: 16 + MediaQuery.paddingOf(context).bottom),
                const FluidLearnerPageFooter(),
              ],
            ),
          );
        },
      ),
    );
  }

  String _joinedLabel(int userId) {
    final m = 1 + (userId % 12);
    final y = 2023 + (userId % 3);
    return 'Người đam mê ngôn ngữ · Tham gia tháng $m/$y';
  }

  List<Widget> _buildTopicTiles(BuildContext context, _ProfileData data) {
    final tiles = <Widget>[];
    for (var i = 0; i < data.topics.length; i++) {
      final t = data.topics[i];
      final wc = data.topicWordCounts[t.id] ?? 0;
      final vocabPct = data.topicVocabProgressPct[t.id] ?? 0;
      final quizPct = data.topicBestScore[t.id] ?? 0;
      final mastery = wc > 0 ? math.max(vocabPct, quizPct) : quizPct;
      final mastered = mastery >= 100;
      if (_topicFilter == _TopicFilter.mastered && !mastered) {
        continue;
      }
      if (_topicFilter == _TopicFilter.ongoing && mastered) {
        continue;
      }
      tiles.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _TopicMasteryTile(
            topic: t,
            wordCount: wc,
            mastery: mastery,
            iconIndex: i,
            onVocabulary: () {
              Navigator.pushNamed(
                context,
                AppRoutes.learnerVocabulary,
                arguments: {
                  'topicId': t.id,
                  'topicName': t.name,
                },
              );
            },
            onQuiz: () {
              Navigator.pushNamed(
                context,
                AppRoutes.learnerQuiz,
                arguments: {'topicId': t.id},
              );
            },
          ),
        ),
      );
    }
    if (tiles.isEmpty) {
      tiles.add(
        Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: Text(
              _topicFilter == _TopicFilter.mastered
                  ? 'Chưa có chủ đề nào đạt 100% tiến độ (từ vựng hoặc quiz).'
                  : 'Tất cả chủ đề đã đạt 100% — chuyển sang tab Đã thành thạo.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ),
      );
    }
    return tiles;
  }
}

class _ProfileHeroCard extends StatelessWidget {
  const _ProfileHeroCard({
    required this.name,
    required this.level,
    required this.xp,
    required this.xpFormatted,
    required this.accuracyPct,
    required this.joinedLabel,
    required this.onEditProfile,
    required this.onShare,
  });

  final String name;
  final int level;
  final int xp;
  final String xpFormatted;
  final int accuracyPct;
  final String joinedLabel;
  final VoidCallback onEditProfile;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: AppColors.primaryContainer.withValues(alpha: 0.08),
                blurRadius: 24,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: LayoutBuilder(
            builder: (context, c) {
              final row = c.maxWidth >= 720;
              final avatar = Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: row ? 128 : 112,
                    height: row ? 128 : 112,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white, width: 4),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.12),
                          blurRadius: 16,
                        ),
                      ],
                      color: AppColors.surfaceContainerHighest,
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Icon(
                        Icons.account_circle_rounded,
                        size: 64,
                        color: AppColors.primaryContainer,
                      ),
                    ),
                  ),
                  Positioned(
                    right: -6,
                    bottom: -6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF684000),
                        borderRadius: BorderRadius.circular(999),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.2),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.bolt_rounded,
                            size: 14,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'CẤP $level',
                            style: GoogleFonts.spaceGrotesk(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );

              final info = Column(
                crossAxisAlignment:
                    row ? CrossAxisAlignment.start : CrossAxisAlignment.center,
                children: [
                  Text(
                    name,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: row ? 40 : 32,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.8,
                      color: AppColors.onSurface,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    joinedLabel,
                    textAlign: row ? TextAlign.start : TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF777587),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 12,
                    runSpacing: 10,
                    alignment:
                        row ? WrapAlignment.start : WrapAlignment.center,
                    children: [
                      _HeroStatPill(
                        value: xpFormatted,
                        label: 'TỔNG XP',
                        fg: AppColors.primary,
                      ),
                      _HeroStatPill(
                        value: '$accuracyPct%',
                        label: 'ĐỘ CHÍNH XÁC',
                        fg: AppColors.secondary,
                      ),
                    ],
                  ),
                ],
              );

              final actions = Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: FilledButton(
                      onPressed: onEditProfile,
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 14,
                        ),
                        backgroundColor: AppColors.primaryContainer,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'Chỉnh sửa hồ sơ',
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Material(
                    color: AppColors.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      onTap: onShare,
                      borderRadius: BorderRadius.circular(12),
                      child: const Padding(
                        padding: EdgeInsets.all(14),
                        child: Icon(
                          Icons.share_rounded,
                          color: Color(0xFF3323CC),
                        ),
                      ),
                    ),
                  ),
                ],
              );

              if (row) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    avatar,
                    const SizedBox(width: 24),
                    Expanded(child: info),
                    const SizedBox(width: 16),
                    actions,
                  ],
                );
              }
              return Column(
                children: [
                  avatar,
                  const SizedBox(height: 20),
                  info,
                  const SizedBox(height: 20),
                  actions,
                ],
              );
            },
          ),
        ),
        Positioned(
          top: -40,
          right: -40,
          child: IgnorePointer(
            child: Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFC3C0FF).withValues(alpha: 0.2),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _HeroStatPill extends StatelessWidget {
  const _HeroStatPill({
    required this.value,
    required this.label,
    required this.fg,
  });

  final String value;
  final String label;
  final Color fg;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: fg.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: GoogleFonts.robotoMono(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: fg,
            ),
          ),
          Text(
            label,
            style: GoogleFonts.spaceGrotesk(
              fontSize: 9,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
              color: fg.withValues(alpha: 0.55),
            ),
          ),
        ],
      ),
    );
  }
}

class _WordsStatCard extends StatelessWidget {
  const _WordsStatCard({required this.value, required this.caption});

  final String value;
  final String caption;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: LearnerDecorations.cardSurface(radius: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.menu_book_rounded,
                  color: AppColors.primaryContainer,
                ),
              ),
              Flexible(
                child: Text(
                  caption,
                  textAlign: TextAlign.end,
                  maxLines: 2,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF64748B),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            value,
            style: GoogleFonts.robotoMono(
              fontSize: 34,
              fontWeight: FontWeight.w900,
              letterSpacing: -1,
              color: AppColors.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'TỪ ĐÃ HỌC',
            style: GoogleFonts.spaceGrotesk(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.4,
              color: const Color(0xFF777587),
            ),
          ),
        ],
      ),
    );
  }
}

class _TimeStatCard extends StatelessWidget {
  const _TimeStatCard({required this.minutes});

  final int minutes;

  static String _label(int m) {
    if (m >= 120) {
      final h = m ~/ 60;
      final rest = m % 60;
      return rest > 0 ? '~${h}h ${rest}p' : '~${h}h';
    }
    if (m >= 60) {
      final h = m ~/ 60;
      final rest = m % 60;
      return rest > 0 ? '~${h}h ${rest}p' : '~${h}h';
    }
    return '~$m phút';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: LearnerDecorations.cardSurface(radius: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF684000).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.schedule_rounded,
                  color: Color(0xFF684000),
                ),
              ),
              Text(
                'ƯỚC LƯỢNG',
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                  color: const Color(0xFF777587),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            _label(minutes),
            style: GoogleFonts.robotoMono(
              fontSize: 34,
              fontWeight: FontWeight.w900,
              letterSpacing: -1,
              color: AppColors.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'THỜI GIAN HỌC',
            style: GoogleFonts.spaceGrotesk(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.4,
              color: const Color(0xFF777587),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Từ số lần quiz + từ đã nắm',
            style: GoogleFonts.inter(
              fontSize: 11,
              color: const Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }
}

class _StreakCard extends StatelessWidget {
  const _StreakCard({required this.days});

  final int days;

  @override
  Widget build(BuildContext context) {
    const labels = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];
    final lit = math.min(days, 7);
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: LearnerDecorations.cardSurface(radius: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'CHUỖI HOẠT ĐỘNG',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                  color: const Color(0xFF777587),
                ),
              ),
              Row(
                children: [
                  Icon(
                    Icons.local_fire_department_rounded,
                    color: const Color(0xFF684000),
                    size: 22,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '$days ngày',
                    style: GoogleFonts.robotoMono(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                      color: const Color(0xFF684000),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: List.generate(7, (i) {
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(right: i < 6 ? 6 : 0),
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: Container(
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppColors.secondaryFixed.withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        labels[i],
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF007432),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 8),
          Row(
            children: List.generate(7, (i) {
              final on = i < lit;
              final med = i % 3 == 1;
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(right: i < 6 ? 6 : 0),
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(4),
                        color: on
                            ? AppColors.secondary.withValues(
                                alpha: med ? 1.0 : 0.85,
                              )
                            : AppColors.secondary.withValues(alpha: 0.18),
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 8),
          Text(
            'Đếm từ ngày có quiz hoặc ôn từ; các ô dưới minh họa tối đa 7 ngày.',
            style: GoogleFonts.inter(
              fontSize: 10,
              height: 1.3,
              color: const Color(0xFF777587),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuizMasteryCard extends StatelessWidget {
  const _QuizMasteryCard({
    required this.topicsDone,
    required this.topicsTotal,
    required this.avgQuizScore,
  });

  final int topicsDone;
  final int topicsTotal;
  final int avgQuizScore;

  @override
  Widget build(BuildContext context) {
    final bar = topicsTotal > 0
        ? (topicsDone / topicsTotal).clamp(0.0, 1.0)
        : 0.0;
    return Container(
      padding: const EdgeInsets.all(26),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: AppColors.primaryContainer,
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.2),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned(
            right: -20,
            bottom: -20,
            child: Icon(
              Icons.quiz_rounded,
              size: 120,
              color: Colors.white.withValues(alpha: 0.1),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'CHỦ ĐỀ HOÀN THÀNH',
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.3,
                  color: const Color(0xFFE0E7FF),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    '$topicsDone',
                    style: GoogleFonts.robotoMono(
                      fontSize: 44,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      height: 1,
                    ),
                  ),
                  Text(
                    ' / $topicsTotal',
                    style: GoogleFonts.robotoMono(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFFC7D2FE),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'chủ đề đạt 100% tiến độ',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFFC7D2FE),
                        height: 1.2,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'max(% từ vựng, điểm quiz tốt nhất) ≥ 100%',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: const Color(0xFFE0E7FF).withValues(alpha: 0.85),
                ),
              ),
              const SizedBox(height: 14),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: bar > 0 ? bar.clamp(0.02, 1.0) : 0.02,
                  minHeight: 8,
                  backgroundColor: const Color(0xFF312E81).withValues(alpha: 0.5),
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Điểm quiz trung bình: $avgQuizScore%',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFFE0E7FF),
                  height: 1.35,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BadgesRowCard extends StatelessWidget {
  const _BadgesRowCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(26),
      decoration: LearnerDecorations.cardSurface(radius: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Huy hiệu đạt được',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: AppColors.onSurface,
                ),
              ),
              TextButton(
                onPressed: () {
                  showAppSnackBar(
                    context,
                    'Danh sách huy hiệu sẽ mở rộng sau.',
                    kind: AppSnackKind.info,
                  );
                },
                child: Text(
                  'XEM TẤT CẢ',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                    color: AppColors.primaryContainer,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              _BadgeCircle(
                color: AppColors.tertiaryFixed,
                icon: Icons.wb_sunny_rounded,
                iconColor: const Color(0xFF653E00),
              ),
              const SizedBox(width: 12),
              _BadgeCircle(
                color: const Color(0xFFE2DFFF),
                icon: Icons.bedtime_rounded,
                iconColor: const Color(0xFF3323CC),
              ),
              const SizedBox(width: 12),
              _BadgeCircle(
                color: AppColors.secondaryFixed,
                icon: Icons.military_tech_rounded,
                iconColor: const Color(0xFF007432),
              ),
              const SizedBox(width: 12),
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.surfaceContainerHighest,
                  border: Border.all(
                    color: AppColors.outlineVariant,
                    width: 2,
                  ),
                ),
                child: Icon(
                  Icons.add_rounded,
                  color: AppColors.outlineVariant,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BadgeCircle extends StatelessWidget {
  const _BadgeCircle({
    required this.color,
    required this.icon,
    required this.iconColor,
  });

  final Color color;
  final IconData icon;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Icon(icon, color: iconColor, size: 26),
    );
  }
}

class _TopicMasteryHeader extends StatelessWidget {
  const _TopicMasteryHeader({
    required this.ongoing,
    required this.onSelectOngoing,
    required this.onSelectMastered,
  });

  final bool ongoing;
  final VoidCallback onSelectOngoing;
  final VoidCallback onSelectMastered;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            'Thành thạo theo chủ đề',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.4,
              color: AppColors.onSurface,
            ),
          ),
        ),
        _FilterChip(
          label: 'Đang học',
          selected: ongoing,
          onTap: onSelectOngoing,
          filled: false,
        ),
        const SizedBox(width: 8),
        _FilterChip(
          label: 'Đã thành thạo',
          selected: !ongoing,
          onTap: onSelectMastered,
          filled: true,
        ),
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.filled,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final bg = selected
        ? (filled
            ? AppColors.secondaryFixed
            : AppColors.surfaceContainerHighest)
        : AppColors.surfaceContainerHighest.withValues(alpha: 0.6);
    final fg = selected
            ? (filled
                ? const Color(0xFF007432)
                : AppColors.onSurfaceVariant)
        : AppColors.onSurfaceVariant.withValues(alpha: 0.7);
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Text(
            label,
            style: GoogleFonts.spaceGrotesk(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.6,
              color: fg,
            ),
          ),
        ),
      ),
    );
  }
}

class _TopicMasteryTile extends StatelessWidget {
  const _TopicMasteryTile({
    required this.topic,
    required this.wordCount,
    required this.mastery,
    required this.iconIndex,
    required this.onVocabulary,
    required this.onQuiz,
  });

  final TopicModel topic;
  final int wordCount;
  final int mastery;
  final int iconIndex;
  final VoidCallback onVocabulary;
  final VoidCallback onQuiz;

  static const _icons = [
    Icons.restaurant_rounded,
    Icons.flight_takeoff_rounded,
    Icons.science_rounded,
    Icons.theater_comedy_rounded,
    Icons.business_center_rounded,
  ];

  static const _bgColors = [
    Color(0xFFEEF2FF),
    Color(0xFFD1FAE5),
    Color(0xFFFEF3C7),
    Color(0xFFFCE7F3),
    Color(0xFFE0E7FF),
  ];

  String _subtitle() {
    if (wordCount >= 80) {
      return '$wordCount từ · Tiến độ = max(% từ có trọng số, điểm quiz tốt nhất)';
    }
    if (wordCount >= 40) {
      return '$wordCount từ · new/learning/review/mastered đều tăng % từ';
    }
    return '$wordCount từ · Học từ và quiz cùng chủ đề';
  }

  @override
  Widget build(BuildContext context) {
    final mastered = mastery >= 100;
    final icon = _icons[iconIndex % _icons.length];
    final bg = _bgColors[iconIndex % _bgColors.length];

    return Material(
      color: AppColors.surfaceContainerLowest,
      borderRadius: BorderRadius.circular(16),
      elevation: 0,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: LearnerDecorations.cardSurface(radius: 16),
        child: LayoutBuilder(
            builder: (context, c) {
              final row = c.maxWidth >= 640;
              final lead = Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  icon,
                  size: 36,
                  color: AppColors.primaryContainer,
                ),
              );
              final mid = Column(
                crossAxisAlignment:
                    row ? CrossAxisAlignment.start : CrossAxisAlignment.center,
                children: [
                  Text(
                    topic.name,
                    textAlign: row ? TextAlign.start : TextAlign.center,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: AppColors.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _subtitle(),
                    textAlign: row ? TextAlign.start : TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF777587),
                    ),
                  ),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: SizedBox(
                      height: 6,
                      child: LinearProgressIndicator(
                        value: (mastery / 100).clamp(0.0, 1.0),
                        backgroundColor: AppColors.surfaceContainerHighest,
                        color: mastered
                            ? AppColors.secondary
                            : AppColors.primaryContainer,
                      ),
                    ),
                  ),
                ],
              );
              final trail = Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Column(
                    children: [
                      Text(
                        '$mastery%',
                        style: GoogleFonts.robotoMono(
                          fontWeight: FontWeight.w800,
                          fontSize: 18,
                          color: mastered
                              ? AppColors.secondary
                              : AppColors.primaryContainer,
                        ),
                      ),
                      Text(
                        'THÀNH THẠO',
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1,
                          color: const Color(0xFF777587),
                        ),
                      ),
                    ],
                  ),
                  if (row) ...[
                    const SizedBox(width: 12),
                    Container(
                      width: 1,
                      height: 40,
                      color: AppColors.outlineVariant.withValues(alpha: 0.5),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (mastered)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Icon(
                            Icons.verified_rounded,
                            color: const Color(0xFF885500),
                            size: 28,
                          ),
                        ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          OutlinedButton(
                            onPressed: onVocabulary,
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                            ),
                            child: Text(
                              'Từ vựng',
                              style: GoogleFonts.plusJakartaSans(
                                fontWeight: FontWeight.w800,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          FilledButton.tonal(
                            onPressed: onQuiz,
                            style: FilledButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              backgroundColor:
                                  AppColors.primary.withValues(alpha: 0.1),
                              foregroundColor: AppColors.primaryContainer,
                            ),
                            child: Text(
                              'Quiz',
                              style: GoogleFonts.plusJakartaSans(
                                fontWeight: FontWeight.w800,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              );
              if (row) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    lead,
                    const SizedBox(width: 20),
                    Expanded(child: mid),
                    trail,
                  ],
                );
              }
              return Column(
                children: [
                  lead,
                  const SizedBox(height: 16),
                  mid,
                  const SizedBox(height: 16),
                  trail,
                ],
              );
            },
          ),
        ),
    );
  }
}
