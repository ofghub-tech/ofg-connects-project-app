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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedIndex = _calculateSelectedIndex(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('OFG Connects'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () { /* TODO: context.go('/search'); */
            },
          ),
          IconButton(
            icon: const Icon(Icons.notifications_none),
            onPressed: () { /* TODO: Show notifications */
            },
          ),
        ],
      ),
      body: child,
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
                    child: Text(user?.name.isNotEmpty == true ? user!.name[0] : 'G'),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.history),
                  title: const Text('History'),
                  onTap: () {
                    context.pop(); // Close drawer
                    context.push('/history'); // Navigate
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.watch_later_outlined),
                  title: const Text('Watch Later'),
                  onTap: () {
                    context.pop(); // Close drawer
                    context.push('/watchlater'); // Navigate
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.thumb_up_alt_outlined),
                  title: const Text('Liked Videos'),
                  onTap: () {
                    context.pop();
                    context.push('/liked');
                  },
                ),
                
                // --- BIBLE LINK REMOVED FROM HERE ---

                const Divider(),
                ListTile(
                  leading: const Icon(Icons.settings_outlined),
                  title: const Text('Settings'),
                  onTap: () { /* TODO: context.go('/settings'); */
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.logout),
                  title: const Text('Logout'),
                  onTap: () {
                    ref.read(authProvider.notifier).logoutUser();
                    context.go('/login');
                  },
                ),
              ],
            );
          },
        ),
      ),
      
      // --- HERE IS THE FLOATING ACTION BUTTON ---
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Use push to open the Bible page over the current page
          context.push('/bible');
        },
        backgroundColor: Colors.blue, // Optional: Style it
        foregroundColor: Colors.white, // Optional: Style it
        child: const Icon(Icons.book_outlined), // 
      ),
      // ------------------------------------------

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