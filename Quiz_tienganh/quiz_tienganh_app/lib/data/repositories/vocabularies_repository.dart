import '../../core/network/api_client.dart';
import '../models/vocabulary_model.dart';

class VocabulariesRepository {
  VocabulariesRepository(this._client);

  final ApiClient _client;

  Future<List<VocabularyModel>> fetchAll({
    int? topicId,
    String? difficulty,
    String? q,
  }) async {
    final raw = await _client.get('/vocabularies', query: {
      if (topicId != null) 'topic_id': '$topicId',
      if (difficulty != null && difficulty.isNotEmpty) 'difficulty': difficulty,
      if (q != null && q.trim().isNotEmpty) 'q': q.trim(),
    }) as List<dynamic>;
    return raw
        .map((e) => VocabularyModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<VocabularyModel>> fetchByTopic(int topicId) async {
    return fetchAll(topicId: topicId);
  }

  Future<void> create({
    required String word,
    required String meaning,
    required int topicId,
    String? pronunciation,
    String? example,
    String difficulty = 'B2',
  }) async {
    final body = <String, dynamic>{
      'word': word,
      'meaning': meaning,
      'topic_id': topicId,
      'difficulty': difficulty,
    };
    if (pronunciation != null) {
      body['pronunciation'] = pronunciation;
    }
    if (example != null) {
      body['example'] = example;
    }
    await _client.post('/vocabularies', body);
  }

  Future<void> update(
    int id, {
    String? word,
    String? meaning,
    int? topicId,
    String? pronunciation,
    String? example,
    String? difficulty,
  }) async {
    final body = <String, dynamic>{};
    if (word != null) {
      body['word'] = word;
    }
    if (meaning != null) {
      body['meaning'] = meaning;
    }
    if (topicId != null) {
      body['topic_id'] = topicId;
    }
    if (pronunciation != null) {
      body['pronunciation'] = pronunciation;
    }
    if (example != null) {
      body['example'] = example;
    }
    if (difficulty != null) {
      body['difficulty'] = difficulty;
    }
    await _client.put('/vocabularies/$id', body);
  }

  Future<void> delete(int id) async {
    await _client.delete('/vocabularies/$id');
  }
}
