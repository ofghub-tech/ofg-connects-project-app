// lib/presentation/pages/home_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ofgconnects/logic/video_provider.dart';
import 'package:ofgconnects/logic/auth_provider.dart';
import 'package:ofgconnects/presentation/widgets/video_card.dart';
import 'package:ofgconnects/presentation/widgets/shorts_card.dart';
import 'package:ofgconnects/presentation/widgets/animate_in_effect.dart';
import 'package:ofgconnects/presentation/widgets/feed_ad_card.dart';
import 'package:ofgconnects/logic/shorts_provider.dart'; 

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
      // Trigger fetch earlier (300px from bottom) for smoother infinite scroll
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

  Future<void> _onRefresh() async {
    await Future.wait([
      ref.read(videosListProvider.notifier).refresh(),
      ref.read(shortsListProvider.notifier).refresh(),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final shortsState = ref.watch(shortsListProvider);
    final videosState = ref.watch(videosListProvider);
    
    // Config: How many items between ads?
    const int adFrequency = 6; 

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _onRefresh,
        color: Colors.blueAccent,
        backgroundColor: const Color(0xFF1E1E1E),
        edgeOffset: 60, 
        child: CustomScrollView(
          controller: _scrollController,
          physics: const BouncingScrollPhysics(),
          slivers: [
            
            // --- HEADER & SHORTS SECTION ---
            SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
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

            // --- MAIN FEED SECTION ---
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
                    // Logic: Insert an ad every 'adFrequency' items, but skip the very first slot
                    // Visual Sequence: Video, Video, Video, Video, Video, Video, AD, Video...
                    
                    if (index > 0 && index % adFrequency == 0) {
                      return const FeedAdCard();
                    }

                    // Calculate the true index in the data list
                    // We subtract the number of ads that have appeared so far
                    final int adsBefore = index ~/ adFrequency;
                    final int videoIndex = index - adsBefore;

                    // SAFETY CHECK: Ensure we don't go out of bounds
                    if (videoIndex >= videosState.items.length) {
                       // We are at the bottom. Show spinner if loading, else blank.
                       if (videosState.isLoadingMore) {
                          return const Padding(padding: EdgeInsets.all(24.0), child: Center(child: CircularProgressIndicator()));
                       }
                       return const SizedBox(height: 100); // Padding at bottom
                    }

                    return AnimateInEffect(
                      index: index,
                      child: VideoCard(video: videosState.items[videoIndex]),
                    );
                  },
                  // Calculate total count: Videos + Ads + 1 (for potential bottom loader)
                  childCount: videosState.items.length + (videosState.items.length ~/ adFrequency) + 1,
                ),
              ),
          ],
        ),
      ),
    );
  }
}