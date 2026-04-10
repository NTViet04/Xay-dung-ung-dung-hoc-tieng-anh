class VocabularyModel {
  const VocabularyModel({
    required this.id,
    required this.word,
    required this.meaning,
    this.pronunciation,
    this.example,
    required this.topicId,
    this.difficulty = 'B2',
    this.topicName,
    this.masteryLabel,
  });

  final int id;
  final String word;
  final String meaning;
  final String? pronunciation;
  final String? example;
  final int topicId;
  /// CEFR: B1, B2, C1
  final String difficulty;
  final String? topicName;
  /// Low, Med, High, Expert — từ máy chủ (user_vocabulary).
  final String? masteryLabel;

  factory VocabularyModel.fromJson(Map<String, dynamic> j) {
    final diff = j['difficulty'] as String?;
    return VocabularyModel(
      id: (j['id'] as num).toInt(),
      word: j['word'] as String,
      meaning: j['meaning'] as String,
      pronunciation: j['pronunciation'] as String?,
      example: j['example'] as String?,
      topicId: (j['topic_id'] as num).toInt(),
      difficulty: (diff != null && diff.isNotEmpty) ? diff : 'B2',
      topicName: j['topic_name'] as String?,
      masteryLabel: j['mastery_label'] as String?,
    );
  }
}
