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

import 'package:ofgconnects_mobile/presentation/pages/history_page.dart';
import 'package:ofgconnects_mobile/presentation/pages/watch_later_page.dart';
import 'package:ofgconnects_mobile/presentation/pages/upload_page.dart';
import 'package:ofgconnects_mobile/presentation/pages/bible_page.dart';
import 'package:ofgconnects_mobile/presentation/pages/settings_page.dart';
import 'package:ofgconnects_mobile/presentation/pages/search_page.dart';
import 'package:ofgconnects_mobile/presentation/pages/user_profile_page.dart';
import 'package:ofgconnects_mobile/presentation/pages/create_status_page.dart';
import 'package:ofgconnects_mobile/presentation/pages/status_view_page.dart';
import 'package:ofgconnects_mobile/presentation/pages/edit_profile_page.dart';

final routerProvider = Provider<GoRouter>((ref) => router);

final router = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const AuthGate(),
    ),
    ShellRoute(
      builder: (context, state, child) => MainAppShell(child: child),
      routes: [
        GoRoute(path: '/home', builder: (context, state) => const HomePage()),
        GoRoute(
          path: '/shorts',
          builder: (context, state) {
            final videoId = state.uri.queryParameters['id'];
            return ShortsPage(videoId: videoId);
          },
        ),
        GoRoute(path: '/upload', builder: (context, state) => const UploadPage()),
        GoRoute(path: '/following', builder: (context, state) => const FollowingPage()),
        GoRoute(path: '/myspace', builder: (context, state) => const MySpacePage()),
        GoRoute(
          path: '/watch/:videoId',
          builder: (context, state) => WatchPage(videoId: state.pathParameters['videoId']!),
        ),
        GoRoute(path: '/history', builder: (context, state) => const HistoryPage()),
        GoRoute(path: '/watchlater', builder: (context, state) => const WatchLaterPage()),
        GoRoute(path: '/bible', builder: (context, state) => const BiblePage()),
        GoRoute(path: '/settings', builder: (context, state) => const SettingsPage()),
        GoRoute(path: '/search', builder: (context, state) => const SearchPage()),
        GoRoute(
          path: '/profile/:userId',
          builder: (context, state) => UserProfilePage(
            userId: state.pathParameters['userId']!,
            initialName: state.uri.queryParameters['name'],
          ),
        ),
        GoRoute(path: '/create-status', builder: (context, state) => const CreateStatusPage()),
        GoRoute(
          path: '/view-status',
          builder: (context, state) => StatusViewPage(statuses: state.extra as List<Status>),
        ),
        GoRoute(path: '/edit-profile', builder: (context, state) => const EditProfilePage()),
      ],
    ),
  ],
);