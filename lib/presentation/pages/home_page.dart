// lib/presentation/pages/home_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ofgconnects_mobile/logic/video_provider.dart';
import 'package:ofgconnects_mobile/presentation/widgets/video_card.dart';
import 'package:ofgconnects_mobile/presentation/widgets/shorts_card.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  // We still use separate controllers for logic, but the main UI uses CustomScrollView
  final _scrollController = ScrollController();
  final _shortsScrollController = ScrollController();

  @override
  void initState() {
    super.initState();

    // 1. Listener for the main vertical scroll (Videos)
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 200) {
        ref.read(videosListProvider.notifier).fetchMore();
      }
    });

    // 2. Listener for the horizontal scroll (Shorts)
    _shortsScrollController.addListener(() {
      if (_shortsScrollController.position.pixels >=
          _shortsScrollController.position.maxScrollExtent - 100) {
        ref.read(shortsListProvider.notifier).fetchMore();
      }
    });

    // 3. Initial Data Fetch
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(shortsListProvider.notifier).fetchFirstBatch();
      ref.read(videosListProvider.notifier).fetchFirstBatch();
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _shortsScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final shortsState = ref.watch(shortsListProvider);
    final videosState = ref.watch(videosListProvider);

    return Scaffold(
      // Use CustomScrollView for high-performance mixed lists
      body: CustomScrollView(
        controller: _scrollController,
        slivers: [
          // --- 1. Shorts Section (Header) ---
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Text(
                    'Shorts',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ),
                SizedBox(
                  height: 250,
                  child: (shortsState.items.isEmpty && shortsState.isLoadingMore)
                      ? const Center(child: CircularProgressIndicator())
                      : ListView.builder(
                          controller: _shortsScrollController,
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          itemCount: shortsState.items.length + (shortsState.hasMore ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (index == shortsState.items.length) {
                              return Center(
                                child: shortsState.isLoadingMore
                                    ? const Padding(
                                        padding: EdgeInsets.all(16.0),
                                        child: CircularProgressIndicator(),
                                      )
                                    : const SizedBox(width: 50),
                              );
                            }
                            return SizedBox(
                              width: 150,
                              child: Padding(
                                padding: const EdgeInsets.only(right: 8.0),
                                child: ShortsCard(video: shortsState.items[index]),
                              ),
                            );
                          },
                        ),
                ),
                const Divider(height: 32, thickness: 1),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: Text(
                    'Videos',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ),
              ],
            ),
          ),

          // --- 2. Videos List (Lazy Loaded Sliver) ---
          if (videosState.items.isEmpty && videosState.isLoadingMore)
            const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
            )
          else if (videosState.items.isEmpty)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(32.0),
                child: Center(child: Text('No videos found.')),
              ),
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  // Loader at bottom
                  if (index == videosState.items.length) {
                    return videosState.isLoadingMore
                        ? const Padding(
                            padding: EdgeInsets.all(24.0),
                            child: Center(child: CircularProgressIndicator()),
                          )
                        : const SizedBox(height: 80); // Bottom padding
                  }
                  
                  // Video Item
                  return VideoCard(video: videosState.items[index]);
                },
                // Count includes +1 for the loader
                childCount: videosState.items.length + (videosState.hasMore ? 1 : 0),
              ),
            ),
        ],
      ),
    );
  }
}