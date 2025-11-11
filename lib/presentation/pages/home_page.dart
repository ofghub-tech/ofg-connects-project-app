// lib/presentation/pages/home_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ofgconnects_mobile/logic/auth_provider.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Get the user's name from the provider
    final userName = ref.watch(authProvider).user?.name ?? 'User';

    return Scaffold(
      appBar: AppBar(
        title: Text('Welcome, $userName!'),
        actions: [
          IconButton(
            icon: Icon(Icons.logout),
            onPressed: () {
              // Call the logout function from our provider
              ref.read(authProvider.notifier).logoutUser();
            },
          )
        ],
      ),
      body: const Center(
        child: Text('Home Page'),
      ),
    );
  }
}