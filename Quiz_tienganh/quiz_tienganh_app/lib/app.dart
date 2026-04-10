import 'package:flutter/material.dart';

import 'core/constants/app_routes.dart';
import 'data/models/vocabulary_model.dart';
import 'core/theme/app_theme.dart';
import 'features/admin/dashboard/views/admin_dashboard_screen.dart';
import 'features/admin/shell/admin_gate.dart';
import 'features/admin/topic_management/views/topic_management_screen.dart';
import 'features/admin/user_management/views/user_management_screen.dart';
import 'features/admin/vocabulary_management/views/vocabulary_management_screen.dart';
import 'features/auth/views/auth_gate.dart';
import 'features/auth/views/login_screen.dart';
import 'features/auth/views/register_screen.dart';
import 'features/learner/flashcards/views/flashcards_screen.dart';
import 'features/learner/quiz/views/quiz_screen.dart';
import 'features/admin/quiz_questions/views/quiz_questions_management_screen.dart';
import 'features/learner/quiz_results/views/quiz_results_screen.dart';
import 'features/learner/shell/learner_shell.dart';
import 'features/learner/vocabulary_list/views/vocabulary_list_screen.dart';

class QuizTienganhApp extends StatelessWidget {
  const QuizTienganhApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Quiz Tiếng Anh',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: const AuthGate(),
      routes: {
        AppRoutes.login: (_) => const LoginScreen(),
        AppRoutes.register: (_) => const RegisterScreen(),
        AppRoutes.learnerVocabulary: (_) => const VocabularyListScreen(),
        AppRoutes.learnerFlashcards: (_) => const FlashcardsScreen(),
        AppRoutes.learnerQuiz: (context) {
          final args = ModalRoute.of(context)?.settings.arguments;
          var topicId = 1;
          if (args is Map && args['topicId'] != null) {
            topicId = (args['topicId'] as num).toInt();
          }
          return QuizScreen(topicId: topicId);
        },
        AppRoutes.learnerQuizResults: (context) {
          final args = ModalRoute.of(context)?.settings.arguments;
          if (args is Map<String, dynamic>) {
            return QuizResultsScreen(
              score: (args['score'] as num?)?.toInt() ?? 0,
              total: (args['total'] as num?)?.toInt() ?? 10,
              xpGained: (args['xpGained'] as num?)?.toInt() ?? 0,
              correctCount: (args['correctCount'] as num?)?.toInt(),
              level: (args['level'] as num?)?.toInt(),
              xp: (args['xp'] as num?)?.toInt(),
              topicId: (args['topicId'] as num?)?.toInt(),
              topicName: args['topicName'] as String?,
              missedWords: args['missedWords'] as List<VocabularyModel>?,
            );
          }
          return const QuizResultsScreen(score: 0, total: 10, xpGained: 0);
        },
        AppRoutes.adminDashboard: (_) =>
            const AdminGate(child: AdminDashboardScreen()),
        AppRoutes.adminTopics: (_) =>
            const AdminGate(child: TopicManagementScreen()),
        AppRoutes.adminVocabulary: (_) =>
            const AdminGate(child: VocabularyManagementScreen()),
        AppRoutes.adminUsers: (_) =>
            const AdminGate(child: UserManagementScreen()),
        AppRoutes.adminQuizQuestions: (_) =>
            const AdminGate(child: QuizQuestionsManagementScreen()),
      },
      onGenerateRoute: (RouteSettings settings) {
        final name = settings.name;
        if (name == AppRoutes.learnerHome ||
            name == AppRoutes.learnerTopics ||
            name == AppRoutes.learnerProgress) {
          final tab = switch (name) {
            AppRoutes.learnerHome => 0,
            AppRoutes.learnerTopics => 1,
            AppRoutes.learnerProgress => 2,
            _ => 0,
          };
          return MaterialPageRoute<void>(
            builder: (_) => LearnerShell(initialTab: tab),
            settings: settings,
          );
        }
        return null;
      },
    );
  }
}
