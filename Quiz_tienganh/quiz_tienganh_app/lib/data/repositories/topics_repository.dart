import '../../core/network/api_client.dart';
import '../models/topic_model.dart';

class TopicsRepository {
  TopicsRepository(this._client);

  final ApiClient _client;

  Future<List<TopicModel>> fetchTopics() async {
    final raw = await _client.get('/topics') as List<dynamic>;
    return raw
        .map((e) => TopicModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<TopicModel> fetchById(int id) async {
    final j = await _client.get('/topics/$id') as Map<String, dynamic>;
    return TopicModel.fromJson(j);
  }

  Future<TopicModel> createTopic({required String name, String? description}) async {
    final data = await _client.post('/topics', {
      'name': name,
      if (description != null) 'description': description,
    }) as Map<String, dynamic>;
    final id = (data['id'] as num).toInt();
    return fetchById(id);
  }

  Future<void> updateTopic(
    int id, {
    String? name,
    String? description,
  }) async {
    await _client.put('/topics/$id', {
      if (name != null) 'name': name,
      if (description != null) 'description': description,
    });
  }

  Future<void> deleteTopic(int id) async {
    await _client.delete('/topics/$id');
  }
}
