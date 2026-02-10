// lib/presentation/pages/following_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ofgconnects/logic/following_provider.dart';
import 'package:ofgconnects/logic/subscription_provider.dart';

class FollowingPage extends ConsumerStatefulWidget {
  const FollowingPage({super.key});

  @override
  ConsumerState<FollowingPage> createState() => _FollowingPageState();
}

class _FollowingPageState extends ConsumerState<FollowingPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(followingListProvider.notifier).fetchFirstBatch();
    });
  }

  @override
  Widget build(BuildContext context) {
    final followingState = ref.watch(followingListProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      appBar: AppBar(
        title: const Text("Following", style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: NotificationListener<ScrollNotification>(
        onNotification: (ScrollNotification scrollInfo) {
          // FIX: Trigger Load More when scrolling to bottom
          if (!followingState.isLoadingMore && 
              followingState.hasMore && 
              scrollInfo.metrics.pixels >= scrollInfo.metrics.maxScrollExtent - 200) {
            ref.read(followingListProvider.notifier).fetchNextBatch();
          }
          return false;
        },
        child: followingState.isLoadingMore && followingState.items.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : followingState.items.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.people_outline, size: 60, color: Colors.grey),
                        SizedBox(height: 16),
                        Text("You aren't following anyone yet.", style: TextStyle(color: Colors.grey)),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: followingState.items.length + (followingState.hasMore ? 1 : 0),
                    separatorBuilder: (c, i) => const Divider(color: Colors.white10),
                    itemBuilder: (context, index) {
                      // Show loading spinner at the bottom
                      if (index == followingState.items.length) {
                        return const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator()));
                      }

                      final doc = followingState.items[index];
                      final creatorId = doc.data['followingId'];
                      final creatorName = doc.data['followingUsername'] ?? 'User';

                      return ListTile(
                        onTap: () => context.push('/profile/$creatorId'),
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                          backgroundColor: Colors.blueAccent,
                          radius: 24,
                          child: Text(creatorName.isNotEmpty ? creatorName[0].toUpperCase() : 'U', 
                            style: const TextStyle(color: Colors.white, fontSize: 20)),
                        ),
                        title: Text(creatorName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                        subtitle: const Text("Content Creator", style: TextStyle(color: Colors.grey)),
                        trailing: SizedBox(
                          height: 32,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white.withOpacity(0.1),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                            ),
                            onPressed: () async {
                              // 1. Call API
                              await ref.read(subscriptionNotifierProvider.notifier).unfollowUser(creatorId);
                              
                              // 2. FIX: Instantly remove from UI instead of reloading everything
                              if (context.mounted) {
                                ref.read(followingListProvider.notifier).removeUserLocally(creatorId);
                              }
                            },
                            child: const Text("Unfollow", style: TextStyle(fontSize: 12)),
                          ),
                        ),
                      );
                    },
                  ),
      ),
    );
  }
}