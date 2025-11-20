import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ofgconnects_mobile/logic/profile_provider.dart';
import 'package:ofgconnects_mobile/logic/subscription_provider.dart';
import 'package:ofgconnects_mobile/logic/auth_provider.dart';
import 'package:ofgconnects_mobile/models/video.dart';
import 'package:ofgconnects_mobile/presentation/widgets/video_card.dart';
// REMOVED: guest_login_dialog import

class UserProfilePage extends ConsumerStatefulWidget {
  final String userId;
  final String? initialName; 

  const UserProfilePage({super.key, required this.userId, this.initialName});

  @override
  ConsumerState<UserProfilePage> createState() => _UserProfilePageState();
}

class _UserProfilePageState extends ConsumerState<UserProfilePage> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
        ref.read(otherUserVideosProvider(widget.userId).notifier).fetchMore();
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(otherUserVideosProvider(widget.userId).notifier).fetchFirstBatch();
    });
  }

  @override
  void dispose() { _scrollController.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final currentUserId = ref.watch(authProvider).user?.$id;
    final isMe = currentUserId == widget.userId;
    if (isMe) {
       Future.microtask(() { if (mounted && GoRouterState.of(context).uri.path != '/myspace') context.go('/myspace'); });
       return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final videosState = ref.watch(otherUserVideosProvider(widget.userId));
    final statsAsync = ref.watch(otherUserStatsProvider(widget.userId));
    final isFollowingAsync = ref.watch(isFollowingProvider(widget.userId));
    String displayName = widget.initialName ?? 'User';
    if (videosState.items.isNotEmpty) displayName = videosState.items.first.creatorName;

    return Scaffold(
      body: NestedScrollView(
        controller: _scrollController,
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            SliverAppBar(
              expandedHeight: 350.0,
              pinned: true,
              leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.pop()),
              title: innerBoxIsScrolled ? Text(displayName) : null,
              flexibleSpace: FlexibleSpaceBar(
                background: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.blueAccent.withOpacity(0.2), Theme.of(context).scaffoldBackgroundColor]),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SafeArea(bottom: false, child: SizedBox(height: 20)),
                      CircleAvatar(radius: 45, backgroundColor: Colors.grey[800], child: Text(displayName.isNotEmpty ? displayName[0].toUpperCase() : 'U', style: const TextStyle(fontSize: 36, color: Colors.white, fontWeight: FontWeight.bold))),
                      const SizedBox(height: 12),
                      Text(displayName, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _buildStat(videosState.items.length.toString(), 'Videos'),
                          const SizedBox(width: 24),
                          statsAsync.when(
                            data: (stats) => Row(children: [_buildStat('${stats['followers']}', 'Followers'), const SizedBox(width: 24), _buildStat('${stats['following']}', 'Following')]),
                            loading: () => const SizedBox(width: 100, height: 20, child: Center(child: LinearProgressIndicator())),
                            error: (_,__) => const SizedBox.shrink(),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24), 
                      isFollowingAsync.when(
                        data: (isFollowing) => SizedBox(
                          height: 40, 
                          child: ElevatedButton(
                            onPressed: () async {
                              // REMOVED GUEST CHECK
                              final notifier = ref.read(subscriptionNotifierProvider.notifier);
                              if (isFollowing) {
                                notifier.unfollowUser(widget.userId);
                              } else {
                                final dummyVideo = Video(id: '', title: '', description: '', thumbnailUrl: '', videoUrl: '', creatorId: widget.userId, creatorName: displayName, category: '', tags: [], viewCount: 0, likeCount: 0, createdAt: DateTime.now());
                                notifier.followUser(dummyVideo);
                              }
                              ref.invalidate(otherUserStatsProvider(widget.userId));
                            },
                            style: ElevatedButton.styleFrom(backgroundColor: isFollowing ? Colors.grey[800] : Colors.blueAccent, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 32), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
                            child: Text(isFollowing ? 'Following' : 'Follow'),
                          ),
                        ),
                        loading: () => const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                        error: (_,__) => const Icon(Icons.error, color: Colors.red),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ];
        },
        body: videosState.isLoadingMore && videosState.items.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : videosState.items.isEmpty
            ? const Center(child: Text("No videos yet.", style: TextStyle(color: Colors.grey)))
            : ListView.builder(padding: const EdgeInsets.only(top: 0), physics: const NeverScrollableScrollPhysics(), shrinkWrap: true, itemCount: videosState.items.length + (videosState.hasMore ? 1 : 0), itemBuilder: (context, index) { if (index == videosState.items.length) return const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator())); return VideoCard(video: videosState.items[index]); }),
      ),
    );
  }

  Widget _buildStat(String value, String label) {
    return Column(mainAxisSize: MainAxisSize.min, children: [Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white)), Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey))]);
  }
}