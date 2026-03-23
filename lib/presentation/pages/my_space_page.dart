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
import 'package:ofgconnects/presentation/theme/ofg_ui.dart';

class MySpacePage extends ConsumerStatefulWidget {
  const MySpacePage({super.key});

  @override
  ConsumerState<MySpacePage> createState() => _MySpacePageState();
}

class _MySpacePageState extends ConsumerState<MySpacePage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = ref.read(authProvider).user;
      if (user != null) {
        ref
            .read(otherUserLongVideosProvider(user.$id).notifier)
            .fetchFirstBatch();
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
    if (user == null) {
      return Scaffold(
        backgroundColor: OfgUi.bg,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Please sign in to access My Space.',
                  style: TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: () => context.go('/'),
                  child: const Text('Go To Sign In'),
                ),
              ],
            ),
          ),
        ),
      );
    }
    final bio = user?.prefs.data['bio'] as String? ?? '';
    final avatarUrl = user?.prefs.data['avatar'] as String?;

    return Scaffold(
      backgroundColor: OfgUi.bg,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            SliverAppBar(
              expandedHeight: 460.0,
              pinned: true,
              backgroundColor: OfgUi.bg,
              title: innerBoxIsScrolled ? Text(user.name) : null,
              centerTitle: true,
              actions: [
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
                      colors: [const Color(0xFF0A1428), OfgUi.bg],
                    ),
                  ),
                  child: SafeArea(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(height: 20),
                        CircleAvatar(
                          radius: 50,
                          backgroundColor: OfgUi.accent,
                          child: CircleAvatar(
                            radius: 47,
                            backgroundColor: OfgUi.surface,
                            backgroundImage: (avatarUrl != null)
                                ? NetworkImage(avatarUrl)
                                : null,
                            child: (avatarUrl == null)
                                ? Text(
                                    user.name.isNotEmpty
                                        ? user.name[0].toUpperCase()
                                        : 'U',
                                    style: const TextStyle(
                                        fontSize: 36, color: Colors.white))
                                : null,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          user.name,
                          style: const TextStyle(
                            fontFamily: 'Cinzel',
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        if (bio.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 32, vertical: 8),
                            child: Text(
                              bio,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                  color: OfgUi.muted2, fontSize: 14),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _buildStatItem('Followers',
                                '${ref.watch(followerCountProvider).asData?.value ?? 0}'),
                            const SizedBox(width: 24),
                            _buildStatItem('Following',
                                '${ref.watch(followingCountProvider).asData?.value ?? 0}'),
                          ],
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          height: 36,
                          child: OutlinedButton(
                            onPressed: () => context.push('/edit-profile'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                              backgroundColor: OfgUi.surface2,
                              side: const BorderSide(color: OfgUi.border),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
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
                labelColor: OfgUi.accent,
                unselectedLabelColor: OfgUi.muted2,
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
            _buildMyContentList(
                ref, otherUserLongVideosProvider(user.$id), 'No videos yet.'),
            _buildMyContentList(
                ref, otherUserSongsProvider(user.$id), 'No songs yet.'),
            _buildMyShortsGrid(
                ref, otherUserShortsProvider(user.$id), 'No shorts yet.'),
            _buildMyLibraryTab(),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: const TextStyle(
            fontFamily: 'Cinzel',
            fontWeight: FontWeight.w700,
            fontSize: 18,
            color: OfgUi.accent,
          ),
        ),
        Text(label, style: const TextStyle(fontSize: 11, color: OfgUi.muted)),
      ],
    );
  }

  Widget _buildMyContentList(WidgetRef ref,
      ProviderListenable<PaginationState<Video>> provider, String emptyMsg) {
    final state = ref.watch(provider);
    final videos = state.items;

    if (videos.isEmpty && state.isLoadingMore)
      return const Center(child: CircularProgressIndicator());
    if (videos.isEmpty)
      return Center(
          child: Text(emptyMsg, style: const TextStyle(color: OfgUi.muted2)));

    return NotificationListener<ScrollNotification>(
      onNotification: (ScrollNotification scrollInfo) {
        if (!state.isLoadingMore &&
            state.hasMore &&
            scrollInfo.metrics.pixels >=
                scrollInfo.metrics.maxScrollExtent - 200) {
          ref.read(provider as dynamic).notifier.fetchMore();
        }
        return false;
      },
      child: ListView.builder(
        padding: const EdgeInsets.only(top: 8, bottom: 100),
        itemCount: videos.length + (state.hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == videos.length)
            return const Center(
                child: Padding(
                    padding: EdgeInsets.all(16),
                    child: CircularProgressIndicator()));

          final video = videos[index];
          return Stack(
            children: [
              VideoCard(video: video),
              if (video.adminStatus != 'approved')
                Positioned(
                  top: 12,
                  right: 12,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: video.adminStatus == 'pending'
                          ? Colors.orange
                          : Colors.red,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      video.adminStatus.toUpperCase(),
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildMyShortsGrid(WidgetRef ref,
      ProviderListenable<PaginationState<Video>> provider, String emptyMsg) {
    final state = ref.watch(provider);
    final videos = state.items;

    if (videos.isEmpty && state.isLoadingMore)
      return const Center(child: CircularProgressIndicator());
    if (videos.isEmpty)
      return Center(
          child: Text(emptyMsg, style: const TextStyle(color: OfgUi.muted2)));

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
                color: OfgUi.surface,
                child: video.thumbnailUrl.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: video.thumbnailUrl, fit: BoxFit.cover)
                    : const Icon(Icons.play_circle_outline,
                        color: Colors.white54),
              ),
              if (video.adminStatus != 'approved')
                Container(
                  color: Colors.black45,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      color: video.adminStatus == 'pending'
                          ? Colors.orange
                          : Colors.red,
                      child: Text(
                        video.adminStatus.toUpperCase(),
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 8,
                            fontWeight: FontWeight.bold),
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
        _buildMenuTile(
            context, 'Watch Later', Icons.watch_later_outlined, '/watchlater'),
        _buildMenuTile(context, 'Music', Icons.music_note_rounded, '/music'),
        _buildMenuTile(context, 'Kids', Icons.child_care_rounded, '/kids'),
      ],
    );
  }

  Widget _buildMenuTile(
      BuildContext context, String title, IconData icon, String route) {
    return ListTile(
      leading: Icon(icon, color: OfgUi.accent),
      title: Text(title, style: const TextStyle(color: OfgUi.text)),
      trailing: const Icon(Icons.chevron_right, size: 20, color: OfgUi.muted2),
      onTap: () => context.push(route),
    );
  }
}
