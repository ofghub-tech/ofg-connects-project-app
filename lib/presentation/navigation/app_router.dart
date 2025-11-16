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
import 'package:ofgconnects_mobile/presentation/pages/upload_page.dart';
import 'package:ofgconnects_mobile/presentation/pages/bible_page.dart'; // <-- BIBLE IMPORT
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

    // This ShellRoute wraps all pages that have the bottom nav bar
    ShellRoute(
      builder: (context, state, child) {
        return MainAppShell(child: child);
      },
      routes: [
        // --- Tab 1: Home ---
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
        // --- Tab 2: Shorts ---
        GoRoute(
          path: '/shorts',
          builder: (context, state) {
            final videoId = state.uri.queryParameters['id'];
            return ShortsPage(videoId: videoId);
          },
        ),
        // --- Tab 3: Upload ---
        GoRoute(
          path: '/upload',
          builder: (context, state) => const UploadPage(),
        ),
        // --- Tab 4: Following ---
        GoRoute(
          path: '/following',
          builder: (context, state) => const FollowingPage(),
        ),
        // --- Tab 5: My Space ---
        GoRoute(
          path: '/myspace',
          builder: (context, state) => const MySpacePage(),
        ),

        // --- Routes accessible from My Space or Drawer ---
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
        GoRoute(
          path: '/bible', // <-- BIBLE ROUTE
          builder: (context, state) => const BiblePage(),
        ),
      ],
    ),
  ],
);