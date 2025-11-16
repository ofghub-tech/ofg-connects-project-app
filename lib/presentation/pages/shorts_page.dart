// lib/presentation/pages/shorts_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ofgconnects_mobile/logic/shorts_provider.dart';
import 'package:ofgconnects_mobile/logic/video_provider.dart';
import 'package:ofgconnects_mobile/presentation/widgets/shorts_player.dart';

// 1. Convert to ConsumerStatefulWidget
class ShortsPage extends ConsumerStatefulWidget {
  // 2. Accept an optional videoId to jump to
  final String? videoId;
  const ShortsPage({super.key, this.videoId});

  @override
  ConsumerState<ShortsPage> createState() => _ShortsPageState();
}

class _ShortsPageState extends ConsumerState<ShortsPage> {
  // 3. Create a PageController to control the PageView
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 4. Use the new shortsListProvider
    final shortsAsync = ref.watch(shortsListProvider);

    return shortsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text('Error: $err')),
      data: (videos) {
        if (videos.isEmpty) {
          return const Center(child: Text('No shorts found.'));
        }
        
        // 5. Check if we need to jump to a specific video
        if (widget.videoId != null) {
          final index = videos.indexWhere((v) => v.id == widget.videoId);
          if (index != -1) {
            // Use addPostFrameCallback to jump after the build
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (_pageController.hasClients) {
                _pageController.jumpToPage(index);
                // Set the active provider so the video plays
                ref.read(activeShortsIndexProvider.notifier).state = index;
              }
            });
          }
        }

        return PageView.builder(
          controller: _pageController, // 6. Assign the controller
          scrollDirection: Axis.horizontal, // 7. SET TO HORIZONTAL
          itemCount: videos.length,
          onPageChanged: (index) {
            // This provider controls which video is playing
            ref.read(activeShortsIndexProvider.notifier).state = index;
          },
          itemBuilder: (context, index) {
            final video = videos[index];
            return ShortsPlayer(
              video: video,
              index: index,
            );
          },
        );
      },
    );
  }
}