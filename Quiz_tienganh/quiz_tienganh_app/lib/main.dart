import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'core/network/api_client.dart';
import 'data/repositories/admin_repository.dart';
import 'data/repositories/auth_repository.dart';
import 'data/repositories/progress_repository.dart';
import 'data/repositories/quiz_bank_admin_repository.dart';
import 'data/repositories/quiz_repository.dart';
import 'data/repositories/topics_repository.dart';
import 'data/repositories/user_vocabulary_repository.dart';
import 'data/repositories/vocabularies_repository.dart';
import 'features/auth/controllers/auth_provider.dart';
import 'features/learner/controllers/learner_tab_index.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final api = ApiClient();
  final authRepo = AuthRepository(api);
  final auth = AuthProvider(authRepo);
  await auth.init();

  runApp(
    MultiProvider(
      providers: [
        Provider<ApiClient>.value(value: api),
        Provider<AuthRepository>.value(value: authRepo),
        Provider<TopicsRepository>(create: (_) => TopicsRepository(api)),
        Provider<VocabulariesRepository>(
          create: (_) => VocabulariesRepository(api),
        ),
        Provider<QuizRepository>(create: (_) => QuizRepository(api)),
        Provider<ProgressRepository>(create: (_) => ProgressRepository(api)),
        Provider<QuizBankAdminRepository>(
          create: (_) => QuizBankAdminRepository(api),
        ),
        Provider<AdminRepository>(create: (_) => AdminRepository(api)),
        Provider<UserVocabularyRepository>(
          create: (_) => UserVocabularyRepository(api),
        ),
        ChangeNotifierProvider<AuthProvider>.value(value: auth),
        ChangeNotifierProvider<LearnerTabIndex>(
          create: (_) => LearnerTabIndex(0),
        ),
      ],
      child: const QuizTienganhApp(),
    ),
  );
}
