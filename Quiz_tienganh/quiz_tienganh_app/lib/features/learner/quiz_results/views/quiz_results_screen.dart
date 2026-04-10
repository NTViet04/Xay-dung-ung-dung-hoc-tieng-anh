import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/constants/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../../../data/models/vocabulary_model.dart';
import '../../theme/learner_decorations.dart';
import '../../widgets/fluid_learner_page_footer.dart';

/// Kết quả quiz sau khi nộp API.
class QuizResultsScreen extends StatelessWidget {
  const QuizResultsScreen({
    super.key,
    required this.score,
    required this.total,
    required this.xpGained,
    this.elapsed,
    this.correctCount,
    this.level,
    this.xp,
    this.topicId,
    this.topicName,
    this.missedWords,
  });

  /// Điểm % (0–100)
  final int score;
  final int total;
  final int xpGained;
  /// Thời gian làm bài (vd: `04:12`) — optional để tương thích route cũ.
  final String? elapsed;
  final int? correctCount;
  final int? level;
  final int? xp;
  final int? topicId;
  final String? topicName;
  final List<VocabularyModel>? missedWords;

  int get _derivedCorrect => correctCount ??
      (total <= 0 ? 0 : ((score / 100) * total).round().clamp(0, total));

  int get _incorrect => (total - _derivedCorrect).clamp(0, total);

  String get _elapsedLabel => elapsed ?? '—:—';

  String get _accuracyShort {
    if (score >= 85) return 'Cao';
    if (score >= 60) return 'Khá';
    return 'Cần luyện thêm';
  }

  String get _rewardTitle {
    if (score >= 90) return 'Bứt phá đà học';
    if (score >= 75) return 'Tăng tốc ổn định';
    return 'Giữ nhịp tiến bộ';
  }

  String _rewardSubtitle(int? level, int? xp) {
    if (level == null || xp == null) {
      return 'Tiếp tục làm quiz để tích lũy XP và lên cấp.';
    }
    final nextLevelXp = level * 500;
    final remain = math.max(0, nextLevelXp - (xp % 500));
    return 'Bạn chỉ còn $remain XP nữa để đạt cấp ${level + 1}.';
  }

  static String _formatInt(int n) {
    return n.toString().replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (m) => '${m[1]},',
        );
  }

  @override
  Widget build(BuildContext context) {
    final curXp = xp ?? 0;
    final lv = level ?? 1;
    final nextLevelXp = lv * 500;
    final bar = nextLevelXp <= 0 ? 0.0 : (curXp % 500) / 500.0;

    final missed = missedWords ?? const <VocabularyModel>[];

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: _QuizResultsTopBar(
        onClose: () => Navigator.pushNamedAndRemoveUntil(
          context,
          AppRoutes.learnerHome,
          (r) => false,
        ),
      ),
      body: Stack(
        children: [
          const Positioned.fill(child: _ConfettiBackdrop(opacity: 0.22)),
          ListView(
            padding: EdgeInsets.fromLTRB(
              20,
              16,
              20,
              24 + MediaQuery.paddingOf(context).bottom,
            ),
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 980),
                  child: Column(
                    children: [
                      const SizedBox(height: 8),
                      _CelebrationHeader(
                        title: 'Hoàn thành quiz!',
                        subtitle: topicName != null && topicName!.trim().isNotEmpty
                            ? 'Bạn vừa hoàn thành chủ đề: $topicName'
                            : 'Bạn đang tiến bộ rất nhanh với LexiFlow.',
                      ),
                      const SizedBox(height: 22),
                      LayoutBuilder(
                        builder: (context, c) {
                          final wide = c.maxWidth >= 860;
                          final scoreCard = _ScoreCard(
                            score: score,
                            elapsed: _elapsedLabel,
                            accuracyShort: _accuracyShort,
                          );
                          final rewardCard = _RewardCard(
                            xpGained: xpGained,
                            title: _rewardTitle,
                            subtitle: _rewardSubtitle(level, xp),
                            level: lv,
                            xp: curXp,
                            bar: bar,
                          );
                          if (wide) {
                            return Row(
                              children: [
                                Expanded(flex: 7, child: scoreCard),
                                const SizedBox(width: 16),
                                Expanded(flex: 5, child: rewardCard),
                              ],
                            );
                          }
                          return Column(
                            children: [
                              scoreCard,
                              const SizedBox(height: 16),
                              rewardCard,
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 16),
                      LayoutBuilder(
                        builder: (context, c) {
                          final wide = c.maxWidth >= 860;
                          final breakdown = _BreakdownCard(
                            correct: _derivedCorrect,
                            incorrect: _incorrect,
                          );
                          final insight = const _InsightCard();
                          if (wide) {
                            return Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(flex: 8, child: breakdown),
                                const SizedBox(width: 16),
                                Expanded(flex: 4, child: insight),
                              ],
                            );
                          }
                          return Column(
                            children: [
                              breakdown,
                              const SizedBox(height: 16),
                              insight,
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 22),
                      _ActionRow(
                        canRetry: topicId != null,
                        onRetry: topicId == null
                            ? null
                            : () {
                                Navigator.pushNamedAndRemoveUntil(
                                  context,
                                  AppRoutes.learnerQuiz,
                                  (r) => false,
                                  arguments: {'topicId': topicId},
                                );
                              },
                        onBackToTopics: () => Navigator.pushNamedAndRemoveUntil(
                          context,
                          AppRoutes.learnerTopics,
                          (r) => false,
                        ),
                      ),
                      const SizedBox(height: 28),
                      _QuickReviewHeader(
                        count: missed.length,
                        onViewAll: missed.isEmpty
                            ? null
                            : () => showModalBottomSheet<void>(
                                  context: context,
                                  showDragHandle: true,
                                  builder: (sheetCtx) => _AllErrorsSheet(
                                    words: missed,
                                  ),
                                ),
                      ),
                      const SizedBox(height: 12),
                      if (missed.isEmpty)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(18),
                          decoration: LearnerDecorations.cardSurface(radius: 14),
                          child: Text(
                            _incorrect == 0
                                ? 'Không có từ sai — xuất sắc!'
                                : 'Chưa có danh sách từ sai cho phiên này.',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        )
                      else
                        ...missed.take(6).map(
                              (w) => Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: _MissedWordTile(word: w),
                              ),
                            ),
                      const SizedBox(height: 16),
                      const FluidLearnerPageFooter(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Giữ tương thích với code cũ (không dùng trong UI mới).
}

class _QuizResultsTopBar extends StatelessWidget implements PreferredSizeWidget {
  const _QuizResultsTopBar({required this.onClose});

  final VoidCallback onClose;

  @override
  Size get preferredSize => const Size.fromHeight(64);

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    return Material(
      color: Colors.white.withValues(alpha: 0.88),
      elevation: 0,
      shadowColor: AppColors.primary.withValues(alpha: 0.06),
      child: SafeArea(
        bottom: false,
        child: Container(
          height: 64,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'The Fluid Scholar',
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w900,
                    fontSize: w >= 400 ? 20 : 17,
                    letterSpacing: -0.8,
                    color: AppColors.primaryContainer,
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
              const SizedBox(width: 4),
              InkWell(
                onTap: onClose,
                borderRadius: BorderRadius.circular(999),
                child: CircleAvatar(
                  radius: 16,
                  backgroundColor: AppColors.surfaceContainerHighest,
                  child: Icon(
                    Icons.person_rounded,
                    color: AppColors.primaryContainer,
                    size: 20,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ConfettiBackdrop extends StatelessWidget {
  const _ConfettiBackdrop({required this.opacity});

  final double opacity;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(
        painter: _ConfettiPainter(opacity: opacity),
      ),
    );
  }
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter({required this.opacity});

  final double opacity;

  @override
  void paint(Canvas canvas, Size size) {
    final paints = [
      Paint()..color = AppColors.primaryContainer.withValues(alpha: opacity),
      Paint()..color = AppColors.secondaryFixed.withValues(alpha: opacity),
      Paint()..color = const Color(0xFFFFB95F).withValues(alpha: opacity),
      Paint()..color = AppColors.primary.withValues(alpha: opacity),
    ];

    final dots = <Offset>[
      Offset(size.width * 0.20, size.height * 0.22),
      Offset(size.width * 0.72, size.height * 0.10),
      Offset(size.width * 0.90, size.height * 0.64),
      Offset(size.width * 0.08, size.height * 0.78),
      Offset(size.width * 0.40, size.height * 0.12),
      Offset(size.width * 0.58, size.height * 0.34),
      Offset(size.width * 0.14, size.height * 0.44),
      Offset(size.width * 0.86, size.height * 0.28),
    ];
    for (var i = 0; i < dots.length; i++) {
      final p = paints[i % paints.length];
      canvas.drawCircle(dots[i], 1.4 + (i % 3) * 0.6, p);
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter oldDelegate) =>
      oldDelegate.opacity != opacity;
}

class _CelebrationHeader extends StatelessWidget {
  const _CelebrationHeader({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: AppColors.secondaryFixed.withValues(alpha: 0.30),
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.auto_awesome_rounded,
            size: 40,
            color: AppColors.secondary,
          ),
        ),
        const SizedBox(height: 14),
        Text(
          title,
          textAlign: TextAlign.center,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 40,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.9,
            color: AppColors.onSurface,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: AppColors.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _ScoreCard extends StatelessWidget {
  const _ScoreCard({
    required this.score,
    required this.elapsed,
    required this.accuracyShort,
  });

  final int score;
  final String elapsed;
  final String accuracyShort;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(26),
      decoration: LearnerDecorations.cardSurface(radius: 16),
      child: Stack(
        children: [
          Positioned(
            top: -60,
            right: -60,
            child: Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary.withValues(alpha: 0.06),
              ),
            ),
          ),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'MỨC THÀNH THẠO',
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                  color: const Color(0xFF777587),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    '$score',
                    style: GoogleFonts.robotoMono(
                      fontSize: 88,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -2,
                      color: AppColors.primary,
                      height: 1,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '%',
                    style: GoogleFonts.robotoMono(
                      fontSize: 38,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary.withValues(alpha: 0.55),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Wrap(
                spacing: 28,
                runSpacing: 12,
                alignment: WrapAlignment.center,
                children: [
                  _TinyMeta(label: 'THỜI GIAN', value: elapsed),
                  _TinyMeta(label: 'ĐỘ CHÍNH XÁC', value: accuracyShort),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TinyMeta extends StatelessWidget {
  const _TinyMeta({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: GoogleFonts.spaceGrotesk(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
            color: const Color(0xFF777587),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: GoogleFonts.robotoMono(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: AppColors.onSurface,
          ),
        ),
      ],
    );
  }
}

class _RewardCard extends StatelessWidget {
  const _RewardCard({
    required this.xpGained,
    required this.title,
    required this.subtitle,
    required this.level,
    required this.xp,
    required this.bar,
  });

  final int xpGained;
  final String title;
  final String subtitle;
  final int level;
  final int xp;
  final double bar;

  @override
  Widget build(BuildContext context) {
    final nextXp = level * 500;
    final base = xp - (xp % 500);
    final inLevel = xp % 500;
    final cur = base + inLevel;
    final end = base + nextXp;
    return Container(
      padding: const EdgeInsets.all(26),
      decoration: LearnerDecorations.primaryHero(radius: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'PHẦN THƯỞNG NHẬN ĐƯỢC',
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                  color: const Color(0xFFE2DFFF),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.20),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '+$xpGained XP',
                  style: GoogleFonts.robotoMono(
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              letterSpacing: -0.6,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: GoogleFonts.inter(
              fontSize: 13,
              height: 1.4,
              color: const Color(0xFFE2DFFF),
            ),
          ),
          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'CẤP $level',
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                  color: const Color(0xFFE2DFFF),
                ),
              ),
              Text(
                '${QuizResultsScreen._formatInt(cur)} / ${QuizResultsScreen._formatInt(end)} XP',
                style: GoogleFonts.robotoMono(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: SizedBox(
              height: 10,
              child: LinearProgressIndicator(
                value: bar.clamp(0.0, 1.0),
                backgroundColor: Colors.white.withValues(alpha: 0.25),
                valueColor: const AlwaysStoppedAnimation<Color>(
                  AppColors.secondaryFixed,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BreakdownCard extends StatelessWidget {
  const _BreakdownCard({required this.correct, required this.incorrect});

  final int correct;
  final int incorrect;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
      ),
      child: LayoutBuilder(
        builder: (context, c) {
          final col = c.maxWidth < 520;
          final children = [
            _ResultChip(
              icon: Icons.check_circle_rounded,
              iconBg: AppColors.secondary.withValues(alpha: 0.10),
              iconColor: AppColors.secondary,
              value: correct.toString(),
              label: 'ĐÚNG',
            ),
            _ResultChip(
              icon: Icons.cancel_rounded,
              iconBg: AppColors.error.withValues(alpha: 0.10),
              iconColor: AppColors.error,
              value: incorrect.toString().padLeft(2, '0'),
              label: 'SAI',
            ),
          ];
          return col
              ? Column(
                  children: [
                    ...children.map((w) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: w,
                        )),
                    const _InsightMini(),
                  ],
                )
              : Row(
                  children: [
                    Expanded(child: children[0]),
                    const SizedBox(width: 12),
                    Expanded(child: children[1]),
                    const SizedBox(width: 12),
                    const Expanded(child: _InsightMini()),
                  ],
                );
        },
      ),
    );
  }
}

class _ResultChip extends StatelessWidget {
  const _ResultChip({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(icon, color: iconColor, size: 30),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: GoogleFonts.robotoMono(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: AppColors.onSurface,
                ),
              ),
              Text(
                label,
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                  color: const Color(0xFF777587),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InsightMini extends StatelessWidget {
  const _InsightMini();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: const Color(0xFFB45309).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(
              Icons.psychology_rounded,
              color: Color(0xFFB45309),
              size: 30,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Ghi nhớ tốt',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: AppColors.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Từ vựng mới',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                    color: const Color(0xFF777587),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InsightCard extends StatelessWidget {
  const _InsightCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(26),
      decoration: BoxDecoration(
        color: AppColors.tertiaryFixed,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.psychology_rounded,
            size: 40,
            color: Color(0xFF2A1700),
          ),
          const SizedBox(height: 10),
          Text(
            'Ghi nhớ tốt nhất',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: const Color(0xFF2A1700),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'TỪ VỰNG MỚI',
            style: GoogleFonts.spaceGrotesk(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.6,
              color: const Color(0xFF653E00),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.canRetry,
    required this.onRetry,
    required this.onBackToTopics,
  });

  final bool canRetry;
  final VoidCallback? onRetry;
  final VoidCallback onBackToTopics;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final row = c.maxWidth >= 560;
        final retry = _PillButton(
          filled: true,
          enabled: canRetry,
          icon: Icons.refresh_rounded,
          label: 'Làm lại quiz',
          onTap: onRetry,
        );
        final back = _PillButton(
          filled: false,
          enabled: true,
          icon: Icons.arrow_back_rounded,
          label: 'Quay về chủ đề',
          onTap: onBackToTopics,
        );
        return row
            ? Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Expanded(child: retry),
                  const SizedBox(width: 14),
                  Expanded(child: back),
                ],
              )
            : Column(
                children: [
                  retry,
                  const SizedBox(height: 12),
                  back,
                ],
              );
      },
    );
  }
}

class _PillButton extends StatelessWidget {
  const _PillButton({
    required this.filled,
    required this.enabled,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final bool filled;
  final bool enabled;
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final bg = filled ? AppColors.primary : AppColors.surfaceContainerHighest;
    final fg = filled ? Colors.white : const Color(0xFF3323CC);
    return Material(
      color: enabled ? bg : bg.withValues(alpha: 0.5),
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(999),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: fg),
              const SizedBox(width: 10),
              Text(
                label,
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w900,
                  color: fg,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickReviewHeader extends StatelessWidget {
  const _QuickReviewHeader({
    required this.count,
    required this.onViewAll,
  });

  final int count;
  final VoidCallback? onViewAll;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Ôn nhanh',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.4,
                  color: AppColors.onSurface,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                count == 0
                    ? 'Không có từ cần xem lại trong phiên này.'
                    : 'Các từ bạn gặp khó trong phiên vừa rồi.',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: AppColors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        TextButton(
          onPressed: onViewAll,
          child: Text(
            'XEM TẤT CẢ LỖI',
            style: GoogleFonts.spaceGrotesk(
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
              color: AppColors.primaryContainer,
              fontSize: 10,
            ),
          ),
        ),
      ],
    );
  }
}

class _MissedWordTile extends StatelessWidget {
  const _MissedWordTile({required this.word});

  final VocabularyModel word;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: LearnerDecorations.cardSurface(radius: 14),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.error.withValues(alpha: 0.10),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.close_rounded, color: AppColors.error),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  word.word,
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                    color: AppColors.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  word.meaning,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontStyle: FontStyle.italic,
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              'TỪ VỰNG',
              style: GoogleFonts.spaceGrotesk(
                fontSize: 9,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.1,
                color: AppColors.outlineVariant,
              ),
            ),
          ),
          IconButton(
            tooltip: 'Phát âm',
            onPressed: () {
              showAppSnackBar(
                context,
                'Phát âm (TTS) sẽ bổ sung sau.',
                kind: AppSnackKind.info,
              );
            },
            icon: Icon(
              Icons.volume_up_rounded,
              color: AppColors.primaryContainer,
            ),
          ),
        ],
      ),
    );
  }
}

class _AllErrorsSheet extends StatelessWidget {
  const _AllErrorsSheet({required this.words});

  final List<VocabularyModel> words;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        children: [
          Text(
            'Tất cả từ cần ôn (${words.length})',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          ...words.map((w) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _MissedWordTile(word: w),
              )),
        ],
      ),
    );
  }
}

// _MiniStat giữ lại ở phiên bản cũ (đã không dùng trong UI mới).
