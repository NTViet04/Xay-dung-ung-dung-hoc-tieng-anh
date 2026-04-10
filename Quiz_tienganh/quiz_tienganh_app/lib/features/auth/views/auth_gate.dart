import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../learner/shell/learner_shell.dart';
import '../controllers/auth_provider.dart';
import 'login_screen.dart';

/// Khởi động: loading → đã đăng nhập (Learner) hoặc Login.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, auth, _) {
        if (auth.isInitializing) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (auth.isLoggedIn) {
          return const LearnerShell(initialTab: 0);
        }
        return const LoginScreen();
      },
    );
  }
}
