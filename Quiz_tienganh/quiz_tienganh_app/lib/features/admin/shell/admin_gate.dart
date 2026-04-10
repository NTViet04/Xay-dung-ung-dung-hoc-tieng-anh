import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_routes.dart';
import '../../auth/controllers/auth_provider.dart';
import '../../auth/views/login_screen.dart';

/// Chỉ cho phép tài khoản `role == admin`. Các route `/admin/*` bọc bằng widget này.
class AdminGate extends StatelessWidget {
  const AdminGate({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, auth, _) {
        if (!auth.isLoggedIn) {
          return const LoginScreen();
        }
        if (auth.user?.isAdmin != true) {
          return Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.lock_outline, size: 48),
                    const SizedBox(height: 16),
                    Text(
                      'Bạn không có quyền truy cập khu vực quản trị.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: () {
                        Navigator.of(context).pushNamedAndRemoveUntil(
                          AppRoutes.learnerHome,
                          (route) => false,
                        );
                      },
                      child: const Text('Về trang học viên'),
                    ),
                  ],
                ),
              ),
            ),
          );
        }
        return child;
      },
    );
  }
}
