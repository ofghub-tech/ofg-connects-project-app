// lib/presentation/pages/history_page.dart
import 'package:flutter/material.dart'; // <-- THIS WAS THE FIX
import 'package:flutter_riverpod/flutter_riverpod.dart';
// We import the new widget
import 'package:ofgconnects_mobile/presentation/widgets/linked_video_card.dart';
// We import the provider file
import 'package:ofgconnects_mobile/logic/video_provider.dart';

// 1. Convert to ConsumerStatefulWidget
class HistoryPage extends ConsumerStatefulWidget {
  const HistoryPage({Key? key}) : super(key: key);

  @override
  ConsumerState<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends ConsumerState<HistoryPage> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();

    // 2. Add listener for pagination
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 200) {
        // 3. Fetch more history videos
        ref.read(paginatedHistoryProvider.notifier).fetchMore();
      }
    });

    // 4. Fetch initial batch
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(paginatedHistoryProvider.notifier).fetchFirstBatch();
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
    final historyLinksState = ref.watch(paginatedHistoryProvider);
    final historyLinks = historyLinksState.items;

    // Handle initial loading
    final isInitialLoading = historyLinks.isEmpty && historyLinksState.isLoadingMore;

    return Scaffold(
      appBar: AppBar(title: const Text('History')),
      body: isInitialLoading
          ? const Center(child: CircularProgressIndicator())
          : historyLinks.isEmpty
              ? const Center(child: Text('No videos in your history.'))
              : ListView.builder(
                  controller: _scrollController,
                  itemCount: historyLinks.length + (historyLinksState.hasMore ? 1 : 0),
                  itemBuilder: (context, index) {
                    // 6. Show loading indicator at the end
                    if (index == historyLinks.length) {
                      return historyLinksState.isLoadingMore
                          ? const Center(child: CircularProgressIndicator())
                          : const SizedBox();
                    }
                    
                    // 7. Use the new LinkedVideoCard
                    final linkDocument = historyLinks[index];
                    return LinkedVideoCard(
                      linkDocument: linkDocument,
                      videoIdField: 'videoId', // From your appwrite.config.json
                    );
                  },
                ),
    );
  }
}