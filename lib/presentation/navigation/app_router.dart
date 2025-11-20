// lib/presentation/navigation/app_router.dart
import 'package:go_router/go_router.dart';
import 'package:ofgconnects_mobile/models/status.dart'; // Required for casting 'extra'
import 'package:ofgconnects_mobile/presentation/pages/following_page.dart';
import 'package:ofgconnects_mobile/presentation/pages/home_page.dart';
import 'package:ofgconnects_mobile/presentation/pages/my_space_page.dart';
import 'package:ofgconnects_mobile/presentation/pages/shorts_page.dart';
import 'package:ofgconnects_mobile/presentation/pages/watch_page.dart';
import 'package:ofgconnects_mobile/presentation/widgets/auth_gate.dart';
import 'package:ofgconnects_mobile/presentation/widgets/main_app_shell.dart';

// --- Page Imports ---
import 'package:ofgconnects_mobile/presentation/pages/history_page.dart';
import 'package:ofgconnects_mobile/presentation/pages/liked_videos_page.dart';
import 'package:ofgconnects_mobile/presentation/pages/watch_later_page.dart';
import 'package:ofgconnects_mobile/presentation/pages/upload_page.dart';
import 'package:ofgconnects_mobile/presentation/pages/bible_page.dart';
import 'package:ofgconnects_mobile/presentation/pages/settings_page.dart';
import 'package:ofgconnects_mobile/presentation/pages/search_page.dart';
// --- NEW Feature Imports ---
import 'package:ofgconnects_mobile/presentation/pages/user_profile_page.dart';
import 'package:ofgconnects_mobile/presentation/pages/create_status_page.dart';
import 'package:ofgconnects_mobile/presentation/pages/status_view_page.dart';

final router = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const AuthGate(),
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

        // --- Other Routes inside the shell (Standard Pages) ---
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
          path: '/bible',
          builder: (context, state) => const BiblePage(),
        ),
        GoRoute(
          path: '/settings',
          builder: (context, state) => const SettingsPage(),
        ),
        GoRoute(
          path: '/search',
          builder: (context, state) => const SearchPage(),
        ),

        // --- NEW: User Profile Route ---
        GoRoute(
          path: '/profile/:userId',
          builder: (context, state) {
            final userId = state.pathParameters['userId']!;
            final name = state.uri.queryParameters['name'];
            return UserProfilePage(userId: userId, initialName: name);
          },
        ),

        // --- NEW: Status (Story) Routes ---
        GoRoute(
          path: '/create-status',
          builder: (context, state) => const CreateStatusPage(),
        ),
        GoRoute(
          path: '/view-status',
          builder: (context, state) {
             // We pass the list of Status objects via the 'extra' parameter
             final statuses = state.extra as List<Status>; 
             return StatusViewPage(statuses: statuses);
          },
        ),
      ],
    ),
  ],
);