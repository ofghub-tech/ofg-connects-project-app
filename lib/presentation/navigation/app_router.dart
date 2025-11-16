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

// --- ADDED NEW PAGE IMPORTS ---
import 'package:ofgconnects_mobile/presentation/pages/history_page.dart';
import 'package:ofgconnects_mobile/presentation/pages/liked_videos_page.dart';
import 'package:ofgconnects_mobile/presentation/pages/watch_later_page.dart';
// ---

final router = GoRouter(
  initialLocation: '/', 
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const AuthGate(),
    ),
    GoRoute(
      path: '/login',
      builder: (context, state) => const LoginPage(),
    ),
    
    ShellRoute(
      builder: (context, state, child) {
        return MainAppShell(child: child);
      },
      routes: [
        GoRoute(
          path: '/home',
          builder: (context, state) => const HomePage(),
          routes: [
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
          path: '/shorts', // Stays the same path
          builder: (context, state) {
            // --- THIS IS THE FIX ---
            // Get the 'id' from the query parameter (e.g., /shorts?id=123)
            final videoId = state.uri.queryParameters['id'];
            // Pass it to the ShortsPage
            return ShortsPage(videoId: videoId);
            // --- END FIX ---
          },
        ),
        GoRoute(
          path: '/following',
          builder: (context, state) => const FollowingPage(),
        ),
        GoRoute(
          path: '/myspace',
          builder: (context, state) => const MySpacePage(),
        ),

        // --- User Library Routes (from previous step) ---
        GoRoute(
          path: '/history',
          builder: (context, state) => const HistoryPage(),
        ),
        GoRoute(
          path: '/liked',
          builder: (context, state) => const LikedVideosPage(),
        ),
        GoRoute(
          path: '/watchlater',
          builder: (context, state) => const WatchLaterPage(),
        ),
      ],
    ),
  ],
);