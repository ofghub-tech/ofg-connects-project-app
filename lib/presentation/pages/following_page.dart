// lib/presentation/pages/following_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ofgconnects_mobile/logic/video_provider.dart';
import 'package:ofgconnects_mobile/presentation/widgets/video_card.dart';

// 1. Convert to ConsumerStatefulWidget
class FollowingPage extends ConsumerStatefulWidget {
  const FollowingPage({super.key});

  @override
  ConsumerState<FollowingPage> createState() => _FollowingPageState();
}

// 2. Make sure state extends ConsumerState
class _FollowingPageState extends ConsumerState<FollowingPage> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();

    // 3. Add listener for pagination
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 200) {
        // 4. Fetch more following videos
        ref.read(paginatedFollowingProvider.notifier).fetchMore();
      }
    });

    // 5. Fetch initial batch
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(paginatedFollowingProvider.notifier).fetchFirstBatch();
    });
  }

   @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  // 6. Make sure build method signature is correct
  @override
  Widget build(BuildContext context) {
    // 7. Watch the new paginated provider
    final followingState = ref.watch(paginatedFollowingProvider);
    final videos = followingState.items;

    // Handle initial loading
    final isInitialLoading = videos.isEmpty && followingState.isLoadingMore;

    // 8. Return the Scaffold (not inside a Consumer)
    return Scaffold(
      body: isInitialLoading
          ? const Center(child: CircularProgressIndicator())
          : videos.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Text(
                      'You are not following anyone, or the users you follow haven\'t posted videos yet.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : ListView.builder(
                  controller: _scrollController,
                  itemCount: videos.length + (followingState.hasMore ? 1 : 0),
                  itemBuilder: (context, index) {
                    // 9. Show loading indicator at the end
                    if (index == videos.length) {
                      return followingState.isLoadingMore
                          ? const Center(child: CircularProgressIndicator())
                          : const SizedBox();
                    }
                    
                    // 10. Use the standard VideoCard
                    final video = videos[index];
                    return VideoCard(video: video);
                  },
                ),
    );
  }
}