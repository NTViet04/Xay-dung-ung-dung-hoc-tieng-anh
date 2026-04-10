import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../auth/controllers/auth_provider.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../../../data/models/quiz_bank_question_model.dart';
import '../../../../data/models/vocabulary_model.dart';
import '../../../../data/repositories/quiz_repository.dart';
import '../../controllers/learner_tab_index.dart';
import '../../quiz_results/views/quiz_results_screen.dart';
import '../../widgets/fluid_learner_app_bar.dart';
import '../../widgets/fluid_learner_page_footer.dart';

/// Quiz trắc nghiệm nghĩa — theo `quiz_screen/code.html` (The Fluid Scholar).
class QuizScreen extends StatefulWidget {
  const QuizScreen({super.key, required this.topicId});

  final int topicId;

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  static const _limit = 10;

  bool _isBank = false;
  List<VocabularyModel> _vocabQuestions = [];
  List<QuizBankQuestionModel> _bankQuestions = [];
  int _index = 0;

  int get _qLen => _isBank ? _bankQuestions.length : _vocabQuestions.length;
  int _correct = 0;
  final List<VocabularyModel> _missed = [];
  List<String> _options = [];
  String? _selected;
  bool _loading = true;
  String? _error;
  String? _topicName;
  Timer? _tick;
  final _stopwatch = Stopwatch();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final repo = context.read<QuizRepository>();
      final p = await repo.fetchQuestions(
        topicId: widget.topicId,
        limit: _limit,
      );
      _topicName = p.topicName;
      _isBank = p.isBank;
      if (p.isBank) {
        _bankQuestions = p.bankQuestions;
        _vocabQuestions = [];
        if (_bankQuestions.isEmpty) {
          setState(() {
            _error =
                'Chưa có câu hỏi trắc nghiệm trong ngân hàng. Admin cần thêm câu hỏi hoặc dùng chế độ từ vựng khi chưa có ngân hàng.';
            _loading = false;
          });
          return;
        }
      } else {
        _vocabQuestions = p.vocabQuestions;
        _bankQuestions = [];
        if (_vocabQuestions.isEmpty) {
          setState(() {
            _error = 'Chủ đề chưa có từ vựng để làm quiz.';
            _loading = false;
          });
          return;
        }
      }
      _buildOptions();
      _stopwatch.reset();
      _stopwatch.start();
      _tick?.cancel();
      _tick = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
      setState(() => _loading = false);
    } on ApiException catch (e) {
      setState(() {
        _error = e.message;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  void _buildOptions() {
    if (_isBank) {
      final q = _bankQuestions[_index];
      final pool = List<String>.from(q.options)..shuffle();
      _options = pool.take(4).toList();
      return;
    }
    final q = _vocabQuestions[_index];
    final pool = _vocabQuestions.map((e) => e.meaning).toList();
    final wrong = pool.where((m) => m != q.meaning).toList()..shuffle();
    final opts = <String>[q.meaning];
    var i = 0;
    while (opts.length < 4 && i < wrong.length) {
      if (!opts.contains(wrong[i])) {
        opts.add(wrong[i]);
      }
      i++;
    }
    while (opts.length < 4) {
      opts.add('(${Random().nextInt(999)})');
    }
    opts.shuffle();
    _options = opts.take(4).toList();
  }

  String get _elapsedLabel {
    final s = _stopwatch.elapsed.inSeconds;
    final m = s ~/ 60;
    final sec = s % 60;
    return '${m.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}';
  }

  /// Dòng in đậm (ưu tiên câu đầu nếu có dấu chấm).
  static String _optionTitle(String meaning) {
    final t = meaning.trim();
    final dot = t.indexOf('. ');
    if (dot > 8 && dot < t.length - 2) {
      return t.substring(0, dot + 1).trim();
    }
    if (t.length <= 56) return t;
    return '${t.substring(0, 53)}…';
  }

  static String _optionSubtitle(String meaning) {
    final t = meaning.trim();
    final dot = t.indexOf('. ');
    if (dot > 8 && dot < t.length - 2) {
      return t.substring(dot + 2).trim();
    }
    if (t.length > 56) return t.substring(53).trim();
    return '';
  }

  void _onNext() {
    if (_selected == null) {
      return;
    }
    final ok = _isBank
        ? _selected == _bankQuestions[_index].correctAnswerText
        : _selected == _vocabQuestions[_index].meaning;
    if (!ok) {
      if (!_isBank) {
        _missed.add(_vocabQuestions[_index]);
      }
    } else {
      _correct++;
    }

    if (_index >= _qLen - 1) {
      _finish();
      return;
    }
    setState(() {
      _index++;
      _selected = null;
      _buildOptions();
    });
  }

  void _skip() {
    if (_index >= _qLen - 1) {
      _finish();
      return;
    }
    setState(() {
      _index++;
      _selected = null;
      _buildOptions();
    });
  }

  Future<void> _finish() async {
    _tick?.cancel();
    final total = _qLen;
    final nav = Navigator.of(context);
    final quizRepo = context.read<QuizRepository>();
    final auth = context.read<AuthProvider>();
    try {
      final r = await quizRepo.submitResult(
        topicId: widget.topicId,
        totalQuestions: total,
        correctCount: _correct,
      );
      await auth.refreshProfile();
      if (!mounted) {
        return;
      }
      nav.pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => QuizResultsScreen(
            score: r.score,
            total: total,
            xpGained: r.xpGained,
            elapsed: _elapsedLabel,
            correctCount: _correct,
            level: r.level,
            xp: r.xp,
            topicId: widget.topicId,
            topicName: _topicName,
            missedWords: _missed,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }
      nav.pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => QuizResultsScreen(
            score: ((_correct * 100) / total).round(),
            total: total,
            xpGained: 0,
            elapsed: _elapsedLabel,
            correctCount: _correct,
            topicId: widget.topicId,
            topicName: _topicName,
            missedWords: _missed,
          ),
        ),
      );
    }
  }

  void _navToTab(int tab) {
    context.read<LearnerTabIndex>().goTo(tab);
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        backgroundColor: AppColors.surface,
        appBar: const FluidLearnerAppBar(subtitle: 'LexiFlow Quiz'),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null) {
      return Scaffold(
        backgroundColor: AppColors.surface,
        appBar: FluidLearnerAppBar(
          subtitle: 'LexiFlow Quiz',
          leading: IconButton(
            icon: const Icon(Icons.close_rounded),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: Center(child: Text(_error!)),
      );
    }
    final letters = ['A', 'B', 'C', 'D'];
    final progress = (_index + 1) / _qLen;
    final pct = (progress * 100).round();
    final unitLabel =
        'CHỦ ĐỀ · ${(_topicName ?? 'LexiFlow').toUpperCase()}';
    final isLast = _index >= _qLen - 1;

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: _QuizSessionAppBar(
        onBack: () => Navigator.pop(context),
        onGoTab: _navToTab,
        onNotifications: () {
          showAppSnackBar(
            context,
            'Chưa có thông báo mới.',
            kind: AppSnackKind.info,
          );
        },
        onSettings: () {
          showAppSnackBar(
            context,
            'Tài khoản nằm trong icon người (góc phải).',
            kind: AppSnackKind.info,
          );
        },
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
            children: [
              Text(
                unitLabel,
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.4,
                  color: AppColors.primaryContainer,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      'LexiFlow Quiz',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.6,
                        color: AppColors.onSurface,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.timer_rounded,
                          size: 20,
                          color: Colors.orange.shade600,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _elapsedLabel,
                          style: GoogleFonts.spaceGrotesk(
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                            color: AppColors.onSurface,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: SizedBox(
                  height: 12,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Container(color: AppColors.surfaceContainerHighest),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: FractionallySizedBox(
                          widthFactor: progress.clamp(0.0, 1.0),
                          child: Container(
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  AppColors.secondary,
                                  AppColors.primary,
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Câu ${_index + 1} / $_qLen',
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF777587),
                    ),
                  ),
                  Text(
                    '$pct% hoàn thành',
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF777587),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),
              _QuestionCard(
                isBank: _isBank,
                word: _isBank ? '' : _vocabQuestions[_index].word,
                prompt: _isBank ? _bankQuestions[_index].prompt : null,
              ),
              const SizedBox(height: 20),
              LayoutBuilder(
                builder: (context, c) {
                  final wide = c.maxWidth >= 560;
                  if (wide) {
                    return GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        mainAxisSpacing: 14,
                        crossAxisSpacing: 14,
                        mainAxisExtent: 132,
                      ),
                      itemCount: _options.length,
                      itemBuilder: (context, i) => _OptionTile(
                        letter: letters[i],
                        title: _isBank
                            ? _options[i].trim()
                            : _optionTitle(_options[i]),
                        subtitle:
                            _isBank ? '' : _optionSubtitle(_options[i]),
                        selected: _selected == _options[i],
                        onTap: () => setState(() => _selected = _options[i]),
                      ),
                    );
                  }
                  return Column(
                    children: List.generate(_options.length, (i) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _OptionTile(
                          letter: letters[i],
                          title: _isBank
                              ? _options[i].trim()
                              : _optionTitle(_options[i]),
                          subtitle:
                              _isBank ? '' : _optionSubtitle(_options[i]),
                          selected: _selected == _options[i],
                          onTap: () => setState(() => _selected = _options[i]),
                        ),
                      );
                    }),
                  );
                },
              ),
              const SizedBox(height: 28),
              LayoutBuilder(
                builder: (context, c) {
                  final row = c.maxWidth >= 560;
                  final skip = TextButton.icon(
                    onPressed: _skip,
                    icon: Icon(
                      Icons.skip_next_rounded,
                      color: AppColors.onSurfaceVariant,
                    ),
                    label: Text(
                      'Bỏ qua câu',
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w800,
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                  );
                  final next = Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: _selected == null ? null : _onNext,
                      borderRadius: BorderRadius.circular(999),
                      child: Ink(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [
                              AppColors.primary,
                              AppColors.primaryContainer,
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(999),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.25),
                              blurRadius: 20,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 28,
                          vertical: 16,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              isLast ? 'Nộp bài' : 'Câu tiếp theo',
                              style: GoogleFonts.plusJakartaSans(
                                fontWeight: FontWeight.w900,
                                fontSize: 17,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 10),
                            const Icon(
                              Icons.arrow_forward_rounded,
                              color: Colors.white,
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                  if (row) {
                    return Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        skip,
                        next,
                      ],
                    );
                  }
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      skip,
                      const SizedBox(height: 12),
                      Align(alignment: Alignment.centerRight, child: next),
                    ],
                  );
                },
              ),
              SizedBox(height: 24 + MediaQuery.paddingOf(context).bottom),
              const FluidLearnerPageFooter(),
            ],
          ),
        ),
      ),
    );
  }
}

/// Thanh trên: quay lại + logo + (rộng) điều hướng + chuông + cài đặt — tab Chủ đề đang chọn.
class _QuizSessionAppBar extends StatelessWidget implements PreferredSizeWidget {
  const _QuizSessionAppBar({
    required this.onBack,
    required this.onGoTab,
    required this.onNotifications,
    required this.onSettings,
  });

  final VoidCallback onBack;
  final void Function(int tabIndex) onGoTab;
  final VoidCallback onNotifications;
  final VoidCallback onSettings;

  static const _breakNav = 720.0;

  @override
  Size get preferredSize => const Size.fromHeight(64);

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    final showNav = w >= _breakNav;

    return Material(
      color: Colors.white.withValues(alpha: 0.88),
      elevation: 0,
      shadowColor: AppColors.primary.withValues(alpha: 0.06),
      child: SafeArea(
        bottom: false,
        child: Container(
          height: 64,
          padding: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.05),
                blurRadius: 8,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Row(
            children: [
              IconButton(
                tooltip: 'Thoát quiz',
                onPressed: onBack,
                icon: const Icon(Icons.arrow_back_rounded),
                color: const Color(0xFF64748B),
              ),
              Expanded(
                child: showNav
                    ? Row(
                        children: [
                          Text(
                            'The Fluid Scholar',
                            style: GoogleFonts.plusJakartaSans(
                              fontWeight: FontWeight.w900,
                              fontSize: w >= 400 ? 19 : 16,
                              letterSpacing: -0.8,
                              color: AppColors.primaryContainer,
                            ),
                          ),
                          Expanded(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                _QuizNavLink(
                                  label: 'Trang chủ',
                                  selected: false,
                                  onTap: () => onGoTab(0),
                                ),
                                _QuizNavLink(
                                  label: 'Chủ đề',
                                  selected: true,
                                  onTap: () => onGoTab(1),
                                ),
                                _QuizNavLink(
                                  label: 'Tiến độ',
                                  selected: false,
                                  onTap: () => onGoTab(2),
                                ),
                                _QuizNavLink(
                                  label: 'Hồ sơ',
                                  selected: false,
                                  onTap: () => onGoTab(3),
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
                          fontSize: 17,
                          letterSpacing: -0.8,
                          color: AppColors.primaryContainer,
                        ),
                      ),
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
            ],
          ),
        ),
      ),
    );
  }
}

class _QuizNavLink extends StatelessWidget {
  const _QuizNavLink({
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
                      ? AppColors.primaryContainer
                      : const Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 4),
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                height: 2,
                width: selected ? 28 : 0,
                decoration: BoxDecoration(
                  color: AppColors.primaryContainer,
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

class _QuestionCard extends StatelessWidget {
  const _QuestionCard({
    required this.isBank,
    required this.word,
    this.prompt,
  });

  final bool isBank;
  final String word;
  final String? prompt;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(22, 22, 22, 26),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryContainer.withValues(alpha: 0.06),
            blurRadius: 24,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned(
            top: -40,
            right: -40,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary.withValues(alpha: 0.05),
              ),
            ),
          ),
          if (isBank)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'TRẮC NGHIỆM',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  prompt ?? '',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    height: 1.45,
                    color: AppColors.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Chọn một đáp án đúng bên dưới.',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
              ],
            )
          else
            Text.rich(
              TextSpan(
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  height: 1.45,
                  color: AppColors.onSurface,
                ),
                children: [
                  const TextSpan(
                    text: 'Chọn nghĩa đúng cho từ ',
                  ),
                  WidgetSpan(
                    alignment: PlaceholderAlignment.baseline,
                    baseline: TextBaseline.alphabetic,
                    child: Text(
                      '“$word”',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: AppColors.primaryContainer,
                        decoration: TextDecoration.underline,
                        decorationColor: const Color(0xFFE2DFFF),
                        decorationThickness: 3,
                        height: 1.45,
                      ),
                    ),
                  ),
                  const TextSpan(text: ' trong ngữ cảnh học tập của bạn.'),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.letter,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final String letter;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceContainerLowest,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected
                  ? AppColors.primaryContainer
                  : Colors.transparent,
              width: selected ? 2 : 0,
            ),
            color: selected
                ? AppColors.surfaceContainerLowest
                : AppColors.surfaceContainerLowest,
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ]
                : null,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 46,
                height: 46,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: selected
                      ? AppColors.primaryContainer
                      : AppColors.surfaceContainerHighest,
                ),
                child: Text(
                  letter,
                  style: GoogleFonts.spaceGrotesk(
                    fontWeight: FontWeight.w800,
                    fontSize: 17,
                    color: selected ? Colors.white : AppColors.onSurface,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.onSurface,
                        height: 1.25,
                      ),
                    ),
                    if (subtitle.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          height: 1.35,
                          color: const Color(0xFF777587),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (selected)
                Icon(
                  Icons.check_circle_rounded,
                  color: AppColors.primaryContainer,
                  size: 26,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
