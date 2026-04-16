import '../../core/network/api_client.dart';
import '../../core/utils/json_convert.dart';

/// Tiến độ theo chủ đề — `GET /progress/topics`.
class ProgressRepository {
  ProgressRepository(this._client);

  final ApiClient _client;

  /// GET /progress/summary — tổng từ đã nắm, quiz, chủ đề hoàn thành, streak, thời gian ước lượng.
  Future<Map<String, dynamic>> fetchMyProgressSummary() async {
    final data = await _client.get('/progress/summary') as Map<String, dynamic>;
    return {
      'words_mastered_total': parseJsonInt(data['words_mastered_total']) ?? 0,
      'quiz_attempts_total': parseJsonInt(data['quiz_attempts_total']) ?? 0,
      'topics_mastered_count': parseJsonInt(data['topics_mastered_count']) ?? 0,
      'topics_total': parseJsonInt(data['topics_total']) ?? 0,
      'avg_quiz_score': parseJsonInt(data['avg_quiz_score']) ?? 0,
      'streak_days': parseJsonInt(data['streak_days']) ?? 0,
      'study_minutes_estimate': parseJsonInt(data['study_minutes_estimate']) ?? 0,
    };
  }

  /// Mỗi phần tử: topic_id, topic_name, vocab_total, vocab_mastered, vocab_progress_pct, quiz_best_score
  Future<List<Map<String, dynamic>>> fetchMyTopicProgress() async {
    final raw = await _client.get('/progress/topics') as List<dynamic>;
    return raw.map((e) {
      final m = Map<String, dynamic>.from(e as Map);
      return {
        'topic_id': parseJsonInt(m['topic_id']) ?? 0,
        'topic_name': '${m['topic_name'] ?? ''}',
        'vocab_total': parseJsonInt(m['vocab_total']) ?? 0,
        'vocab_mastered': parseJsonInt(m['vocab_mastered']) ?? 0,
        'vocab_progress_pct':
            (parseJsonDouble(m['vocab_progress_pct']) ?? parseJsonInt(m['vocab_progress_pct'])?.toDouble() ?? 0)
                .round()
                .clamp(0, 100),
        'quiz_best_score': parseJsonInt(m['quiz_best_score']) ?? 0,
      };
    }).toList();
  }
}
