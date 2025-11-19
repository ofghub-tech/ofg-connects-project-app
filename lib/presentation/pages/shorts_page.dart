// lib/presentation/pages/shorts_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ofgconnects_mobile/logic/shorts_provider.dart';
import 'package:ofgconnects_mobile/logic/video_provider.dart';
import 'package:ofgconnects_mobile/presentation/widgets/shorts_player.dart';

class ShortsPage extends ConsumerStatefulWidget {
  final String? videoId;
  const ShortsPage({super.key, this.videoId});

  @override
  ConsumerState<ShortsPage> createState() => _ShortsPageState();
}

class _ShortsPageState extends ConsumerState<ShortsPage> {
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();

    // Initializes the feed. If widget.videoId is not null, it loads that specific
    // video first so the user lands on the correct content.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(shortsListProvider.notifier).init(widget.videoId);
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final shortsState = ref.watch(shortsListProvider);
    final shorts = shortsState.items;

    // Loading state
    if (shorts.isEmpty && shortsState.isLoadingMore) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // Empty state
    if (shorts.isEmpty && !shortsState.hasMore) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Text(
            'No shorts found.', 
            style: TextStyle(color: Colors.white),
          )
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: PageView.builder(
        controller: _pageController,
        scrollDirection: Axis.vertical,
        itemCount: shorts.length + (shortsState.hasMore ? 1 : 0),
        onPageChanged: (index) {
          // Update the active index so the player knows when to play/pause
          ref.read(activeShortsIndexProvider.notifier).state = index;

          // Fetch more when nearing the end
          if (index >= shorts.length - 2 && shortsState.hasMore) {
            ref.read(shortsListProvider.notifier).fetchMore();
          }
        },
        itemBuilder: (context, index) {
          // Loader at the end
          if (index == shorts.length) {
            return const Center(child: CircularProgressIndicator());
          }
          
          return ShortsPlayer(
            video: shorts[index],
            index: index,
          );
        },
      ),
    );
  }
}