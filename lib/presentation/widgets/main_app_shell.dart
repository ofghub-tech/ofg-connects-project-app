// lib/presentation/widgets/main_app_shell.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart'; // Import GoRouter
import 'package:ofgconnects_mobile/logic/auth_provider.dart';

// 1. Changed to ConsumerWidget
class MainAppShell extends ConsumerWidget { 
  // 2. GoRouter passes the current page as a 'child'
  final Widget child; 

  const MainAppShell({super.key, required this.child});

  // 3. Helper to figure out which nav item is active
  int _calculateSelectedIndex(BuildContext context) {
    final String location = GoRouterState.of(context).uri.toString();
    if (location.startsWith('/home')) {
      return 0;
    }
    if (location.startsWith('/shorts')) {
      return 1;
    }
    if (location.startsWith('/following')) {
      return 2;
    }
    if (location.startsWith('/myspace')) {
      return 3;
    }
    return 0; // Default to home
  }

  // 4. Navigation tap handler
  void _onItemTapped(int index, BuildContext context) {
    switch (index) {
      case 0:
        context.go('/home');
        break;
      case 1:
        context.go('/shorts');
        break;
      case 2:
        context.go('/following');
        break;
      case 3:
        context.go('/myspace');
        break;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) { // 5. Added ref
    final selectedIndex = _calculateSelectedIndex(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('OFG Connects'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () { /* TODO: context.go('/search'); */ },
          ),
          IconButton(
            icon: const Icon(Icons.notifications_none),
            onPressed: () { /* TODO: Show notifications */ },
          ),
        ],
      ),

      // 6. The Main Content Area - displays the current page
      body: child, 

      // 7. The Drawer (Sidebar)
      drawer: Drawer(
        child: Consumer(
          builder: (context, ref, child) {
            final user = ref.watch(authProvider).user;
            return ListView(
              padding: EdgeInsets.zero,
              children: [
                UserAccountsDrawerHeader(
                  accountName: Text(user?.name ?? 'Guest'),
                  accountEmail: Text(user?.email ?? 'No email'),
                  currentAccountPicture: CircleAvatar(
                    // 8. Safer way to get first initial
                    child: Text(user?.name.isNotEmpty == true ? user!.name[0] : 'G'),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.history),
                  title: const Text('History'),
                  onTap: () { /* TODO: context.go('/history'); */ },
                ),
                ListTile(
                  leading: const Icon(Icons.watch_later_outlined),
                  title: const Text('Watch Later'),
                  onTap: () { /* TODO: context.go('/watchlater'); */ },
                ),
                ListTile(
                  leading: const Icon(Icons.thumb_up_alt_outlined),
                  title: const Text('Liked Videos'),
                  onTap: () { /* TODO: context.go('/liked'); */ },
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.settings_outlined),
                  title: const Text('Settings'),
                  onTap: () { /* TODO: context.go('/settings'); */ },
                ),
                ListTile(
                  leading: const Icon(Icons.logout),
                  title: const Text('Logout'),
                  onTap: () {
                    ref.read(authProvider.notifier).logoutUser();
                    // 9. Navigate to login after logout
                    context.go('/login'); 
                  },
                ),
              ],
            );
          },
        ),
      ),

      // 10. The Bottom Navigation Bar
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
        onTap: (index) => _onItemTapped(index, context), // 11. Pass context
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.blue,
        unselectedItemColor: Colors.grey,
      ),
    );
  }
}