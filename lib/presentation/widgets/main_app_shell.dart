// lib/presentation/widgets/main_app_shell.dart
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
<<<<<<< HEAD
// CORRECTION: Package name must match pubspec.yaml (ofgconnects)
=======
>>>>>>> ae3527dc080370e17b52e3164c73699c33084bda
import 'package:ofgconnects/logic/auth_provider.dart';

class MainAppShell extends ConsumerStatefulWidget {
  final Widget child;
  const MainAppShell({super.key, required this.child});

  @override
  ConsumerState<MainAppShell> createState() => _MainAppShellState();
}

class _MainAppShellState extends ConsumerState<MainAppShell> {
  Offset? _bibleButtonPosition;

  int _calculateSelectedIndex(BuildContext context) {
    final String location = GoRouterState.of(context).uri.toString();
    if (location.startsWith('/home')) return 0;
    if (location.startsWith('/shorts')) return 1;
    if (location.startsWith('/upload')) return 2;
    if (location.startsWith('/following')) return 3;
    if (location.startsWith('/myspace')) return 4;
    return 0;
  }

  void _onItemTapped(int index, BuildContext context, WidgetRef ref) {
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
  Widget build(BuildContext context) {
    final selectedIndex = _calculateSelectedIndex(context);
    final user = ref.watch(authProvider).user;
    final bool isGuest = user == null || user.email.isEmpty;

    final String location = GoRouterState.of(context).uri.toString();
    final bool isShortsPage = location.startsWith('/shorts');
    
    final double bottomPadding = isShortsPage ? 0 : 100;
    final Size screenSize = MediaQuery.of(context).size;

    if (_bibleButtonPosition == null) {
      _bibleButtonPosition = Offset(screenSize.width - 72, screenSize.height - 160);
    }

    const double navBarHeight = 70;
    const double navBarBottomMargin = 24;
    const double logoBottomPos = 35; 
    const double logoSize = 75;

    return Stack(
      children: [
        Scaffold(
          extendBody: true, 
          appBar: _shouldShowAppBar(context)
              ? PreferredSize(
                  preferredSize: const Size.fromHeight(60), 
                  child: AppBar(
                    automaticallyImplyLeading: false,
                    backgroundColor: Colors.transparent,
                    elevation: 0,
                    scrolledUnderElevation: 0,
                    flexibleSpace: ClipRRect(
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                        child: Container(color: Theme.of(context).scaffoldBackgroundColor.withOpacity(0.7)),
                      ),
                    ),
                    title: GestureDetector(
                      onTap: () => context.go('/home'),
                      child: const Padding(
                        padding: EdgeInsets.only(left: 8.0),
                        child: Text(
                          'OFG',
                          style: TextStyle(
                            color: Colors.white, 
                            fontWeight: FontWeight.w900,
                            fontSize: 28, 
                            letterSpacing: 2.0,
                          ),
                        ),
                      ),
                    ),
                    centerTitle: false,
                    actions: [
                      if (isGuest)
                        TextButton(
                          onPressed: () => ref.read(authProvider.notifier).googleLogin(),
                          child: const Text('Sign In', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      _buildCircleAction(context, Icons.search_rounded, () => context.push('/search')),
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
                            backgroundImage: (user?.prefs.data['avatar'] != null) ? NetworkImage(user!.prefs.data['avatar']) : null,
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
          
          body: Padding(
            padding: EdgeInsets.only(bottom: bottomPadding),
            child: widget.child,
          ),
        ),

        // CUSTOM FLOATING NAVIGATION BAR - Hidden on Shorts
        if (!isShortsPage)
          Positioned(
            left: 0, 
            right: 0, 
            bottom: 0,
            child: SizedBox(
              height: 140, 
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.bottomCenter,
                children: [
                  Container(
                    margin: const EdgeInsets.only(left: 16, right: 16, bottom: navBarBottomMargin),
                    height: navBarHeight,
                    decoration: BoxDecoration(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(35),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 10))
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(35),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                        child: Container(
                          color: const Color(0xFF1E1E1E).withOpacity(0.85),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              _buildNavItem(context, Icons.home_rounded, Icons.home_outlined, 0, selectedIndex, ref),
                              _buildNavItem(context, Icons.play_arrow_rounded, Icons.play_arrow_outlined, 1, selectedIndex, ref),
                              const SizedBox(width: 60),
                              _buildNavItem(context, Icons.people_rounded, Icons.people_outline, 3, selectedIndex, ref),
                              _buildNavItem(context, Icons.person_rounded, Icons.person_outline, 4, selectedIndex, ref),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: logoBottomPos,
                    child: GestureDetector(
                      onTap: () => _onItemTapped(2, context, ref),
                      child: SizedBox(
                        width: logoSize, 
                        height: logoSize,
                        child: Image.asset(
                          'assets/logo.png', 
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) => 
                            const Icon(Icons.add_circle, size: 60, color: Colors.blueAccent),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

        // DRAGGABLE BIBLE BUTTON - Hidden on Shorts
        if (!isShortsPage) 
          Positioned(
            left: _bibleButtonPosition!.dx,
            top: _bibleButtonPosition!.dy,
            child: GestureDetector(
              onPanUpdate: (details) {
                setState(() {
                  double newX = _bibleButtonPosition!.dx + details.delta.dx;
                  double newY = _bibleButtonPosition!.dy + details.delta.dy;
                  final double maxX = screenSize.width - 56;
                  final double maxY = screenSize.height - 56;
                  if (newX < 0) newX = 0;
                  if (newX > maxX) newX = maxX;
                  if (newY < 50) newY = 50;
                  if (newY > maxY) newY = maxY;
                  _bibleButtonPosition = Offset(newX, newY);
                });
              },
              child: FloatingActionButton(
                onPressed: () => context.push('/bible'),
                backgroundColor: Colors.blueAccent,
                elevation: 8,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                child: const Icon(Icons.menu_book_rounded, color: Colors.white),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildNavItem(BuildContext context, IconData activeIcon, IconData inactiveIcon, int index, int selectedIndex, WidgetRef ref) {
    final isSelected = index == selectedIndex;
    return GestureDetector(
      onTap: () => _onItemTapped(index, context, ref),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(12),
        child: Icon(
          isSelected ? activeIcon : inactiveIcon,
          color: isSelected ? Colors.white : Colors.white54,
          size: 28,
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
        decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withOpacity(0.08)),
        child: Icon(icon, size: 22, color: Colors.white),
      ),
    );
  }
}