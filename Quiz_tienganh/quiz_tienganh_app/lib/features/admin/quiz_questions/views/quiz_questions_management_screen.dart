import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/json_convert.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../../../data/models/topic_model.dart';
import '../../../../data/repositories/quiz_bank_admin_repository.dart';
import '../../../../data/repositories/topics_repository.dart';
import '../../shell/admin_scaffold.dart';
import '../../widgets/admin_delete_dialog.dart';
import '../../widgets/admin_page_footer.dart';

/// Admin: CRUD câu hỏi trắc nghiệm — tải toàn bộ từ API, lọc theo chủ đề trên client.
class QuizQuestionsManagementScreen extends StatefulWidget {
  const QuizQuestionsManagementScreen({super.key});

  @override
  State<QuizQuestionsManagementScreen> createState() =>
      _QuizQuestionsManagementScreenState();
}

class _QuizQuestionsManagementScreenState
    extends State<QuizQuestionsManagementScreen> {
  List<TopicModel> _topics = [];
  List<Map<String, dynamic>> _allQuestions = [];
  int? _filterTopicId;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final topicsRepo = context.read<TopicsRepository>();
    final bank = context.read<QuizBankAdminRepository>();
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final topics = await topicsRepo.fetchTopics();
      final all = await bank.listAll();
      if (!mounted) {
        return;
      }
      setState(() {
        _topics = topics;
        _allQuestions = all;
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = '$e';
        });
      }
    }
  }

  List<Map<String, dynamic>> get _filtered {
    final tid = _filterTopicId;
    if (tid == null) {
      return _allQuestions;
    }
    return _allQuestions
        .where((q) => (parseJsonInt(q['topic_id']) ?? -1) == tid)
        .toList();
  }

  Future<void> _openEditor({Map<String, dynamic>? row}) async {
    final topics = _topics;
    if (topics.isEmpty) {
      showAppSnackBar(
        context,
        'Chưa có chủ đề trên hệ thống.',
        kind: AppSnackKind.warning,
      );
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      barrierColor: const Color(0xFF0F172A).withValues(alpha: 0.55),
      builder: (ctx) => _QuizQuestionEditorDialog(
        topics: topics,
        editing: row,
        defaultTopicId: _filterTopicId,
      ),
    );
    if (ok == true && mounted) {
      showAppSnackBar(context, 'Đã lưu.', kind: AppSnackKind.success);
      await _load();
    }
  }

  Future<void> _confirmDelete(Map<String, dynamic> row) async {
    final id = parseJsonInt(row['id']);
    if (id == null) {
      return;
    }
    final preview = '${row['prompt']}'.trimLeft().split('\n').first;
    final short = preview.length > 80 ? '${preview.substring(0, 77)}…' : preview;
    final ok = await showAdminDeleteDialog(
      context: context,
      title: 'Xóa câu hỏi quiz?',
      message: 'Câu hỏi sẽ biến mất khỏi ngân hàng và không còn trong quiz chủ đề.',
      highlight: short.isEmpty ? 'ID #$id' : short,
      confirmLabel: 'Xóa câu',
    );
    if (!ok || !mounted) {
      return;
    }
    try {
      await context.read<QuizBankAdminRepository>().delete(id);
      if (mounted) {
        showAppSnackBar(context, 'Đã xóa.', kind: AppSnackKind.success);
        await _load();
      }
    } catch (e) {
      if (mounted) {
        showAppSnackBar(context, '$e', kind: AppSnackKind.warning);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    return AdminScaffold(
      title: 'Ngân hàng câu hỏi quiz',
      showInnerHeader: false,
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                        child: LayoutBuilder(
                          builder: (context, c) {
                            final narrow = c.maxWidth < 720;
                            final titleBlock = Column(
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
                                      'NGÂN HÀNG QUIZ',
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
                                  'Ngân hàng câu hỏi',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 28,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.onSurface,
                                    height: 1.1,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  '${_allQuestions.length} câu trong hệ thống · trắc nghiệm 4 phương án',
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    color: const Color(0xFF64748B),
                                    height: 1.4,
                                  ),
                                ),
                              ],
                            );
                            final addBtn = FilledButton.icon(
                              onPressed:
                                  _topics.isEmpty ? null : () => _openEditor(),
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
                                shadowColor:
                                    AppColors.primary.withValues(alpha: 0.25),
                              ),
                              icon: const Icon(Icons.add_rounded, size: 20),
                              label: Text(
                                'Thêm câu mới',
                                style: GoogleFonts.plusJakartaSans(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            );
                            if (narrow) {
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  titleBlock,
                                  const SizedBox(height: 14),
                                  addBtn,
                                ],
                              );
                            }
                            return Row(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Expanded(child: titleBlock),
                                addBtn,
                              ],
                            );
                          },
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
                        child: Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceContainerLow,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.7),
                            ),
                          ),
                          child: _topics.isEmpty
                              ? Text(
                                  'Chưa có chủ đề — tạo chủ đề trước khi thêm câu.',
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    color: const Color(0xFF64748B),
                                  ),
                                )
                              : Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
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
                                    const SizedBox(height: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: DropdownButtonHideUnderline(
                                        child: DropdownButton<int?>(
                                          isExpanded: true,
                                          value: _filterTopicId != null &&
                                                  _topics.any(
                                                    (t) =>
                                                        t.id == _filterTopicId,
                                                  )
                                              ? _filterTopicId
                                              : null,
                                          items: [
                                            const DropdownMenuItem<int?>(
                                              value: null,
                                              child: Text('Tất cả chủ đề'),
                                            ),
                                            ..._topics.map(
                                              (t) => DropdownMenuItem<int?>(
                                                value: t.id,
                                                child: Text(
                                                  t.name,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ),
                                          ],
                                          onChanged: (v) =>
                                              setState(() => _filterTopicId = v),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                      if (_error != null)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Text(
                            _error!,
                            style: const TextStyle(color: AppColors.error),
                          ),
                        ),
                      Expanded(
                        child: filtered.isEmpty
                            ? Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(32),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.quiz_outlined,
                                        size: 56,
                                        color: AppColors.outlineVariant,
                                      ),
                                      const SizedBox(height: 16),
                                      Text(
                                        _allQuestions.isEmpty
                                            ? 'Chưa có câu hỏi trong CSDL. Thêm câu hoặc import lại schema (bảng quiz_questions).'
                                            : 'Không có câu nào cho bộ lọc hiện tại.',
                                        textAlign: TextAlign.center,
                                        style: GoogleFonts.inter(
                                          fontSize: 15,
                                          height: 1.45,
                                          color: const Color(0xFF64748B),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                            : ListView.separated(
                                padding:
                                    const EdgeInsets.fromLTRB(24, 0, 24, 16),
                                itemCount: filtered.length,
                                separatorBuilder: (context, index) =>
                                    const SizedBox(height: 12),
                                itemBuilder: (context, i) {
                                  final q = filtered[i];
                                  final idx =
                                      parseJsonInt(q['correct_index']) ?? 0;
                                  const letters = ['A', 'B', 'C', 'D'];
                                  final topicLabel =
                                      '${q['topic_name'] ?? '?'} · ID #${q['id']}';
                                  final preview = '${q['prompt']}'
                                      .trimLeft()
                                      .split('\n')
                                      .first;
                                  final short = preview.length > 140
                                      ? '${preview.substring(0, 137)}…'
                                      : preview;
                                  return Material(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(16),
                                    elevation: 0,
                                    child: Container(
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(
                                          color: const Color(0xFFE2E8F0),
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withValues(
                                              alpha: 0.05,
                                            ),
                                            blurRadius: 12,
                                            offset: const Offset(0, 4),
                                          ),
                                        ],
                                      ),
                                      clipBehavior: Clip.antiAlias,
                                      child: IntrinsicHeight(
                                        child: Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.stretch,
                                          children: [
                                            Container(
                                              width: 4,
                                              color: AppColors.primaryContainer
                                                  .withValues(alpha: 0.85),
                                            ),
                                            Expanded(
                                              child: Padding(
                                                padding:
                                                    const EdgeInsets.fromLTRB(
                                                  16,
                                                  16,
                                                  8,
                                                  16,
                                                ),
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      topicLabel,
                                                      style: GoogleFonts
                                                          .spaceGrotesk(
                                                        fontSize: 10,
                                                        fontWeight:
                                                            FontWeight.w800,
                                                        letterSpacing: 0.6,
                                                        color: AppColors
                                                            .primaryContainer,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 6),
                                                    Text(
                                                      short,
                                                      style: GoogleFonts
                                                          .plusJakartaSans(
                                                        fontWeight:
                                                            FontWeight.w700,
                                                        fontSize: 15,
                                                        height: 1.35,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 8),
                                                    Text(
                                                      'Đáp án đúng: ${letters[idx.clamp(0, 3)]} · Thứ tự ${parseJsonInt(q['sort_order']) ?? 0}',
                                                      style: GoogleFonts.inter(
                                                        fontSize: 12,
                                                        color: const Color(
                                                          0xFF64748B,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                            IconButton(
                                              tooltip: 'Sửa',
                                              icon: const Icon(
                                                Icons.edit_rounded,
                                              ),
                                              color: AppColors.primaryContainer,
                                              onPressed: () =>
                                                  _openEditor(row: q),
                                            ),
                                            IconButton(
                                              tooltip: 'Xóa',
                                              icon: const Icon(
                                                Icons.delete_outline_rounded,
                                              ),
                                              color: const Color(0xFF94A3B8),
                                              onPressed: () =>
                                                  _confirmDelete(q),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                ),
                const AdminPageFooter(),
              ],
            ),
    );
  }
}

InputDecoration _quizFieldDeco(String label, {bool alignHint = false}) {
  return InputDecoration(
    labelText: label,
    alignLabelWithHint: alignHint,
    filled: true,
    fillColor: const Color(0xFFF8FAFC),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide.none,
    ),
  );
}

class _QuizQuestionEditorDialog extends StatefulWidget {
  const _QuizQuestionEditorDialog({
    required this.topics,
    this.editing,
    this.defaultTopicId,
  });

  final List<TopicModel> topics;
  final Map<String, dynamic>? editing;
  final int? defaultTopicId;

  @override
  State<_QuizQuestionEditorDialog> createState() =>
      _QuizQuestionEditorDialogState();
}

class _QuizQuestionEditorDialogState extends State<_QuizQuestionEditorDialog> {
  late final TextEditingController _prompt;
  late final TextEditingController _a;
  late final TextEditingController _b;
  late final TextEditingController _c;
  late final TextEditingController _d;
  late final TextEditingController _expl;
  late final TextEditingController _sort;
  late int _topicId;
  late int _correct;

  @override
  void initState() {
    super.initState();
    final row = widget.editing;
    _prompt = TextEditingController(text: '${row?['prompt'] ?? ''}');
    _a = TextEditingController(text: '${row?['option_a'] ?? ''}');
    _b = TextEditingController(text: '${row?['option_b'] ?? ''}');
    _c = TextEditingController(text: '${row?['option_c'] ?? ''}');
    _d = TextEditingController(text: '${row?['option_d'] ?? ''}');
    _expl = TextEditingController(text: '${row?['explanation'] ?? ''}');
    _sort = TextEditingController(
      text: '${parseJsonInt(row?['sort_order']) ?? 0}',
    );
    _topicId = parseJsonInt(row?['topic_id']) ??
        widget.defaultTopicId ??
        widget.topics.first.id;
    _correct = parseJsonInt(row?['correct_index'])?.clamp(0, 3) ?? 0;
  }

  @override
  void dispose() {
    _prompt.dispose();
    _a.dispose();
    _b.dispose();
    _c.dispose();
    _d.dispose();
    _expl.dispose();
    _sort.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final prompt = _prompt.text.trim();
    final a = _a.text.trim();
    final b = _b.text.trim();
    final c = _c.text.trim();
    final d = _d.text.trim();
    final sort = int.tryParse(_sort.text.trim()) ?? 0;
    final expl = _expl.text.trim();

    if (prompt.isEmpty || a.isEmpty || b.isEmpty || c.isEmpty || d.isEmpty) {
      showAppSnackBar(
        context,
        'Điền đủ câu hỏi và 4 đáp án.',
        kind: AppSnackKind.warning,
      );
      return;
    }

    final bank = context.read<QuizBankAdminRepository>();
    final row = widget.editing;

    try {
      if (row == null) {
        await bank.create(
          topicId: _topicId,
          prompt: prompt,
          optionA: a,
          optionB: b,
          optionC: c,
          optionD: d,
          correctIndex: _correct,
          explanation: expl.isEmpty ? null : expl,
          sortOrder: sort,
        );
      } else {
        final id = parseJsonInt(row['id']) ?? 0;
        final oldTid = parseJsonInt(row['topic_id']);
        if (oldTid != _topicId) {
          await bank.delete(id);
          await bank.create(
            topicId: _topicId,
            prompt: prompt,
            optionA: a,
            optionB: b,
            optionC: c,
            optionD: d,
            correctIndex: _correct,
            explanation: expl.isEmpty ? null : expl,
            sortOrder: sort,
          );
        } else {
          await bank.update(
            id: id,
            prompt: prompt,
            optionA: a,
            optionB: b,
            optionC: c,
            optionD: d,
            correctIndex: _correct,
            explanation: expl,
            sortOrder: sort,
          );
        }
      }
      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        showAppSnackBar(context, '$e', kind: AppSnackKind.warning);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.editing != null;
    final topics = widget.topics;

    Widget topicDropdown() {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Chủ đề',
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
              items: topics
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
              onChanged: (v) {
                if (v != null) {
                  setState(() => _topicId = v);
                }
              },
            ),
          ),
        ],
      );
    }

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
                        isEdit ? 'Sửa câu hỏi quiz' : 'Câu hỏi quiz mới',
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
                topicDropdown(),
                const SizedBox(height: 14),
                TextField(
                  controller: _prompt,
                  minLines: 2,
                  maxLines: 5,
                  decoration: _quizFieldDeco('Nội dung câu hỏi *',
                      alignHint: true),
                ),
                const SizedBox(height: 12),
                LayoutBuilder(
                  builder: (context, c) {
                    final two = c.maxWidth > 520;
                    Widget field(TextEditingController ctrl, String label) {
                      return TextField(
                        controller: ctrl,
                        decoration: _quizFieldDeco(label),
                      );
                    }

                    if (!two) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          field(_a, 'Đáp án A *'),
                          const SizedBox(height: 10),
                          field(_b, 'Đáp án B *'),
                          const SizedBox(height: 10),
                          field(_c, 'Đáp án C *'),
                          const SizedBox(height: 10),
                          field(_d, 'Đáp án D *'),
                        ],
                      );
                    }
                    return Column(
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: field(_a, 'Đáp án A *')),
                            const SizedBox(width: 12),
                            Expanded(child: field(_b, 'Đáp án B *')),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: field(_c, 'Đáp án C *')),
                            const SizedBox(width: 12),
                            Expanded(child: field(_d, 'Đáp án D *')),
                          ],
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 14),
                Text(
                  'ĐÁP ÁN ĐÚNG',
                  style: GoogleFonts.robotoMono(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF64748B),
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: List.generate(4, (i) {
                    final on = _correct == i;
                    return Material(
                      color: on
                          ? AppColors.primaryContainer
                          : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10),
                      child: InkWell(
                        onTap: () => setState(() => _correct = i),
                        borderRadius: BorderRadius.circular(10),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          child: Text(
                            ['A', 'B', 'C', 'D'][i],
                            style: GoogleFonts.plusJakartaSans(
                              fontWeight: FontWeight.w800,
                              color: on ? Colors.white : AppColors.onSurface,
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _expl,
                  minLines: 1,
                  maxLines: 3,
                  decoration: _quizFieldDeco('Giải thích (tuỳ chọn)',
                      alignHint: true),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _sort,
                  keyboardType: TextInputType.number,
                  decoration: _quizFieldDeco('Thứ tự hiển thị'),
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
                        padding: const EdgeInsets.symmetric(
                          horizontal: 22,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text('Lưu câu hỏi'),
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
