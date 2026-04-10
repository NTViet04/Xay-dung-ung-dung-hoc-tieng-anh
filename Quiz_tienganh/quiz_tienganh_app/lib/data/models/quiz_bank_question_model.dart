/// Câu hỏi trắc nghiệm từ ngân hàng (bảng `quiz_questions`).
class QuizBankQuestionModel {
  const QuizBankQuestionModel({
    required this.id,
    required this.prompt,
    required this.options,
    required this.correctIndex,
  });

  final int id;
  final String prompt;
  final List<String> options;
  final int correctIndex;

  String get correctAnswerText => options[correctIndex];
}
