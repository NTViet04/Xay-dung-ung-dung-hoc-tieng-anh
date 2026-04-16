import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_routes.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/json_convert.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../../../data/models/vocabulary_model.dart';
import '../../../../data/repositories/user_vocabulary_repository.dart';
import '../../../../data/repositories/vocabularies_repository.dart';
import '../../../auth/controllers/auth_provider.dart';
import '../../theme/learner_decorations.dart';
import '../../widgets/fluid_learner_app_bar.dart';
import '../../widgets/fluid_learner_page_footer.dart';
import '../../widgets/fluid_learner_top_nav.dart';

/// `arguments`: `{ topicId: int, startIndex?: int, topicName?: String }`
class FlashcardsScreen extends StatefulWidget {
  const FlashcardsScreen({super.key});

  @override
  State<FlashcardsScreen> createState() => _FlashcardsScreenState();
}

class _FlashcardsScreenState extends State<FlashcardsScreen> {
  Future<List<VocabularyModel>>? _future;
  final GlobalKey<_FlashSessionState> _sessionKey = GlobalKey();
  int? _topicId;
  int _start = 0;
  String _topicName = 'Chủ đề';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map) {
      final tid = args['topicId'];
      if (tid is num) {
        _topicId = tid.toInt();
      }
      final si = args['startIndex'];
      if (si is num) {
        _start = si.toInt();
      }
      final tn = args['topicName'];
      if (tn is String && tn.isNotEmpty) {
        _topicName = tn;
      }
    }
    if (_topicId != null) {
      _future ??=
          context.read<VocabulariesRepository>().fetchByTopic(_topicId!);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_topicId == null) {
      return Scaffold(
        backgroundColor: AppColors.surface,
        appBar: const FluidLearnerAppBar(subtitle: 'Thẻ ghi nhớ'),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Hãy mở thẻ ghi nhớ từ danh sách từ vựng của một chủ đề.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ),
        ),
      );
    }

    final showAdminEntry =
        context.select<AuthProvider, bool>((a) => a.user?.isAdmin == true);

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: FluidLearnerTopNav(
        currentIndex: 1,
        leading: IconButton(
          tooltip: 'Đóng phiên',
          onPressed: () async {
            await _sessionKey.currentState?.onUserExit();
            if (context.mounted) {
              Navigator.pop(context);
            }
          },
          icon: const Icon(Icons.close_rounded),
          color: const Color(0xFF64748B),
        ),
        extraActions: [
          if (showAdminEntry)
            IconButton(
              tooltip: 'Admin',
              icon: const Icon(Icons.admin_panel_settings_outlined),
              onPressed: () =>
                  Navigator.pushNamed(context, AppRoutes.adminDashboard),
            ),
        ],
      ),
      body: FutureBuilder<List<VocabularyModel>>(
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
          final list = snap.data ?? [];
          if (list.isEmpty) {
            return const Center(child: Text('Không có từ trong chủ đề này.'));
          }
          final initial = _start.clamp(0, list.length - 1);
          return _FlashSession(
            key: _sessionKey,
            list: list,
            initialIndex: initial,
            topicLabel: _topicName,
            sessionTitle: _topicName,
          );
        },
      ),
    );
  }
}

class _FlashSession extends StatefulWidget {
  const _FlashSession({
    super.key,
    required this.list,
    required this.initialIndex,
    required this.topicLabel,
    required this.sessionTitle,
  });

  final List<VocabularyModel> list;
  final int initialIndex;
  final String topicLabel;
  final String sessionTitle;

  @override
  State<_FlashSession> createState() => _FlashSessionState();
}

class _FlashSessionState extends State<_FlashSession>
    with SingleTickerProviderStateMixin {
  late final PageController _pageController;
  late int _index;
  final Map<int, bool> _flipped = {};
  late AnimationController _flipController;

  final Set<int> _preMastered = {};
  final Set<int> _actionIds = {};
  bool _sessionComplete = false;
  bool _startedPreload = false;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex;
    _pageController = PageController(initialPage: _index);
    _flipController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _syncFlipController();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_startedPreload) {
      return;
    }
    _startedPreload = true;
    _loadPreMastered();
  }

  Future<void> _loadPreMastered() async {
    try {
      final mine = await context.read<UserVocabularyRepository>().fetchMine();
      if (!mounted) {
        return;
      }
      setState(() {
        for (final row in mine) {
          if (row['status'] == 'mastered') {
            final vid = parseJsonInt(row['vocab_id']);
            if (vid != null) {
              _preMastered.add(vid);
            }
          }
        }
      });
    } catch (_) {}
  }

  Future<void> onUserExit() async {
    if (_sessionComplete) {
      return;
    }
    await _flushPartialSession();
  }

  Future<void> _flushPartialSession() async {
    final repo = context.read<UserVocabularyRepository>();
    final now = DateTime.now();
    final futures = <Future<void>>[];
    for (var i = 0; i <= _index; i++) {
      final id = widget.list[i].id;
      if (_actionIds.contains(id)) {
        continue;
      }
      if (_preMastered.contains(id)) {
        continue;
      }
      futures.add(
        Future<void>(() async {
          try {
            await repo.upsert(
              vocabId: id,
              status: 'learning',
              lastReview: now,
            );
          } catch (_) {}
        }),
      );
    }
    await Future.wait(futures);
  }

  void _syncFlipController() {
    _flipController.value = (_flipped[_index] ?? false) ? 1.0 : 0.0;
  }

  @override
  void dispose() {
    _pageController.dispose();
    _flipController.dispose();
    super.dispose();
  }

  void _toggleFlip() {
    if (_flipController.isAnimating) {
      return;
    }
    if (_flipController.value < 0.5) {
      _flipController.forward();
      _flipped[_index] = true;
    } else {
      _flipController.reverse();
      _flipped[_index] = false;
    }
  }

  Future<void> _reviewAgain() async {
    final id = widget.list[_index].id;
    try {
      await context.read<UserVocabularyRepository>().upsert(
            vocabId: id,
            status: 'learning',
            lastReview: DateTime.now(),
          );
      _actionIds.add(id);
    } catch (_) {}
    if (!mounted) {
      return;
    }
    setState(() {
      _flipped[_index] = false;
      _flipController.reverse();
    });
  }

  Future<void> _know() async {
    final id = widget.list[_index].id;
    try {
      await context.read<UserVocabularyRepository>().upsert(
            vocabId: id,
            status: 'mastered',
            lastReview: DateTime.now(),
          );
      _actionIds.add(id);
    } catch (_) {}
    if (!mounted) {
      return;
    }

    final isLast = _index >= widget.list.length - 1;
    if (isLast) {
      await _flushPartialSession();
      _sessionComplete = true;
      if (!mounted) {
        return;
      }
      showAppSnackBar(
        context,
        'Hoàn thành phiên ôn tập!',
        kind: AppSnackKind.success,
      );
      Navigator.pop(context);
      return;
    }
    _pageController.nextPage(
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  String _topicTag() {
    final t = widget.topicLabel.trim();
    if (t.isEmpty) {
      return 'TỪ VỰNG';
    }
    return t.length > 24 ? '${t.substring(0, 21)}…' : t;
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.list.length;
    final progress = (_index + 1) / total;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) {
          return;
        }
        await onUserExit();
        if (context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 900),
              child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'PHIÊN HỌC HIỆN TẠI',
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.4,
                          color: AppColors.primaryContainer,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(
                            child: Text(
                              widget.sessionTitle,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.5,
                                color: AppColors.onSurface,
                              ),
                            ),
                          ),
                          Text(
                            '${_index + 1}',
                            style: GoogleFonts.spaceGrotesk(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: AppColors.primaryContainer,
                            ),
                          ),
                          Text(
                            ' / $total',
                            style: GoogleFonts.spaceGrotesk(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: AppColors.outlineVariant,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: SizedBox(
                          height: 8,
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              Container(
                                color: AppColors.surfaceContainerHighest,
                              ),
                              Align(
                                alignment: Alignment.centerLeft,
                                child: FractionallySizedBox(
                                  widthFactor: progress.clamp(0.0, 1.0),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(999),
                                      gradient: const LinearGradient(
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
                    ],
                  ),
                ),
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    itemCount: widget.list.length,
                    onPageChanged: (i) {
                      setState(() {
                        _index = i;
                        _flipped.putIfAbsent(i, () => false);
                        _syncFlipController();
                      });
                    },
                    itemBuilder: (context, i) {
                      final v = widget.list[i];
                      return Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 8,
                        ),
                        child: _FlashcardDeck(
                          vocabulary: v,
                          topicTag: _topicTag(),
                          flipController: _flipController,
                          isActivePage: i == _index,
                          staticShowBack: _flipped[i] ?? false,
                          onFlipTap: i == _index ? _toggleFlip : null,
                        ),
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 4, 24, 12),
                  child: LayoutBuilder(
                    builder: (context, c) {
                      final row = c.maxWidth >= 520;
                      if (row) {
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: _SessionActionTile(
                                title: 'Ôn lại',
                                subtitle: 'Tiếp tục luyện tập từ này',
                                icon: Icons.refresh_rounded,
                                onTap: () => _reviewAgain(),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _SessionActionTile(
                                title: 'Tôi đã biết',
                                subtitle: 'Đã nắm vững từ này',
                                icon: Icons.check_circle_rounded,
                                accentGreen: true,
                                onTap: () => _know(),
                              ),
                            ),
                          ],
                        );
                      }
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _SessionActionTile(
                            title: 'Ôn lại',
                            subtitle: 'Tiếp tục luyện tập từ này',
                            icon: Icons.refresh_rounded,
                            onTap: () => _reviewAgain(),
                          ),
                          const SizedBox(height: 12),
                          _SessionActionTile(
                            title: 'Tôi đã biết',
                            subtitle: 'Đã nắm vững từ này',
                            icon: Icons.check_circle_rounded,
                            accentGreen: true,
                            onTap: () => _know(),
                          ),
                        ],
                      );
                    },
                  ),
                ),
                const FluidLearnerPageFooter(),
              ],
            ),
          ),
        );
      },
    ),
    );
  }
}

/// Thẻ 3D + nội dung mặt trước / sau.
class _FlashcardDeck extends StatelessWidget {
  const _FlashcardDeck({
    required this.vocabulary,
    required this.topicTag,
    required this.flipController,
    required this.isActivePage,
    required this.staticShowBack,
    required this.onFlipTap,
  });

  final VocabularyModel vocabulary;
  final String topicTag;
  final AnimationController flipController;
  final bool isActivePage;
  /// Mặt sau tĩnh khi thẻ không phải trang đang xem (PageView).
  final bool staticShowBack;
  final VoidCallback? onFlipTap;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final h = math.min(420.0, constraints.maxHeight);
        return Center(
          child: SizedBox(
            height: h,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(
                  child: Transform.rotate(
                    angle: -0.035,
                    child: Container(
                      margin: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        color: AppColors.primary.withValues(alpha: 0.05),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.12),
                            blurRadius: 40,
                            spreadRadius: 0,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned.fill(
                  child: Material(
                    color: AppColors.surfaceContainerLowest,
                    elevation: 12,
                    shadowColor: AppColors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                    child: InkWell(
                      onTap: onFlipTap,
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        decoration: LearnerDecorations.cardSurface(radius: 20)
                            .copyWith(
                          border: Border.all(
                            color: AppColors.primary.withValues(alpha: 0.06),
                          ),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 32,
                        ),
                        child: isActivePage
                            ? AnimatedBuilder(
                                animation: flipController,
                                builder: (context, child) {
                                  final angle = flipController.value * math.pi;
                                  final showBack = angle > math.pi / 2;
                                  return Transform(
                                    alignment: Alignment.center,
                                    transform: Matrix4.identity()
                                      ..setEntry(3, 2, 0.001)
                                      ..rotateY(angle),
                                    child: showBack
                                        ? Transform(
                                            alignment: Alignment.center,
                                            transform: Matrix4.identity()
                                              ..rotateY(math.pi),
                                            child: _CardFace(
                                              vocabulary: vocabulary,
                                              topicTag: topicTag,
                                              showBack: true,
                                            ),
                                          )
                                        : _CardFace(
                                            vocabulary: vocabulary,
                                            topicTag: topicTag,
                                            showBack: false,
                                          ),
                                  );
                                },
                              )
                            : _CardFace(
                                vocabulary: vocabulary,
                                topicTag: topicTag,
                                showBack: staticShowBack,
                              ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 20,
                  right: 20,
                  child: IgnorePointer(
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 200),
                      opacity: 0.25,
                      child: Icon(
                        Icons.sync_rounded,
                        size: 40,
                        color: AppColors.primaryContainer,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _CardFace extends StatelessWidget {
  const _CardFace({
    required this.vocabulary,
    required this.topicTag,
    required this.showBack,
  });

  final VocabularyModel vocabulary;
  final String topicTag;
  final bool showBack;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFFE2DFFF),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            topicTag.toUpperCase(),
            style: GoogleFonts.spaceGrotesk(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 2,
              color: const Color(0xFF3323CC),
            ),
          ),
        ),
        const SizedBox(height: 24),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            showBack ? vocabulary.meaning : vocabulary.word,
            textAlign: TextAlign.center,
            maxLines: 3,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 44,
              fontWeight: FontWeight.w900,
              letterSpacing: -1,
              height: 1.05,
              color: AppColors.primary,
            ),
          ),
        ),
        if (showBack && vocabulary.pronunciation != null &&
            vocabulary.pronunciation!.trim().isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            vocabulary.pronunciation!,
            style: GoogleFonts.inter(
              fontSize: 16,
              color: AppColors.onSurfaceVariant,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.touch_app_rounded,
              size: 18,
              color: AppColors.outlineVariant,
            ),
            const SizedBox(width: 8),
            Text(
              showBack ? 'CHẠM ĐỂ XEM MẶT TRƯỚC' : 'CHẠM ĐỂ LẬT THẺ',
              style: GoogleFonts.spaceGrotesk(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.6,
                color: AppColors.outlineVariant,
              ),
            ),
          ],
        ),
        if (showBack && vocabulary.example != null &&
            vocabulary.example!.trim().isNotEmpty) ...[
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              '"${vocabulary.example}"',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 15,
                height: 1.45,
                fontStyle: FontStyle.italic,
                color: AppColors.primaryContainer,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _SessionActionTile extends StatelessWidget {
  const _SessionActionTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
    this.accentGreen = false,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;
  final bool accentGreen;

  @override
  Widget build(BuildContext context) {
    final bg = accentGreen
        ? AppColors.secondaryFixed.withValues(alpha: 0.22)
        : AppColors.surfaceContainerLow;

    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.transparent),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Icon(
                  icon,
                  color: accentGreen ? AppColors.secondary : const Color(0xFF885500),
                  size: 26,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  color: AppColors.onSurface,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  height: 1.35,
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
