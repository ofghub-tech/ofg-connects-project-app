// lib/presentation/pages/my_space_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ofgconnects_mobile/logic/auth_provider.dart';
import 'package:ofgconnects_mobile/logic/subscription_provider.dart';
import 'package:ofgconnects_mobile/logic/video_provider.dart';
import 'package:ofgconnects_mobile/presentation/widgets/video_card.dart';

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
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _showEditProfileSheet() {
    final user = ref.read(authProvider).user;
    final nameController = TextEditingController(text: user?.name ?? 'Guest');
    final bioController = TextEditingController(text: user?.prefs.data['bio'] ?? '');
    final formKey = GlobalKey<FormState>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          left: 16,
          right: 16,
          top: 24,
        ),
        child: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Edit Profile', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16),
              TextFormField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Full Name',
                  border: OutlineInputBorder(),
                ),
                validator: (value) => value!.isEmpty ? 'Name cannot be empty' : null,
              ),
              const SizedBox(height: 16),
              
              TextFormField(
                controller: bioController,
                decoration: const InputDecoration(
                  labelText: 'Your Bio',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
                maxLength: 150,
              ),
              const SizedBox(height: 16),
              
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    if (formKey.currentState!.validate()) {
                      try {
                        await ref.read(authProvider.notifier).updateUserProfile(
                          name: nameController.text,
                          bio: bioController.text,
                        );
                        if (context.mounted) Navigator.pop(context);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Profile updated!'), backgroundColor: Colors.green),
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                          );
                        }
                      }
                    }
                  },
                  child: const Text('Save Changes'),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    final isGuest = user == null || user.email.isEmpty;
    final bio = user?.prefs.data['bio'] as String? ?? '';

    return Scaffold(
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            SliverAppBar(
              // 1. Adjusted Height (Removed button space)
              expandedHeight: 260.0, 
              pinned: true,
              backgroundColor: Theme.of(context).scaffoldBackgroundColor,
              
              // 2. Title visibility (Only show when collapsed)
              title: innerBoxIsScrolled ? Text(user?.name ?? 'My Space') : null,
              centerTitle: true,

              // 3. NEW POSITION: Edit Button in Actions (Always visible)
              actions: [
                if (!isGuest)
                  IconButton(
                    icon: const Icon(Icons.edit_outlined),
                    tooltip: 'Edit Profile',
                    onPressed: _showEditProfileSheet,
                  ),
                const SizedBox(width: 8),
              ],

              flexibleSpace: FlexibleSpaceBar(
                background: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.blueAccent.withOpacity(0.15),
                        Theme.of(context).scaffoldBackgroundColor,
                      ],
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 50), // Status bar spacing
                      CircleAvatar(
                        radius: 45,
                        backgroundColor: Colors.blueAccent,
                        child: CircleAvatar(
                          radius: 42,
                          backgroundColor: Colors.grey[900],
                          child: Text(
                            user?.name.isNotEmpty == true ? user!.name[0].toUpperCase() : 'G',
                            style: const TextStyle(fontSize: 36, color: Colors.white),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        user?.name ?? 'Guest',
                        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      if (bio.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 4),
                          child: Text(
                            bio,
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.white70, fontSize: 14),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _buildStatItem('Videos', ref.watch(paginatedUserVideosProvider).items.length.toString()),
                          const SizedBox(width: 24),
                          _buildStatItem('Followers', '${ref.watch(followerCountProvider).asData?.value ?? 0}'),
                          const SizedBox(width: 24),
                          _buildStatItem('Following', '${ref.watch(followingCountProvider).asData?.value ?? 0}'),
                        ],
                      ),
                      // Removed old button from here
                    ],
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
                  Tab(text: 'My Videos'),
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
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white)),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }

  Widget _buildMyVideosTab(WidgetRef ref) {
    final userVideosState = ref.watch(paginatedUserVideosProvider);
    final videos = userVideosState.items;

    if (videos.isEmpty && userVideosState.isLoadingMore) {
      Future.microtask(() => ref.read(paginatedUserVideosProvider.notifier).fetchFirstBatch());
      return const Center(child: CircularProgressIndicator());
    }
    
    if (videos.isEmpty) {
       return const Center(child: Text('You have not uploaded any videos yet.'));
    }

    return NotificationListener<ScrollNotification>(
      onNotification: (ScrollNotification scrollInfo) {
        if (!userVideosState.isLoadingMore &&
            userVideosState.hasMore &&
            scrollInfo.metrics.pixels >= scrollInfo.metrics.maxScrollExtent - 200) {
          ref.read(paginatedUserVideosProvider.notifier).fetchMore();
        }
        return false;
      },
      child: ListView.builder(
        padding: const EdgeInsets.only(top: 8),
        itemCount: videos.length + (userVideosState.hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == videos.length) {
            return const Center(child: Padding(
              padding: EdgeInsets.all(16.0),
              child: CircularProgressIndicator(),
            ));
          }
          return VideoCard(video: videos[index]);
        },
      ),
    );
  }

  Widget _buildMyLibraryTab() {
    return ListView(
      padding: const EdgeInsets.only(top: 8),
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

class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  _SliverAppBarDelegate(this._tabBar);
  final TabBar _tabBar;

  @override
  double get minExtent => _tabBar.preferredSize.height;
  @override
  double get maxExtent => _tabBar.preferredSize.height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: _tabBar,
    );
  }

  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) {
    return false;
  }
}