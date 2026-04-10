/// Đường dẫn màn hình — map với thư mục Thiết kế/.
abstract final class AppRoutes {
  static const String login = '/login';
  static const String register = '/register';

  static const String learnerHome = '/learner/home';
  static const String learnerTopics = '/learner/topics';
  static const String learnerVocabulary = '/learner/vocabulary';
  static const String learnerFlashcards = '/learner/flashcards';
  static const String learnerQuiz = '/learner/quiz';
  static const String learnerQuizResults = '/learner/quiz/results';
  /// Tiến độ học (màn hình profile_progress).
  static const String learnerProgress = '/learner/progress';

  static const String adminDashboard = '/admin';
  static const String adminTopics = '/admin/topics';
  static const String adminVocabulary = '/admin/vocabulary';
  static const String adminUsers = '/admin/users';
  static const String adminQuizQuestions = '/admin/quiz-questions';
}
