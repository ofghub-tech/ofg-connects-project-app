// lib/presentation/widgets/main_app_shell.dart
import 'dart:ui'; // Required for BackdropFilter
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ofgconnects_mobile/logic/auth_provider.dart';

class MainAppShell extends ConsumerWidget {
  final Widget child;

  const MainAppShell({super.key, required this.child});

  int _calculateSelectedIndex(BuildContext context) {
    final String location = GoRouterState.of(context).uri.toString();
    if (location.startsWith('/home')) return 0;
    if (location.startsWith('/shorts')) return 1;
    if (location.startsWith('/upload')) return 2;
    if (location.startsWith('/following')) return 3;
    if (location.startsWith('/myspace')) return 4;
    return 0;
  }

  void _onItemTapped(int index, BuildContext context) {
    switch (index) {
      case 0: context.go('/home'); break;
      case 1: context.go('/shorts'); break;
      case 2: context.go('/upload'); break;
      case 3: context.go('/following'); break;
      case 4: context.go('/myspace'); break;
    }
  }

  void _onProfileMenuSelected(String value, WidgetRef ref, BuildContext context) {
    switch (value) {
      case 'settings': context.push('/settings'); break;
      case 'logout': ref.read(authProvider.notifier).logoutUser(); break;
    }
  }

  bool _shouldShowAppBar(BuildContext context) {
    final String location = GoRouterState.of(context).uri.toString();
    return location == '/home' || location == '/following';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedIndex = _calculateSelectedIndex(context);
    final user = ref.watch(authProvider).user;
    final bool isGuest = user == null || user.email.isEmpty;
    final String location = GoRouterState.of(context).uri.path;
    final bool isOtherRootTab = ['/shorts', '/upload', '/following', '/myspace'].contains(location);

    return PopScope(
      canPop: !isOtherRootTab, 
      onPopInvoked: (didPop) {
        if (didPop) return; 
        context.go('/home');
      },
      child: Scaffold(
        // --- KEY UX FIX: Allow content to flow behind the nav bar ---
        extendBody: true, 
        
        appBar: _shouldShowAppBar(context) 
          ? PreferredSize(
              preferredSize: const Size.fromHeight(60),
              child: AppBar(
                automaticallyImplyLeading: false,
                backgroundColor: Colors.transparent, 
                elevation: 0,
                scrolledUnderElevation: 0,
                // Glass effect for AppBar
                flexibleSpace: ClipRRect(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Container(color: Theme.of(context).scaffoldBackgroundColor.withOpacity(0.7)),
                  ),
                ),
                title: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.blueAccent,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [BoxShadow(color: Colors.blueAccent.withOpacity(0.4), blurRadius: 8)]
                      ),
                      child: const Text(
                        'OFG',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Connects',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                    ),
                  ],
                ),
                actions: [
                  if (isGuest)
                    TextButton(
                      onPressed: () => ref.read(authProvider.notifier).googleLogin(),
                      child: const Text('Sign Up'),
                    ),
                  _buildCircleAction(context, Icons.search_rounded, () => context.push('/search')),
                  const SizedBox(width: 8),
                  _buildCircleAction(context, Icons.notifications_none_rounded, () {}),
                  const SizedBox(width: 8),
                  PopupMenuButton<String>(
                    offset: const Offset(0, 50),
                    color: const Color(0xFF1E1E1E),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    onSelected: (value) => _onProfileMenuSelected(value, ref, context),
                    itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                      const PopupMenuItem<String>(
                        value: 'settings',
                        child: ListTile(
                          leading: Icon(Icons.settings_outlined, color: Colors.white),
                          title: Text('Settings', style: TextStyle(color: Colors.white)),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                      if (!isGuest)
                        const PopupMenuItem<String>(
                          value: 'logout',
                          child: ListTile(
                            leading: Icon(Icons.logout, color: Colors.redAccent),
                            title: Text('Logout', style: TextStyle(color: Colors.redAccent)),
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                    ],
                    child: Padding(
                      padding: const EdgeInsets.only(right: 16.0),
                      child: CircleAvatar(
                        radius: 18,
                        backgroundColor: Colors.grey[800],
                        backgroundImage: (user?.prefs.data['avatar'] != null) 
                            ? NetworkImage(user!.prefs.data['avatar']) 
                            : null,
                        child: (user?.prefs.data['avatar'] == null)
                          ? Text(isGuest ? 'G' : user!.name[0].toUpperCase(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))
                          : null,
                      ),
                    ),
                  ),
                ],
              ),
            )
          : null, 

        body: child,
        
        floatingActionButton: selectedIndex == 1 
          ? null 
          : FloatingActionButton(
              onPressed: () => context.push('/bible'),
              backgroundColor: Colors.blueAccent,
              elevation: 8,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              child: const Icon(Icons.menu_book_rounded, color: Colors.white),
            ),

        // --- NEW GLASSMORPHIC NAV BAR ---
        bottomNavigationBar: Container(
           margin: const EdgeInsets.only(left: 10, right: 10, bottom: 10), // Floating effect
           child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.75),
                  border: Border.all(color: Colors.white.withOpacity(0.1)),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: NavigationBar(
                  selectedIndex: selectedIndex,
                  onDestinationSelected: (index) => _onItemTapped(index, context),
                  backgroundColor: Colors.transparent,
                  indicatorColor: Colors.blueAccent.withOpacity(0.25),
                  labelBehavior: NavigationDestinationLabelBehavior.alwaysHide, // Clean look
                  height: 65,
                  destinations: const [
                     NavigationDestination(
                      icon: Icon(Icons.home_outlined, color: Colors.white60),
                      selectedIcon: Icon(Icons.home_rounded, color: Colors.blueAccent),
                      label: 'Home',
                    ),
                     NavigationDestination(
                      icon: Icon(Icons.play_arrow_outlined, color: Colors.white60),
                      selectedIcon: Icon(Icons.play_arrow_rounded, color: Colors.blueAccent),
                      label: 'Shorts',
                    ),
                     NavigationDestination(
                      icon: Icon(Icons.add_circle_outline, size: 30, color: Colors.white60),
                      selectedIcon: Icon(Icons.add_circle, color: Colors.blueAccent, size: 30),
                      label: 'Upload',
                    ),
                     NavigationDestination(
                      icon: Icon(Icons.people_outline, color: Colors.white60),
                      selectedIcon: Icon(Icons.people_rounded, color: Colors.blueAccent),
                      label: 'Following',
                    ),
                     NavigationDestination(
                      icon: Icon(Icons.person_outline, color: Colors.white60),
                      selectedIcon: Icon(Icons.person_rounded, color: Colors.blueAccent),
                      label: 'My Space',
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCircleAction(BuildContext context, IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(50),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withOpacity(0.08), 
        ),
        child: Icon(icon, size: 22, color: Colors.white),
      ),
    );
  }
}