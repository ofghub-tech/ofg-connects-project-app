// lib/presentation/pages/home_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ofgconnects_mobile/logic/video_provider.dart';
import 'package:ofgconnects_mobile/presentation/widgets/video_card.dart';
import 'package:ofgconnects_mobile/presentation/widgets/shorts_card.dart';

// --- 1. Converted to ConsumerStatefulWidget ---
class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  // --- 2. Create Scroll Controllers ---
  final _scrollController = ScrollController();
  final _shortsScrollController = ScrollController();

  @override
  void initState() {
    super.initState();

    // --- 3. Add listener for vertical video list ---
    _scrollController.addListener(() {
      // If we're at the bottom, fetch more
      if (_scrollController.position.pixels >= 
          _scrollController.position.maxScrollExtent - 200) { // 200px buffer
        ref.read(videosListProvider.notifier).fetchMore();
      }
    });

    // --- 4. Add listener for horizontal shorts list ---
    _shortsScrollController.addListener(() {
      if (_shortsScrollController.position.pixels >=
          _shortsScrollController.position.maxScrollExtent - 100) { // 100px buffer
        ref.read(shortsListProvider.notifier).fetchMore();
      }
    });

    // --- 5. Fetch initial data (if not already loaded) ---
    // We run this in a post-frame callback to ensure ref is available
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(shortsListProvider.notifier).fetchFirstBatch();
      ref.read(videosListProvider.notifier).fetchFirstBatch();
    });
  }

  @override
  void dispose() {
    // --- 6. Dispose controllers ---
    _scrollController.dispose();
    _shortsScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // --- 7. Watch the new paginated providers ---
    final shortsState = ref.watch(shortsListProvider);
    final videosState = ref.watch(videosListProvider);

    // Handle initial loading state
    final isInitialLoading = videosState.items.isEmpty && videosState.isLoadingMore;

    return ListView(
      controller: _scrollController, // Assign main controller
      children: [
        // --- SHORTS SECTION ---
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text(
            'Shorts',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
        ),
        SizedBox(
          height: 250, // Constrain the height of the horizontal list
          child: (shortsState.items.isEmpty && shortsState.isLoadingMore)
              ? const Center(child: CircularProgressIndicator()) // Initial load
              : ListView.builder(
                  controller: _shortsScrollController, // Assign shorts controller
                  scrollDirection: Axis.horizontal,
                  itemCount: shortsState.items.length + (shortsState.hasMore ? 1 : 0),
                  itemBuilder: (context, index) {
                    // --- 8. Show loading indicator at the end ---
                    if (index == shortsState.items.length) {
                      return shortsState.isLoadingMore
                          ? const Center(child: CircularProgressIndicator())
                          : const SizedBox();
                    }
                    final short = shortsState.items[index];
                    return SizedBox(
                      width: 150,
                      child: ShortsCard(video: short),
                    );
                  },
                ),
        ),

        const Divider(height: 32),

        // --- VIDEOS SECTION ---
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text(
            'Videos',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
        ),
        if (isInitialLoading)
          const Center(child: CircularProgressIndicator())
        else if (videosState.items.isEmpty)
          const Center(child: Text('No videos found.'))
        else
          // --- 9. Build the videos list ---
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(), // Important inside another ListView
            itemCount: videosState.items.length + (videosState.hasMore ? 1 : 0),
            itemBuilder: (context, index) {
              // --- 10. Show loading indicator at the end ---
              if (index == videosState.items.length) {
                return videosState.isLoadingMore
                    ? const Center(child: CircularProgressIndicator())
                    : const SizedBox();
              }
              final video = videosState.items[index];
              return VideoCard(video: video);
            },
          ),
        
        // Add padding at the bottom so we can see the final loader
        const SizedBox(height: 40),
      ],
    );
  }
}