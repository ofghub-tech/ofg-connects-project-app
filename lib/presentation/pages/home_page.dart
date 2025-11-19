// lib/presentation/pages/home_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ofgconnects_mobile/logic/video_provider.dart';
import 'package:ofgconnects_mobile/presentation/widgets/video_card.dart';
import 'package:ofgconnects_mobile/presentation/widgets/shorts_card.dart';
import 'package:ofgconnects_mobile/presentation/widgets/animate_in_effect.dart'; // Import the new animation

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  final _scrollController = ScrollController();
  final _shortsScrollController = ScrollController();

  @override
  void initState() {
    super.initState();

    _scrollController.addListener(() {
      if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 300) {
        ref.read(videosListProvider.notifier).fetchMore();
      }
    });

    _shortsScrollController.addListener(() {
      if (_shortsScrollController.position.pixels >= _shortsScrollController.position.maxScrollExtent - 100) {
        ref.read(shortsListProvider.notifier).fetchMore();
      }
    });

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
      body: CustomScrollView(
        controller: _scrollController,
        physics: const BouncingScrollPhysics(),
        slivers: [
          // --- 1. Shorts Section ---
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                  child: Row(
                    children: [
                      const Icon(Icons.bolt_rounded, color: Colors.blueAccent),
                      const SizedBox(width: 8),
                      Text(
                        'Shorts',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  height: 260,
                  child: (shortsState.items.isEmpty && shortsState.isLoadingMore)
                      ? const Center(child: CircularProgressIndicator())
                      : ListView.builder(
                          controller: _shortsScrollController,
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          itemCount: shortsState.items.length + (shortsState.hasMore ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (index == shortsState.items.length) {
                              return Center(
                                child: shortsState.isLoadingMore
                                    ? const Padding(padding: EdgeInsets.all(16.0), child: CircularProgressIndicator())
                                    : const SizedBox(width: 50),
                              );
                            }
                            // Animated Shorts Card
                            return AnimateInEffect(
                              index: index,
                              child: SizedBox(
                                width: 160,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 4.0),
                                  child: ShortsCard(video: shortsState.items[index]),
                                ),
                              ),
                            );
                          },
                        ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Divider(height: 1, thickness: 1, color: Colors.white10),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Text(
                    'Recommended',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ),
              ],
            ),
          ),

          // --- 2. Videos List ---
          if (videosState.items.isEmpty && videosState.isLoadingMore)
            const SliverFillRemaining(child: Center(child: CircularProgressIndicator()))
          else if (videosState.items.isEmpty)
             SliverToBoxAdapter(
              child: SizedBox(
                height: 300,
                child: Center(child: Text('No videos found.', style: TextStyle(color: Colors.white.withOpacity(0.5)))),
              ),
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  if (index == videosState.items.length) {
                    return videosState.isLoadingMore
                        ? const Padding(padding: EdgeInsets.all(24.0), child: Center(child: CircularProgressIndicator()))
                        : const SizedBox(height: 100); // Bottom padding to clear nav bar
                  }
                  
                  // Animated Video Card
                  return AnimateInEffect(
                    index: index,
                    child: VideoCard(video: videosState.items[index]),
                  );
                },
                childCount: videosState.items.length + (videosState.hasMore ? 1 : 0),
              ),
            ),
        ],
      ),
    );
  }
}