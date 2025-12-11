import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ofgconnects_mobile/logic/auth_provider.dart';
import 'package:ofgconnects_mobile/logic/subscription_provider.dart';
import 'package:ofgconnects_mobile/logic/video_provider.dart';
import 'package:ofgconnects_mobile/presentation/widgets/video_card.dart';
import 'package:cached_network_image/cached_network_image.dart';

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
    _tabController = TabController(length: 3, vsync: this); 
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
              expandedHeight: 450.0, // Generous height
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
                  // --- SAFE AREA WRAPPER ---
                  child: SafeArea(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(height: 20), // Top spacing inside Safe Area
                        
                        // Avatar
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
                        
                        // Name
                        Text(user?.name ?? 'Guest', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
                        
                        // Bio
                        if (bio.isNotEmpty) 
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 8), 
                            child: Text(bio, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70, fontSize: 14), maxLines: 2, overflow: TextOverflow.ellipsis)
                          ),
                        
                        const SizedBox(height: 16),
                        
                        // Stats
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _buildStatItem('Followers', '${ref.watch(followerCountProvider).asData?.value ?? 0}'),
                            const SizedBox(width: 24),
                            _buildStatItem('Following', '${ref.watch(followingCountProvider).asData?.value ?? 0}'),
                          ],
                        ),
                        
                        const SizedBox(height: 24),

                        // Edit Profile Button
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
            _buildMyVideosTab(ref),
            _buildMyShortsTab(ref), 
            _buildMyLibraryTab(),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(mainAxisSize: MainAxisSize.min, children: [Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white)), Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey))]);
  }

  // --- 1. LONG VIDEOS TAB ---
  Widget _buildMyVideosTab(WidgetRef ref) {
    final state = ref.watch(paginatedUserLongVideosProvider);
    final videos = state.items;

    if (videos.isEmpty && state.isLoadingMore) {
      Future.microtask(() => ref.read(paginatedUserLongVideosProvider.notifier).fetchFirstBatch());
      return const Center(child: CircularProgressIndicator());
    }
    if (videos.isEmpty) return const Center(child: Padding(padding: EdgeInsets.only(bottom: 100), child: Text('No videos yet.', style: TextStyle(color: Colors.white54))));

    return NotificationListener<ScrollNotification>(
      onNotification: (ScrollNotification scrollInfo) {
        if (!state.isLoadingMore && state.hasMore && scrollInfo.metrics.pixels >= scrollInfo.metrics.maxScrollExtent - 200) {
          ref.read(paginatedUserLongVideosProvider.notifier).fetchMore();
        }
        return false;
      },
      child: ListView.builder(
        padding: const EdgeInsets.only(top: 8, bottom: 100),
        itemCount: videos.length + (state.hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == videos.length) return const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator()));
          return VideoCard(video: videos[index]);
        },
      ),
    );
  }

  // --- 2. SHORTS TAB (Grid View) ---
  Widget _buildMyShortsTab(WidgetRef ref) {
    final state = ref.watch(paginatedUserShortsProvider);
    final videos = state.items;

    if (videos.isEmpty && state.isLoadingMore) {
      Future.microtask(() => ref.read(paginatedUserShortsProvider.notifier).fetchFirstBatch());
      return const Center(child: CircularProgressIndicator());
    }
    if (videos.isEmpty) return const Center(child: Padding(padding: EdgeInsets.only(bottom: 100), child: Text('No shorts yet.', style: TextStyle(color: Colors.white54))));

    return NotificationListener<ScrollNotification>(
      onNotification: (ScrollNotification scrollInfo) {
        if (!state.isLoadingMore && state.hasMore && scrollInfo.metrics.pixels >= scrollInfo.metrics.maxScrollExtent - 200) {
          ref.read(paginatedUserShortsProvider.notifier).fetchMore();
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
            child: Container(
              color: Colors.grey[900],
              child: video.thumbnailUrl.isNotEmpty 
                ? CachedNetworkImage(imageUrl: video.thumbnailUrl, fit: BoxFit.cover)
                : const Icon(Icons.play_circle_outline, color: Colors.white54),
            ),
          );
        },
      ),
    );
  }

  // --- 3. LIBRARY TAB ---
  Widget _buildMyLibraryTab() {
    return ListView(
      padding: const EdgeInsets.only(top: 8, bottom: 100),
      children: [
        _buildMenuTile(context, 'History', Icons.history, '/history'),
        _buildMenuTile(context, 'Liked Videos', Icons.thumb_up_outlined, '/liked'),
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