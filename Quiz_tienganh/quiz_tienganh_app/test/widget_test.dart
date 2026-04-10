import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:quiz_tienganh_app/core/network/api_client.dart';
import 'package:quiz_tienganh_app/data/repositories/admin_repository.dart';
import 'package:quiz_tienganh_app/data/repositories/auth_repository.dart';
import 'package:quiz_tienganh_app/data/repositories/quiz_repository.dart';
import 'package:quiz_tienganh_app/data/repositories/topics_repository.dart';
import 'package:quiz_tienganh_app/data/repositories/vocabularies_repository.dart';
import 'package:quiz_tienganh_app/features/auth/controllers/auth_provider.dart';
import 'package:quiz_tienganh_app/app.dart';

void main() {
  testWidgets('App hiển thị màn hình đăng nhập', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final api = ApiClient();
    final authRepo = AuthRepository(api);
    final auth = AuthProvider(authRepo);
    await auth.init();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<ApiClient>.value(value: api),
          Provider<AuthRepository>.value(value: authRepo),
          Provider<TopicsRepository>(create: (_) => TopicsRepository(api)),
          Provider<VocabulariesRepository>(
            create: (_) => VocabulariesRepository(api),
          ),
          Provider<QuizRepository>(create: (_) => QuizRepository(api)),
          Provider<AdminRepository>(create: (_) => AdminRepository(api)),
          ChangeNotifierProvider<AuthProvider>.value(value: auth),
        ],
        child: const QuizTienganhApp(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Chào mừng trở lại'), findsOneWidget);
  });
}
