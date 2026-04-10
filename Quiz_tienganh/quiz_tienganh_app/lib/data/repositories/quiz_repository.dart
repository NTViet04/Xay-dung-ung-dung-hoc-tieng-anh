import '../../core/network/api_client.dart';
import '../models/quiz_bank_question_model.dart';
import '../models/vocabulary_model.dart';

class QuizQuestionPayload {
  QuizQuestionPayload({
    required this.mode,
    required this.topicId,
    required this.topicName,
    required this.vocabQuestions,
    required this.bankQuestions,
  });

  /// `vocab` — đáp án từ từ vựng; `bank` — ngân hàng câu hỏi do admin nhập.
  final String mode;
  final int topicId;
  final String? topicName;
  final List<VocabularyModel> vocabQuestions;
  final List<QuizBankQuestionModel> bankQuestions;

  bool get isBank => mode == 'bank';
}

class QuizSubmitResult {
  QuizSubmitResult({
    required this.score,
    required this.totalQuestions,
    required this.correctCount,
    required this.xpGained,
    required this.level,
    required this.xp,
  });

  final int score;
  final int totalQuestions;
  final int correctCount;
  final int xpGained;
  final int level;
  final int xp;
}

class QuizRepository {
  QuizRepository(this._client);

  final ApiClient _client;

  Future<QuizQuestionPayload> fetchQuestions({
    required int topicId,
    int limit = 10,
  }) async {
    final data = await _client.get('/quiz/questions', query: {
      'topic_id': '$topicId',
      'limit': '$limit',
    }) as Map<String, dynamic>;
    final mode = '${data['mode'] ?? 'vocab'}';
    final list = data['questions'] as List<dynamic>? ?? [];

    if (mode == 'bank') {
      final bank = <QuizBankQuestionModel>[];
      for (final e in list) {
        final m = e as Map<String, dynamic>;
        final optsRaw = m['options'] as List<dynamic>? ?? [];
        final opts = optsRaw.map((x) => '$x').toList();
        if (opts.length != 4) continue;
        bank.add(
          QuizBankQuestionModel(
            id: (m['id'] as num).toInt(),
            prompt: '${m['prompt'] ?? ''}',
            options: opts,
            correctIndex: (m['correct_index'] as num).toInt().clamp(0, 3),
          ),
        );
      }
      return QuizQuestionPayload(
        mode: 'bank',
        topicId: (data['topic_id'] as num).toInt(),
        topicName: data['topic_name'] as String?,
        vocabQuestions: const [],
        bankQuestions: bank,
      );
    }

    return QuizQuestionPayload(
      mode: 'vocab',
      topicId: (data['topic_id'] as num).toInt(),
      topicName: data['topic_name'] as String?,
      vocabQuestions:
          list.map((e) => VocabularyModel.fromJson(e as Map<String, dynamic>)).toList(),
      bankQuestions: const [],
    );
  }

  Future<QuizSubmitResult> submitResult({
    required int topicId,
    required int totalQuestions,
    required int correctCount,
  }) async {
    final data = await _client.post('/quiz/results', {
      'topic_id': topicId,
      'total_questions': totalQuestions,
      'correct_count': correctCount,
    }) as Map<String, dynamic>;
    final u = data['user'] as Map<String, dynamic>?;
    return QuizSubmitResult(
      score: (data['score'] as num).toInt(),
      totalQuestions: (data['total_questions'] as num).toInt(),
      correctCount: (data['correct_count'] as num).toInt(),
      xpGained: (data['xp_gained'] as num).toInt(),
      level: (u?['level'] as num?)?.toInt() ?? 0,
      xp: (u?['xp'] as num?)?.toInt() ?? 0,
    );
  }

  Future<List<Map<String, dynamic>>> fetchMyResults() async {
    final raw = await _client.get('/quiz/results') as List<dynamic>;
    return raw.map((e) => e as Map<String, dynamic>).toList();
  }
}
