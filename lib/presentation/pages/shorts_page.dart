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
  bool _jumpedToInitialVideo = false;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();

    // Fetch initial batch of shorts
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(shortsListProvider.notifier).fetchFirstBatch();
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 1. Watch the new pagination state provider
    final shortsState = ref.watch(shortsListProvider);
    final shorts = shortsState.items;

    // 2. Handle initial loading
    if (shorts.isEmpty && shortsState.isLoadingMore) {
      return const Center(child: CircularProgressIndicator());
    }

    // 3. Handle no shorts found
    if (shorts.isEmpty && !shortsState.hasMore) {
      return const Center(child: Text('No shorts found.'));
    }

    // 4. Logic to jump to a specific video ID (if provided)
    if (widget.videoId != null && shorts.isNotEmpty && !_jumpedToInitialVideo) {
      final index = shorts.indexWhere((v) => v.id == widget.videoId);
      if (index != -1) {
        _jumpedToInitialVideo = true; // Mark as jumped
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_pageController.hasClients) {
            _pageController.jumpToPage(index);
            // Set the active provider so the video plays
            ref.read(activeShortsIndexProvider.notifier).state = index;
          }
        });
      }
    }

    // 5. Build the PageView
    return PageView.builder(
      controller: _pageController,
      scrollDirection: Axis.horizontal, // Keep horizontal as per your file
      itemCount: shorts.length + (shortsState.hasMore ? 1 : 0), // Add 1 for loader
      onPageChanged: (index) {
        // This provider controls which video is playing
        ref.read(activeShortsIndexProvider.notifier).state = index;

        // 6. Fetch more shorts when user gets near the end
        if (index >= shorts.length - 2 && shortsState.hasMore) {
          ref.read(shortsListProvider.notifier).fetchMore();
        }
      },
      itemBuilder: (context, index) {
        // 7. Show loader at the end
        if (index == shorts.length) {
          return shortsState.isLoadingMore
              ? const Center(child: CircularProgressIndicator())
              : const SizedBox();
        }
        
        final video = shorts[index];
        return ShortsPlayer(
          video: video,
          index: index,
        );
      },
    );
  }
}