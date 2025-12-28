// lib/presentation/pages/liked_videos_page.dart
import 'package:flutter/material.dart'; // <-- THIS WAS THE FIX
import 'package:flutter_riverpod/flutter_riverpod.dart';
// We import the new widget
import 'package:ofgconnects/presentation/widgets/linked_video_card.dart';
// We import the provider file
import 'package:ofgconnects/logic/video_provider.dart';

// 1. Convert to ConsumerStatefulWidget
class LikedVideosPage extends ConsumerStatefulWidget {
  const LikedVideosPage({Key? key}) : super(key: key);

  @override
  ConsumerState<LikedVideosPage> createState() => _LikedVideosPageState();
}

class _LikedVideosPageState extends ConsumerState<LikedVideosPage> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();

    // 2. Add listener for pagination
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 200) {
        // 3. Fetch more liked videos
        ref.read(paginatedLikedVideosProvider.notifier).fetchMore();
      }
    });

    // 4. Fetch initial batch
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(paginatedLikedVideosProvider.notifier).fetchFirstBatch();
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 5. Watch the new paginated provider
    final likedLinksState = ref.watch(paginatedLikedVideosProvider);
    final likedLinks = likedLinksState.items;

    // Handle initial loading
    final isInitialLoading = likedLinks.isEmpty && likedLinksState.isLoadingMore;

    return Scaffold(
      appBar: AppBar(title: const Text('Liked Videos')),
      body: isInitialLoading
          ? const Center(child: CircularProgressIndicator())
          : likedLinks.isEmpty
              ? const Center(child: Text('You have not liked any videos.'))
              : ListView.builder(
                  controller: _scrollController,
                  itemCount: likedLinks.length + (likedLinksState.hasMore ? 1 : 0),
                  itemBuilder: (context, index) {
                    // 6. Show loading indicator at the end
                    if (index == likedLinks.length) {
                      return likedLinksState.isLoadingMore
                          ? const Center(child: CircularProgressIndicator())
                          : const SizedBox();
                    }
                    
                    // 7. Use the new LinkedVideoCard
                    final linkDocument = likedLinks[index];
                    return LinkedVideoCard(
                      linkDocument: linkDocument,
                      videoIdField: 'videoId', // From your appwrite.config.json
                    );
                  },
                ),
    );
  }
}