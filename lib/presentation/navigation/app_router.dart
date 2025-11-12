// lib/presentation/navigation/app_router.dart
import 'package:go_router/go_router.dart';
import 'package:ofgconnects_mobile/presentation/pages/following_page.dart';
import 'package:ofgconnects_mobile/presentation/pages/home_page.dart';
import 'package:ofgconnects_mobile/presentation/pages/login_page.dart';
import 'package:ofgconnects_mobile/presentation/pages/my_space_page.dart';
import 'package:ofgconnects_mobile/presentation/pages/shorts_page.dart';
import 'package:ofgconnects_mobile/presentation/pages/watch_page.dart';
import 'package:ofgconnects_mobile/presentation/widgets/auth_gate.dart';
import 'package:ofgconnects_mobile/presentation/widgets/main_app_shell.dart';

final router = GoRouter(
  initialLocation: '/', // Start at the AuthGate
  routes: [
    // This route shows the loading screen while checking auth
    GoRoute(
      path: '/',
      builder: (context, state) => const AuthGate(),
    ),
    // This route is for the login page
    GoRoute(
      path: '/login',
      builder: (context, state) => const LoginPage(),
    ),
    
    // This ShellRoute wraps all main pages with the Bottom Nav Bar
    ShellRoute(
      builder: (context, state, child) {
        // MainAppShell will now display 'child' as the main content
        return MainAppShell(child: child);
      },
      routes: [
        GoRoute(
          path: '/home',
          builder: (context, state) => const HomePage(),
          routes: [
            // This is the new nested route for the WatchPage
            // It will have a path like /home/watch/VIDEO_ID
            GoRoute(
              path: 'watch/:videoId',
              builder: (context, state) {
                final videoId = state.pathParameters['videoId']!;
                return WatchPage(videoId: videoId);
              },
            ),
          ],
        ),
        GoRoute(
          path: '/shorts',
          builder: (context, state) => const ShortsPage(),
        ),
        GoRoute(
          path: '/following',
          builder: (context, state) => const FollowingPage(),
        ),
        GoRoute(
          path: '/myspace',
          builder: (context, state) => const MySpacePage(),
        ),
      ],
    ),
  ],
);