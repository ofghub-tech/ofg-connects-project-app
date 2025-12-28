import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:ofgconnects/logic/profile_provider.dart';
import 'package:ofgconnects/logic/subscription_provider.dart';
import 'package:ofgconnects/logic/auth_provider.dart';
import 'package:ofgconnects/presentation/widgets/video_card.dart';
import 'package:ofgconnects/logic/video_provider.dart';
import 'package:ofgconnects/models/video.dart';

class UserProfilePage extends ConsumerStatefulWidget {
  final String userId;
  final String? initialName; 

  const UserProfilePage({super.key, required this.userId, this.initialName});

  @override
  ConsumerState<UserProfilePage> createState() => _UserProfilePageState();
}

class _UserProfilePageState extends ConsumerState<UserProfilePage> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(otherUserLongVideosProvider(widget.userId).notifier).fetchFirstBatch();
      ref.read(otherUserSongsProvider(widget.userId).notifier).fetchFirstBatch();
      ref.read(otherUserShortsProvider(widget.userId).notifier).fetchFirstBatch();
    });
  }

  @override
  void dispose() { 
    _tabController.dispose(); 
    super.dispose(); 
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(authProvider).user;
    final isMe = currentUser?.$id == widget.userId;

    final videosState = ref.watch(otherUserLongVideosProvider(widget.userId));
    String displayName = widget.initialName ?? 'User';
    
    if (isMe && currentUser != null) {
      displayName = currentUser.name;
    } else if (videosState.items.isNotEmpty) {
      displayName = videosState.items.first.creatorName;
    }

    final statsAsync = ref.watch(otherUserStatsProvider(widget.userId));
    final isFollowingAsync = ref.watch(isFollowingProvider(widget.userId));

    return Scaffold(
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            SliverAppBar(
              expandedHeight: 380.0,
              pinned: true,
              leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.pop()),
              title: innerBoxIsScrolled ? Text(displayName) : null,
              flexibleSpace: FlexibleSpaceBar(
                background: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter, 
                      end: Alignment.bottomCenter, 
                      colors: [Colors.blueAccent.withOpacity(0.2), Theme.of(context).scaffoldBackgroundColor]
                    ),
                  ),
                  child: SafeArea(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(height: 10),
                        CircleAvatar(
                          radius: 45, 
                          backgroundColor: Colors.grey[800], 
                          backgroundImage: (isMe && currentUser?.prefs.data['avatar'] != null) 
                              ? NetworkImage(currentUser!.prefs.data['avatar']) 
                              : null,
                          child: (isMe && currentUser?.prefs.data['avatar'] != null)
                              ? null
                              : Text(
                                  displayName.isNotEmpty ? displayName[0].toUpperCase() : 'U', 
                                  style: const TextStyle(fontSize: 36, color: Colors.white, fontWeight: FontWeight.bold)
                                ),
                        ),
                        const SizedBox(height: 12),
                        Text(displayName, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
                        const SizedBox(height: 16),
                        
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            statsAsync.when(
                              data: (stats) => Row(children: [
                                _buildStat('${stats['followers']}', 'Followers'), 
                                const SizedBox(width: 24), 
                                _buildStat('${stats['following']}', 'Following')
                              ]),
                              loading: () => const SizedBox(width: 100, height: 20, child: Center(child: LinearProgressIndicator())),
                              error: (_,__) => const SizedBox.shrink(),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24), 
                        
                        if (isMe)
                          SizedBox(
                            height: 36,
                            child: OutlinedButton(
                              onPressed: () => context.push('/edit-profile'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.white,
                                side: BorderSide(color: Colors.white.withOpacity(0.3)),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                              ),
                              child: const Text("Edit Profile"),
                            ),
                          )
                        else
                          isFollowingAsync.when(
                            data: (isFollowing) => SizedBox(
                              height: 40, 
                              child: ElevatedButton(
                                onPressed: () async {
                                  final notifier = ref.read(subscriptionNotifierProvider.notifier);
                                  if (isFollowing) {
                                    notifier.unfollowUser(widget.userId);
                                  } else {
                                    notifier.followUser(
                                      creatorId: widget.userId,
                                      creatorName: displayName,
                                    );
                                  }
                                  ref.invalidate(otherUserStatsProvider(widget.userId));
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: isFollowing ? Colors.grey[800] : Colors.blueAccent, 
                                  foregroundColor: Colors.white, 
                                  padding: const EdgeInsets.symmetric(horizontal: 32), 
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))
                                ),
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
              bottom: TabBar(
                controller: _tabController,
                indicatorColor: Colors.blueAccent,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.grey,
                tabs: const [
                  Tab(text: 'Videos'),
                  Tab(text: 'Songs'),
                  Tab(text: 'Shorts'),
                ],
              ),
            ),
          ];
        },
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildVideoList(
              ref, 
              otherUserLongVideosProvider(widget.userId), 
              isMe,
              isMe ? "You haven't uploaded any videos." : "No videos yet."
            ),
            _buildVideoList(
              ref, 
              otherUserSongsProvider(widget.userId), 
              isMe,
              isMe ? "You haven't uploaded any songs." : "No songs yet."
            ),
            _buildShortsGrid(
              ref, 
              otherUserShortsProvider(widget.userId), 
              isMe,
              isMe ? "You haven't uploaded any shorts." : "No shorts yet."
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStat(String value, String label) {
    return Column(
      mainAxisSize: MainAxisSize.min, 
      children: [
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white)), 
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey))
      ]
    );
  }

  Widget _buildVideoList(WidgetRef ref, ProviderListenable<PaginationState<Video>> provider, bool isMe, String emptyMsg) {
    final state = ref.watch(provider);
    final videos = state.items;

    if (videos.isEmpty && state.isLoadingMore) return const Center(child: CircularProgressIndicator());
    if (videos.isEmpty) return Center(child: Text(emptyMsg, style: const TextStyle(color: Colors.grey)));

    return NotificationListener<ScrollNotification>(
      onNotification: (ScrollNotification scrollInfo) {
        if (!state.isLoadingMore && state.hasMore && scrollInfo.metrics.pixels >= scrollInfo.metrics.maxScrollExtent - 200) {
          ref.read(provider as dynamic).notifier.fetchMore();
        }
        return false;
      },
      child: ListView.builder(
        padding: const EdgeInsets.only(top: 0), 
        itemCount: videos.length + (state.hasMore ? 1 : 0), 
        itemBuilder: (context, index) { 
          if (index == videos.length) return const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator())); 
          
          final video = videos[index];

          // Wrap with a stack to show status badges if isMe is true
          return Stack(
            children: [
              VideoCard(video: video),
              if (isMe && video.adminStatus != 'approved')
                Positioned(
                  top: 10,
                  right: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: video.adminStatus == 'pending' ? Colors.orange : Colors.red,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      video.adminStatus.toUpperCase(),
                      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
            ],
          );
        }
      ),
    );
  }

  Widget _buildShortsGrid(WidgetRef ref, ProviderListenable<PaginationState<Video>> provider, bool isMe, String emptyMsg) {
    final state = ref.watch(provider);
    final videos = state.items;

    if (videos.isEmpty && state.isLoadingMore) return const Center(child: CircularProgressIndicator());
    if (videos.isEmpty) return Center(child: Text(emptyMsg, style: const TextStyle(color: Colors.grey)));

    return NotificationListener<ScrollNotification>(
      onNotification: (ScrollNotification scrollInfo) {
        if (!state.isLoadingMore && state.hasMore && scrollInfo.metrics.pixels >= scrollInfo.metrics.maxScrollExtent - 200) {
          ref.read(provider as dynamic).notifier.fetchMore();
        }
        return false;
      },
      child: GridView.builder(
        padding: const EdgeInsets.all(2),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3, 
          childAspectRatio: 9 / 16,
          crossAxisSpacing: 2,
          mainAxisSpacing: 2,
        ),
        itemCount: videos.length,
        itemBuilder: (context, index) {
          final video = videos[index];
          return GestureDetector(
            onTap: () => context.push('/shorts?id=${video.id}'), 
            child: Stack(
              fit: StackFit.expand,
              children: [
                Container(
                  color: Colors.grey[900],
                  child: video.thumbnailUrl.isNotEmpty 
                    ? CachedNetworkImage(imageUrl: video.thumbnailUrl, fit: BoxFit.cover)
                    : const Icon(Icons.play_circle_outline, color: Colors.white54),
                ),
                if (isMe && video.adminStatus != 'approved')
                  Container(
                    color: Colors.black45,
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        color: video.adminStatus == 'pending' ? Colors.orange : Colors.red,
                        child: Text(
                          video.adminStatus.toUpperCase(),
                          style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}