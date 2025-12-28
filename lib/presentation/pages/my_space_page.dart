import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ofgconnects/logic/auth_provider.dart';
import 'package:ofgconnects/logic/subscription_provider.dart';
import 'package:ofgconnects/logic/profile_provider.dart'; 
import 'package:ofgconnects/presentation/widgets/video_card.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:ofgconnects/models/video.dart';
import 'package:ofgconnects/logic/video_provider.dart';

class MySpacePage extends ConsumerStatefulWidget {
  const MySpacePage({super.key});

  @override
  ConsumerState<MySpacePage> createState() => _MySpacePageState();
}

class _MySpacePageState extends ConsumerState<MySpacePage> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this); 
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = ref.read(authProvider).user;
      if (user != null) {
        ref.read(otherUserLongVideosProvider(user.$id).notifier).fetchFirstBatch();
        ref.read(otherUserSongsProvider(user.$id).notifier).fetchFirstBatch();
        ref.read(otherUserShortsProvider(user.$id).notifier).fetchFirstBatch();
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    final isGuest = user == null || user.email.isEmpty;
    final bio = user?.prefs.data['bio'] as String? ?? '';
    final avatarUrl = user?.prefs.data['avatar'] as String?;

    return Scaffold(
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            SliverAppBar(
              expandedHeight: 450.0,
              pinned: true,
              backgroundColor: Theme.of(context).scaffoldBackgroundColor,
              title: innerBoxIsScrolled ? Text(user?.name ?? 'My Space') : null,
              centerTitle: true,
              actions: [
                if (!isGuest)
                  IconButton(
                    icon: const Icon(Icons.settings_outlined),
                    onPressed: () => context.push('/settings'),
                  ),
                const SizedBox(width: 8),
              ],
              flexibleSpace: FlexibleSpaceBar(
                background: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.blueAccent.withOpacity(0.15), Theme.of(context).scaffoldBackgroundColor],
                    ),
                  ),
                  child: SafeArea(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(height: 20),
                        CircleAvatar(
                          radius: 50,
                          backgroundColor: Colors.blueAccent,
                          child: CircleAvatar(
                            radius: 47,
                            backgroundColor: Colors.grey[900],
                            backgroundImage: (avatarUrl != null) ? NetworkImage(avatarUrl) : null,
                            child: (avatarUrl == null) 
                              ? Text(user?.name.isNotEmpty == true ? user!.name[0].toUpperCase() : 'G', style: const TextStyle(fontSize: 36, color: Colors.white)) 
                              : null,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(user?.name ?? 'Guest', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
                        if (bio.isNotEmpty) 
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 8), 
                            child: Text(bio, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70, fontSize: 14), maxLines: 2, overflow: TextOverflow.ellipsis)
                          ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _buildStatItem('Followers', '${ref.watch(followerCountProvider).asData?.value ?? 0}'),
                            const SizedBox(width: 24),
                            _buildStatItem('Following', '${ref.watch(followingCountProvider).asData?.value ?? 0}'),
                          ],
                        ),
                        const SizedBox(height: 24),
                        if (!isGuest)
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
                          ),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
              ),
              bottom: TabBar(
                controller: _tabController,
                indicatorColor: Colors.blueAccent,
                indicatorWeight: 3,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.grey,
                tabs: const [
                  Tab(text: 'Videos'),
                  Tab(text: 'Songs'),
                  Tab(text: 'Shorts'),
                  Tab(text: 'Library'),
                ],
              ),
            ),
          ];
        },
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildMyContentList(ref, otherUserLongVideosProvider(user?.$id ?? ''), 'No videos yet.'),
            _buildMyContentList(ref, otherUserSongsProvider(user?.$id ?? ''), 'No songs yet.'),
            _buildMyShortsGrid(ref, otherUserShortsProvider(user?.$id ?? ''), 'No shorts yet.'), 
            _buildMyLibraryTab(),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(mainAxisSize: MainAxisSize.min, children: [Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white)), Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey))]);
  }

  Widget _buildMyContentList(WidgetRef ref, ProviderListenable<PaginationState<Video>> provider, String emptyMsg) {
    final state = ref.watch(provider);
    final videos = state.items;

    if (videos.isEmpty && state.isLoadingMore) return const Center(child: CircularProgressIndicator());
    if (videos.isEmpty) return Center(child: Text(emptyMsg, style: const TextStyle(color: Colors.white54)));

    return NotificationListener<ScrollNotification>(
      onNotification: (ScrollNotification scrollInfo) {
        if (!state.isLoadingMore && state.hasMore && scrollInfo.metrics.pixels >= scrollInfo.metrics.maxScrollExtent - 200) {
          ref.read(provider as dynamic).notifier.fetchMore();
        }
        return false;
      },
      child: ListView.builder(
        padding: const EdgeInsets.only(top: 8, bottom: 100),
        itemCount: videos.length + (state.hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == videos.length) return const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator()));
          
          final video = videos[index];
          return Stack(
            children: [
              VideoCard(video: video),
              if (video.adminStatus != 'approved')
                Positioned(
                  top: 12,
                  right: 12,
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
        },
      ),
    );
  }

  Widget _buildMyShortsGrid(WidgetRef ref, ProviderListenable<PaginationState<Video>> provider, String emptyMsg) {
    final state = ref.watch(provider);
    final videos = state.items;

    if (videos.isEmpty && state.isLoadingMore) return const Center(child: CircularProgressIndicator());
    if (videos.isEmpty) return Center(child: Text(emptyMsg, style: const TextStyle(color: Colors.white54)));

    return GridView.builder(
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
              if (video.adminStatus != 'approved')
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
    );
  }

  // --- REMOVED LIKED VIDEOS FROM HERE ---
  Widget _buildMyLibraryTab() {
    return ListView(
      padding: const EdgeInsets.only(top: 8, bottom: 100),
      children: [
        _buildMenuTile(context, 'History', Icons.history, '/history'),
        _buildMenuTile(context, 'Watch Later', Icons.watch_later_outlined, '/watchlater'),
      ],
    );
  }

  Widget _buildMenuTile(BuildContext context, String title, IconData icon, String route) {
    return ListTile(
      leading: Icon(icon, color: Colors.blueAccent),
      title: Text(title),
      trailing: const Icon(Icons.chevron_right, size: 20),
      onTap: () => context.push(route),
    );
  }
}