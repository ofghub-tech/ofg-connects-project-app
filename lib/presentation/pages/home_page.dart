// lib/presentation/pages/home_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ofgconnects_mobile/logic/video_provider.dart';
import 'package:ofgconnects_mobile/logic/auth_provider.dart';
import 'package:ofgconnects_mobile/presentation/widgets/video_card.dart';
import 'package:ofgconnects_mobile/presentation/widgets/shorts_card.dart';
import 'package:ofgconnects_mobile/presentation/widgets/animate_in_effect.dart';
// --- NEW IMPORTS ---
import 'package:ofgconnects_mobile/logic/status_provider.dart';
import 'package:ofgconnects_mobile/presentation/widgets/status_bubble.dart';

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
      // Fetch statuses
      ref.read(statusProvider.notifier).fetchStatuses();
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
    final statusState = ref.watch(statusProvider);
    final currentUser = ref.watch(authProvider).user;

    return Scaffold(
      body: CustomScrollView(
        controller: _scrollController,
        physics: const BouncingScrollPhysics(),
        slivers: [
          
          // --- 0. STATUS SECTION ---
          SliverToBoxAdapter(
            child: SizedBox(
              height: 110,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                children: [
                  // My Status Button
                  GestureDetector(
                    onTap: () => context.push('/create-status'),
                    child: Container(
                      margin: const EdgeInsets.only(right: 8),
                      child: Column(
                        children: [
                          Stack(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(3),
                                decoration: const BoxDecoration(shape: BoxShape.circle),
                                child: CircleAvatar(
                                  radius: 33,
                                  backgroundColor: Colors.grey[800],
                                  backgroundImage: (currentUser?.prefs.data['avatar'] != null)
                                    ? NetworkImage(currentUser!.prefs.data['avatar'])
                                    : null,
                                  child: (currentUser?.prefs.data['avatar'] == null) 
                                    ? const Icon(Icons.person, color: Colors.white) : null,
                                ),
                              ),
                              Positioned(
                                bottom: 0, right: 0,
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(color: Colors.blueAccent, shape: BoxShape.circle),
                                  child: const Icon(Icons.add, size: 14, color: Colors.white),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          const Text("My Status", style: TextStyle(color: Colors.white70, fontSize: 12)),
                        ],
                      ),
                    ),
                  ),
                  
                  // Other Users' Statuses
                  // FIX: Removed 'const' because CircularProgressIndicator is not const
                  if (statusState.isLoading && statusState.groupedStatuses.isEmpty)
                     const Padding(padding: EdgeInsets.only(left:16), child: Center(child: CircularProgressIndicator())),
                  
                  ...statusState.groupedStatuses.entries.map((entry) {
                    // Don't show my own status in the feed list here
                    if (entry.key == currentUser?.$id) return const SizedBox.shrink();
                    
                    return StatusBubble(
                      statuses: entry.value,
                      onTap: () {
                        context.push('/view-status', extra: entry.value);
                      },
                    );
                  }).toList(),
                ],
              ),
            ),
          ),

          // --- 1. Shorts Section ---
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
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
                      // FIX: Removed 'const' here
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
                                    // FIX: Removed 'const' here
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

          // --- 2. Videos List ---
          // FIX: Removed 'const' here
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
                        // FIX: Removed 'const' here
                        ? const Padding(padding: EdgeInsets.all(24.0), child: Center(child: CircularProgressIndicator()))
                        : const SizedBox(height: 100); 
                  }
                  
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