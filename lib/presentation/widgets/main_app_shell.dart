// lib/presentation/widgets/main_app_shell.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ofgconnects_mobile/logic/auth_provider.dart';
import 'package:ofgconnects_mobile/presentation/pages/following_page.dart';
import 'package:ofgconnects_mobile/presentation/pages/home_page.dart';
import 'package:ofgconnects_mobile/presentation/pages/my_space_page.dart';
import 'package:ofgconnects_mobile/presentation/pages/shorts_page.dart';

class MainAppShell extends StatefulWidget {
  const MainAppShell({super.key});

  @override
  State<MainAppShell> createState() => _MainAppShellState();
}

class _MainAppShellState extends State<MainAppShell> {
  int _selectedIndex = 0; // This tracks the active tab

  // List of all the main pages
  static const List<Widget> _pages = <Widget>[
    HomePage(),
    ShortsPage(),
    FollowingPage(),
    MySpacePage(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // 1. The Top AppBar (replaces your Header.js)
      appBar: AppBar(
        title: const Text('OFG Connects'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              // TODO: Navigate to SearchPage
            },
          ),
          IconButton(
            icon: const Icon(Icons.notifications_none),
            onPressed: () {
              // TODO: Show notifications
            },
          ),
        ],
      ),

      // 2. The Main Content Area
      body: Center(
        child: _pages.elementAt(_selectedIndex),
      ),

      // 3. The Drawer (replaces your Sidebar.js)
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
                    child: Text(user?.name[0] ?? 'G'),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.history),
                  title: const Text('History'),
                  onTap: () {
                    // TODO: Navigate to HistoryPage
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.watch_later_outlined),
                  title: const Text('Watch Later'),
                  onTap: () {
                    // TODO: Navigate to WatchLaterPage
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.thumb_up_alt_outlined),
                  title: const Text('Liked Videos'),
                  onTap: () {
                    // TODO: Navigate to LikedVideosPage
                  },
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.settings_outlined),
                  title: const Text('Settings'),
                  onTap: () {
                    // TODO: Navigate to SettingsPage
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.logout),
                  title: const Text('Logout'),
                  onTap: () {
                    // Call the logout function
                    ref.read(authProvider.notifier).logoutUser();
                  },
                ),
              ],
            );
          },
        ),
      ),

      // 4. The Bottom Navigation Bar
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
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        // These are important for it to look right
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.blue,
        unselectedItemColor: Colors.grey,
      ),
    );
  }
}