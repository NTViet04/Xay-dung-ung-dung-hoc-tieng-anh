import '../../core/network/api_client.dart';

class AdminRepository {
  AdminRepository(this._client);

  final ApiClient _client;

  Future<Map<String, dynamic>> topicManagementSummary() async {
    final data = await _client.get('/stats/topic-management');
    return data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> userManagementSummary() async {
    final data = await _client.get('/stats/user-management');
    return data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> vocabularyManagementSummary() async {
    final data = await _client.get('/stats/vocabulary-management');
    return data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> fetchUserAdminProfile(int userId) async {
    final data = await _client.get('/users/$userId/admin-profile');
    return data as Map<String, dynamic>;
  }

  Future<int> createUser({
    required String username,
    required String password,
    String role = 'learner',
  }) async {
    final data = await _client.post('/users', {
      'username': username,
      'password': password,
      'role': role,
    }) as Map<String, dynamic>;
    return (data['id'] as num).toInt();
  }

  Future<void> resetUserPassword(int userId, String password) async {
    await _client.put('/users/$userId/password', {'password': password});
  }

  Future<Map<String, dynamic>> dashboardStats({
    int ledgerPage = 0,
    int ledgerLimit = 10,
    String? search,
  }) async {
    final query = <String, String>{
      'ledger_page': '$ledgerPage',
      'ledger_limit': '$ledgerLimit',
      if (search != null && search.trim().isNotEmpty) 'q': search.trim(),
    };
    final data = await _client.get('/stats/dashboard', query: query);
    return data as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> fetchUsers() async {
    final raw = await _client.get('/users') as List<dynamic>;
    return raw.map((e) => e as Map<String, dynamic>).toList();
  }

  Future<void> deleteUser(int id) async {
    await _client.delete('/users/$id');
  }
}
