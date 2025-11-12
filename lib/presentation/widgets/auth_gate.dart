// lib/presentation/widgets/auth_gate.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ofgconnects_mobile/logic/auth_provider.dart';
// We no longer import pages here

class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);

    // Use a listener to redirect user when auth state changes
    ref.listen<AuthState>(authProvider, (previous, next) {
      if (next.status == AuthStatus.authenticated) {
        context.go('/home'); // Go to home page
      }
      if (next.status == AuthStatus.unauthenticated) {
        context.go('/login'); // Go to login page
      }
    });

    // While loading, show a simple loading screen.
    // The listener will handle the redirect when auth status is determined.
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