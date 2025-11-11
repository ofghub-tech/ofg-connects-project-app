// lib/presentation/widgets/auth_gate.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ofgconnects_mobile/logic/auth_provider.dart';
// 1. REMOVE the import for home_page.dart
// import 'package:ofgconnects_mobile/presentation/pages/home_page.dart'; 
import 'package:ofgconnects_mobile/presentation/pages/login_page.dart';
// 2. ADD the import for our new shell
import 'package:ofgconnects_mobile/presentation/widgets/main_app_shell.dart'; 

class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);

    switch (authState.status) {
      case AuthStatus.authenticated:
        // 3. CHANGE this line from HomePage()
        return const MainAppShell(); // <-- Was: const HomePage();
      case AuthStatus.unauthenticated:
        return const LoginPage();
      case AuthStatus.loading:
        return const Scaffold(
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Loading application...'),
              ],
            ),
          ),
        );
    }
  }
}