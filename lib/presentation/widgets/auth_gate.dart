// lib/presentation/widgets/auth_gate.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ofgconnects/logic/auth_provider.dart';

class AuthGate extends ConsumerStatefulWidget {
  const AuthGate({super.key});

  @override
  ConsumerState<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends ConsumerState<AuthGate> {
  bool _listenerRegistered = false;

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    if (!_listenerRegistered) {
      _listenerRegistered = true;

      ref.listen<AuthState>(authProvider, (previous, next) {
        // Only navigate when authenticated
        if (next.status == AuthStatus.authenticated) {
          if (mounted) context.go('/home');
        }
      });
    }

    // Show relevant UI while auth state resolves.
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (authState.status == AuthStatus.loading) ...[
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              const Text('Connecting...'),
            ] else if (authState.status == AuthStatus.authenticated) ...[
              // Empty view — listener will navigate to /home
              const SizedBox.shrink(),
            ] else ...[
              // This is the error state if guest login fails
              const Icon(Icons.error, color: Colors.red, size: 48),
              const SizedBox(height: 16),
              const Text(
                'Failed to connect. Please restart the app.',
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }
}