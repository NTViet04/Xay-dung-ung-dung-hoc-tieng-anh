class TopicModel {
  const TopicModel({
    required this.id,
    required this.name,
    this.description,
    this.wordCount = 0,
  });

  final int id;
  final String name;
  final String? description;

  /// Số từ trong chủ đề (API `/topics` có thể kèm `word_count`).
  final int wordCount;

  factory TopicModel.fromJson(Map<String, dynamic> j) {
    return TopicModel(
      id: (j['id'] as num).toInt(),
      name: j['name'] as String,
      description: j['description'] as String?,
      wordCount: (j['word_count'] as num?)?.toInt() ?? 0,
    );
  }
}
