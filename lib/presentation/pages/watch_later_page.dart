// lib/presentation/pages/watch_later_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// We import the new widget
import 'package:ofgconnects/presentation/widgets/linked_video_card.dart';
// We import the provider file
import 'package:ofgconnects/logic/video_provider.dart';

// 1. Convert to ConsumerStatefulWidget
class WatchLaterPage extends ConsumerStatefulWidget {
  const WatchLaterPage({Key? key}) : super(key: key);

  @override
  ConsumerState<WatchLaterPage> createState() => _WatchLaterPageState();
}

class _WatchLaterPageState extends ConsumerState<WatchLaterPage> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();

    // 2. Add listener for pagination
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 200) {
        // 3. Fetch more watch later videos
        ref.read(paginatedWatchLaterProvider.notifier).fetchMore();
      }
    });

    // 4. Fetch initial batch
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(paginatedWatchLaterProvider.notifier).fetchFirstBatch();
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
    final watchLaterLinksState = ref.watch(paginatedWatchLaterProvider);
    final watchLaterLinks = watchLaterLinksState.items;

    // Handle initial loading
    final isInitialLoading = watchLaterLinks.isEmpty && watchLaterLinksState.isLoadingMore;

    return Scaffold(
      appBar: AppBar(title: const Text('Watch Later')),
      body: isInitialLoading
          ? const Center(child: CircularProgressIndicator())
          : watchLaterLinks.isEmpty
              ? const Center(child: Text('Your watch later list is empty.'))
              : ListView.builder(
                  controller: _scrollController,
                  itemCount: watchLaterLinks.length + (watchLaterLinksState.hasMore ? 1 : 0),
                  itemBuilder: (context, index) {
                    // 6. Show loading indicator at the end
                    if (index == watchLaterLinks.length) {
                      return watchLaterLinksState.isLoadingMore
                          ? const Center(child: CircularProgressIndicator())
                          : const SizedBox();
                    }
                    
                    // 7. Use the new LinkedVideoCard
                    final linkDocument = watchLaterLinks[index];
                    return LinkedVideoCard(
                      linkDocument: linkDocument,
                      videoIdField: 'videoId', // From your appwrite.config.json
                    );
                  },
                ),
    );
  }
}