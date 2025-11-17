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

  // --- Show the Edit Profile Bottom Sheet ---
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
                maxLength: 150, // Optional: add a length limit
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
                        Navigator.pop(context); // Close sheet
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Profile updated!'), backgroundColor: Colors.green),
                        );
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                        );
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
      appBar: AppBar(
        // The title now updates automatically when the user name changes
        title: Text(ref.watch(authProvider.select((s) => s.user?.name ?? 'My Space'))),
        elevation: 0,
      ),
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    // --- 1. User Avatar ---
                    CircleAvatar(
                      radius: 40,
                      child: Text(
                        user?.name.isNotEmpty == true ? user!.name[0].toUpperCase() : 'G',
                        style: const TextStyle(fontSize: 32),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      user?.name ?? 'Guest User',
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                    ),
                    if (!isGuest)
                      Text(
                        user?.email ?? '',
                        style: const TextStyle(fontSize: 15, color: Colors.grey),
                      ),
                    
                    if (bio.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Text(
                          bio,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 15, fontStyle: FontStyle.italic),
                        ),
                      ),
                    const SizedBox(height: 20),
                    
                    // --- 2. User Stats ---
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildStatColumn('Videos', ref.watch(userVideosProvider).asData?.value.length ?? 0),
                        _buildStatColumn('Followers', ref.watch(followerCountProvider).asData?.value ?? 0),
                        _buildStatColumn('Following', ref.watch(followingCountProvider).asData?.value ?? 0),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // --- 3. Edit Profile Button ---
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: _showEditProfileSheet,
                        child: const Text('Edit Profile'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            // --- 4. Tab Bar ---
            SliverPersistentHeader(
              delegate: _SliverAppBarDelegate(
                TabBar(
                  controller: _tabController,
                  tabs: const [
                    Tab(text: 'My Videos'),
                    Tab(text: 'My Library'),
                  ],
                ),
              ),
              pinned: true,
            ),
          ];
        },
        body: TabBarView(
          controller: _tabController,
          children: [
            // --- Tab 1: My Videos ---
            _buildMyVideosTab(ref),
            
            // --- Tab 2: My Library ---
            _buildMyLibraryTab(),
          ],
        ),
      ),
    );
  }

  // --- Stat Column Helper ---
  Widget _buildStatColumn(String label, int count) {
    return Column(
      children: [
        Text(
          count.toString(),
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 14, color: Colors.grey),
        ),
      ],
    );
  }

  // --- My Videos Tab ---
  Widget _buildMyVideosTab(WidgetRef ref) {
    final userVideosAsync = ref.watch(userVideosProvider);
    
    return userVideosAsync.when(
      data: (videos) {
        if (videos.isEmpty) {
          return const Center(child: Text('You have not uploaded any videos yet.'));
        }
        return ListView.builder(
          padding: const EdgeInsets.only(top: 8), // Add padding for the list
          itemCount: videos.length,
          itemBuilder: (context, index) {
            return VideoCard(video: videos[index]);
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text('Error: $err')),
    );
  }

  // --- My Library Tab ---
  Widget _buildMyLibraryTab() {
    return ListView(
      padding: const EdgeInsets.only(top: 8), // Add padding for the list
      children: [
        _buildMenuTile(context, 'History', Icons.history, '/history'),
        _buildMenuTile(context, 'Liked Videos', Icons.thumb_up_outlined, '/liked'),
        _buildMenuTile(context, 'Watch Later', Icons.watch_later_outlined, '/watchlater'),
      ],
    );
  }

  // --- Menu Tile Helper ---
  Widget _buildMenuTile(BuildContext context, String title, IconData icon, String route) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      trailing: const Icon(Icons.chevron_right, size: 20),
      onTap: () => context.push(route),
    );
  }
}

// --- Helper class for the sticky TabBar ---
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
      color: Theme.of(context).scaffoldBackgroundColor, // Match scaffold bg
      child: _tabBar,
    );
  }

  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) {
    return false;
  }
}