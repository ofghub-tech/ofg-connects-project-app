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
  
  @override
  void initState() {
    super.initState();
    // FIX: Check immediately if we are already authenticated to avoid getting stuck
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authState = ref.read(authProvider);
      if (authState.status == AuthStatus.authenticated) {
        context.go('/home');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    // Listener to handle status changes (e.g. from loading -> authenticated)
    ref.listen<AuthState>(authProvider, (previous, next) {
      if (next.status == AuthStatus.authenticated) {
        context.go('/home');
      }
    });

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F), 
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (authState.status == AuthStatus.loading) ...[
              const CircularProgressIndicator(color: Colors.blueAccent),
              const SizedBox(height: 16),
              const Text('Connecting...', style: TextStyle(color: Colors.white54)),
            ] else if (authState.status == AuthStatus.authenticated) ...[
              // We are authenticated, waiting for navigation...
              const SizedBox.shrink(),
            ] else ...[
              // Error / Guest Login Failed
              const Icon(Icons.error_outline, color: Colors.redAccent, size: 48),
              const SizedBox(height: 16),
              const Text(
                'Connection Failed',
                style: TextStyle(color: Colors.white, fontSize: 18),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => ref.read(authProvider.notifier).checkUserStatus(),
                child: const Text("Retry"),
              )
            ],
          ],
        ),
      ),
    );
  }
}