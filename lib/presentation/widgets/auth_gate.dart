// lib/presentation/widgets/auth_gate.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ofgconnects_mobile/logic/auth_provider.dart';

class AuthGate extends ConsumerStatefulWidget {
  const AuthGate({super.key});

  @override
  ConsumerState<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends ConsumerState<AuthGate> {
  // guard so we only register the listener once (and inside build)
  bool _listenerRegistered = false;

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    // Register listener inside build (Riverpod requires this).
    // We ensure it runs only once to avoid duplicate registrations.
    if (!_listenerRegistered) {
      _listenerRegistered = true;

      ref.listen<AuthState>(authProvider, (previous, next) {
        // don't navigate when a loading check is in progress
        if (next.status == AuthStatus.loading) return;

        if (next.status == AuthStatus.authenticated) {
          if (mounted) context.go('/home');
        } else if (next.status == AuthStatus.unauthenticated) {
          if (mounted) context.go('/login');
        }
      });
    }

    // Show relevant UI while auth state resolves.
    // Navigation is handled by the listener above.
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (authState.status == AuthStatus.loading) ...[
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              const Text('Checking authentication...'),
            ] else if (authState.status == AuthStatus.authenticated) ...[
              // Empty view — listener will navigate to /home
              const SizedBox.shrink(),
            ] else ...[
              // Empty view — listener will navigate to /login
              const SizedBox.shrink(),
            ],
          ],
        ),
      ),
    );
  }
}
