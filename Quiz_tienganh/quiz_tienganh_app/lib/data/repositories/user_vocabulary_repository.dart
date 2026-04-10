import '../../core/network/api_client.dart';

/// Tiến độ từ theo user (`/user-vocabulary`).
class UserVocabularyRepository {
  UserVocabularyRepository(this._client);

  final ApiClient _client;

  Future<List<Map<String, dynamic>>> fetchMine() async {
    final raw = await _client.get('/user-vocabulary') as List<dynamic>;
    return raw.map((e) => e as Map<String, dynamic>).toList();
  }

  Future<void> upsert({
    required int vocabId,
    required String status,
    DateTime? lastReview,
  }) async {
    await _client.post('/user-vocabulary', {
      'vocab_id': vocabId,
      'status': status,
      if (lastReview != null) 'last_review': lastReview.toIso8601String(),
    });
  }
}
