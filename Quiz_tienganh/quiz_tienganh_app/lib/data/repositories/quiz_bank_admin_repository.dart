import '../../core/network/api_client.dart';
import '../../core/utils/json_convert.dart';

/// CRUD câu hỏi trắc nghiệm (admin) — `/quiz/bank-questions`.
class QuizBankAdminRepository {
  QuizBankAdminRepository(this._client);

  final ApiClient _client;

  /// Không query → toàn bộ câu (admin), có `topic_name` từ server.
  Future<List<Map<String, dynamic>>> listAll() async {
    final raw = await _client.get('/quiz/bank-questions') as List<dynamic>;
    return raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<List<Map<String, dynamic>>> listByTopic(int topicId) async {
    final raw = await _client.get(
      '/quiz/bank-questions',
      query: {'topic_id': '$topicId'},
    ) as List<dynamic>;
    return raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<int> create({
    required int topicId,
    required String prompt,
    required String optionA,
    required String optionB,
    required String optionC,
    required String optionD,
    required int correctIndex,
    String? explanation,
    int sortOrder = 0,
  }) async {
    final data = await _client.post('/quiz/bank-questions', {
      'topic_id': topicId,
      'prompt': prompt,
      'option_a': optionA,
      'option_b': optionB,
      'option_c': optionC,
      'option_d': optionD,
      'correct_index': correctIndex,
      if (explanation != null && explanation.trim().isNotEmpty)
        'explanation': explanation.trim(),
      'sort_order': sortOrder,
    }) as Map<String, dynamic>;
    return parseJsonInt(data['id']) ?? 0;
  }

  Future<void> update({
    required int id,
    String? prompt,
    String? optionA,
    String? optionB,
    String? optionC,
    String? optionD,
    int? correctIndex,
    String? explanation,
    int? sortOrder,
  }) async {
    await _client.put('/quiz/bank-questions/$id', {
      if (prompt != null) 'prompt': prompt,
      if (optionA != null) 'option_a': optionA,
      if (optionB != null) 'option_b': optionB,
      if (optionC != null) 'option_c': optionC,
      if (optionD != null) 'option_d': optionD,
      if (correctIndex != null) 'correct_index': correctIndex,
      if (explanation != null) 'explanation': explanation,
      if (sortOrder != null) 'sort_order': sortOrder,
    });
  }

  Future<void> delete(int id) async {
    await _client.delete('/quiz/bank-questions/$id');
  }
}
