// lib/presentation/widgets/main_app_shell.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ofgconnects_mobile/logic/auth_provider.dart';

class MainAppShell extends ConsumerWidget {
  final Widget child;

  const MainAppShell({super.key, required this.child});

  // Index calculation for 5 items
  int _calculateSelectedIndex(BuildContext context) {
    final String location = GoRouterState.of(context).uri.toString();
    if (location.startsWith('/home')) return 0;
    if (location.startsWith('/shorts')) return 1;
    if (location.startsWith('/upload')) return 2;
    if (location.startsWith('/following')) return 3;
    if (location.startsWith('/myspace')) return 4;
    return 0; // Default to home
  }

  // Tap handler for 5 items
  void _onItemTapped(int index, BuildContext context) {
    switch (index) {
      case 0:
        context.go('/home');
        break;
      case 1:
        context.go('/shorts');
        break;
      case 2:
        context.go('/upload');
        break;
      case 3:
        context.go('/following');
        break;
      case 4:
        context.go('/myspace');
        break;
    }
  }

  // --- Handle profile menu selection ---
  void _onProfileMenuSelected(String value, WidgetRef ref, BuildContext context) {
    switch (value) {
      case 'settings':
        context.push('/settings');
        break;
      case 'logout':
        ref.read(authProvider.notifier).logoutUser();
        break;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedIndex = _calculateSelectedIndex(context);
    
    final user = ref.watch(authProvider).user;
    final bool isGuest = user == null || user.email.isEmpty;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false, 
        title: const Text('OFG Connects'),
        actions: [
          if (isGuest)
            TextButton(
              onPressed: () {
                ref.read(authProvider.notifier).googleLogin();
              },
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).appBarTheme.actionsIconTheme?.color ?? Colors.white,
              ),
              child: const Text('Sign Up'),
            ),
          
          // --- UPDATE THIS BUTTON ---
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              context.push('/search'); // Navigate to search page
            },
          ),
          // ---------------------------

          IconButton(
            icon: const Icon(Icons.notifications_none),
            onPressed: () { /* TODO: Show notifications */
            },
          ),
          PopupMenuButton<String>(
            onSelected: (value) => _onProfileMenuSelected(value, ref, context),
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              const PopupMenuItem<String>(
                value: 'settings',
                child: ListTile(
                  leading: Icon(Icons.settings),
                  title: Text('Settings'),
                ),
              ),
              if (!isGuest)
                const PopupMenuItem<String>(
                  value: 'logout',
                  child: ListTile(
                    leading: Icon(Icons.logout),
                    title: Text('Logout'),
                  ),
                ),
            ],
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: CircleAvatar(
                radius: 16,
                child: Text(isGuest ? 'G' : user!.name[0].toUpperCase()),
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: child,
      
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          context.push('/bible');
        },
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        child: const Icon(Icons.book_outlined),
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.video_library_outlined),
            activeIcon: Icon(Icons.video_library),
            label: 'Shorts',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.add_circle_outline, size: 30),
            activeIcon: Icon(Icons.add_circle, size: 30),
            label: 'Upload',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.people_alt_outlined),
            activeIcon: Icon(Icons.people_alt),
            label: 'Following',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: 'My Space',
          ),
        ],
        currentIndex: selectedIndex,
        onTap: (index) => _onItemTapped(index, context),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.blue,
        unselectedItemColor: Colors.grey,
        showUnselectedLabels: true,
      ),
    );
  }
}