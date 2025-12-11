import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ofgconnects_mobile/models/status.dart'; 
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
import 'package:ofgconnects_mobile/presentation/pages/user_profile_page.dart';
import 'package:ofgconnects_mobile/presentation/pages/create_status_page.dart';
import 'package:ofgconnects_mobile/presentation/pages/status_view_page.dart';
import 'package:ofgconnects_mobile/presentation/pages/edit_profile_page.dart'; // <--- ADDED

final routerProvider = Provider<GoRouter>((ref) {
  return router;
});

final router = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const AuthGate(),
    ),

    // ShellRoute wraps the main tabs with the Navigation Bar
    ShellRoute(
      builder: (context, state, child) {
        return MainAppShell(child: child);
      },
      routes: [
        // Tab 1: Home
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
        // Tab 2: Shorts
        GoRoute(
          path: '/shorts',
          builder: (context, state) {
            final videoId = state.uri.queryParameters['id'];
            return ShortsPage(videoId: videoId);
          },
        ),
        // Tab 3: Upload
        GoRoute(
          path: '/upload',
          builder: (context, state) => const UploadPage(),
        ),
        // Tab 4: Following
        GoRoute(
          path: '/following',
          builder: (context, state) => const FollowingPage(),
        ),
        // Tab 5: My Space
        GoRoute(
          path: '/myspace',
          builder: (context, state) => const MySpacePage(),
        ),

        // Other Routes
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
        GoRoute(
          path: '/profile/:userId',
          builder: (context, state) {
            final userId = state.pathParameters['userId']!;
            final name = state.uri.queryParameters['name'];
            return UserProfilePage(userId: userId, initialName: name);
          },
        ),
        GoRoute(
          path: '/create-status',
          builder: (context, state) => const CreateStatusPage(),
        ),
        GoRoute(
          path: '/view-status',
          builder: (context, state) {
             final statuses = state.extra as List<Status>; 
             return StatusViewPage(statuses: statuses);
          },
        ),
        GoRoute(
          path: '/edit-profile', // <--- REGISTERED
          builder: (context, state) => const EditProfilePage(),
        ),
      ],
    ),
  ],
);