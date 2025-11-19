// lib/presentation/pages/my_space_page.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart'; // Import Cropper
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
  final ImagePicker _picker = ImagePicker();
  bool _isUploadingImage = false; 

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

  // --- 1. IMAGE PICKER & CROPPER LOGIC (FIXED UI) ---
  Future<void> _pickAndCropImage(StateSetter updateSheetState) async {
    final user = ref.read(authProvider).user;
    if (user == null) return;

    try {
      // A. Pick Image
      final XFile? pickedFile = await _picker.pickImage(source: ImageSource.gallery);
      if (pickedFile == null) return;

      // B. Crop Image
      final CroppedFile? croppedFile = await ImageCropper().cropImage(
        sourcePath: pickedFile.path,
        // Enforce Square Crop for Avatars
        aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
        // --- UI SETTINGS (REARRANGED & STYLED) ---
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Crop Image', 
            
            // --- THIS FIXES THE OVERLAP ---
            statusBarColor: Colors.black, // Creates a black bar for time/battery
            toolbarColor: Colors.blueAccent, // The actual toolbar starts BELOW the status bar
            // -----------------------------
            
            toolbarWidgetColor: Colors.white, // White Checkmark and X buttons
            backgroundColor: Colors.black, // Background of the crop area
            activeControlsWidgetColor: Colors.blueAccent,
            initAspectRatio: CropAspectRatioPreset.square,
            lockAspectRatio: true,
            hideBottomControls: false, 
          ),
          IOSUiSettings(
            title: 'Crop Image',
            aspectRatioLockEnabled: true,
            resetAspectRatioEnabled: false,
            doneButtonTitle: 'Save', 
            cancelButtonTitle: 'Cancel',
          ),
        ],
      );

      if (croppedFile == null) return; // User cancelled

      // C. Upload
      updateSheetState(() => _isUploadingImage = true); 
      setState(() => _isUploadingImage = true); 

      await ref.read(authProvider.notifier).uploadProfileImage(File(croppedFile.path));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile picture updated!'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        updateSheetState(() => _isUploadingImage = false);
        setState(() => _isUploadingImage = false);
      }
    }
  }

  // --- 2. FULL SCREEN VIEWER ---
  void _openFullScreenImage(String imageUrl) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          body: Center(
            child: InteractiveViewer(
              panEnabled: true,
              minScale: 0.5,
              maxScale: 4,
              child: Image.network(imageUrl),
            ),
          ),
        ),
      ),
    );
  }

  // --- 3. EDIT PROFILE SHEET ---
  void _showEditProfileSheet() {
    final user = ref.read(authProvider).user;
    final nameController = TextEditingController(text: user?.name ?? 'Guest');
    final bioController = TextEditingController(text: user?.prefs.data['bio'] ?? '');
    final formKey = GlobalKey<FormState>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.grey[900],
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) {
          return Consumer(
            builder: (context, ref, child) {
              final updatedUser = ref.watch(authProvider).user;
              final avatarUrl = updatedUser?.prefs.data['avatar'] as String?;

              return Padding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewInsets.bottom + 20,
                  left: 20,
                  right: 20,
                  top: 24,
                ),
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Edit Profile', style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Colors.white)),
                      const SizedBox(height: 24),

                      // --- EDIT AVATAR SECTION ---
                      GestureDetector(
                        onTap: () => _pickAndCropImage(setSheetState),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            CircleAvatar(
                              radius: 45,
                              backgroundColor: Colors.blueAccent,
                              child: CircleAvatar(
                                radius: 42,
                                backgroundColor: Colors.grey[800],
                                child: (avatarUrl != null && avatarUrl.isNotEmpty)
                                    ? ClipOval(
                                        child: Image.network(
                                          avatarUrl,
                                          width: 84,
                                          height: 84,
                                          fit: BoxFit.cover,
                                        ),
                                      )
                                    : Text(
                                        updatedUser?.name.isNotEmpty == true ? updatedUser!.name[0].toUpperCase() : 'G',
                                        style: const TextStyle(fontSize: 32, color: Colors.white),
                                      ),
                              ),
                            ),
                            // Camera Badge
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: const BoxDecoration(
                                  color: Colors.blueAccent,
                                  shape: BoxShape.circle,
                                ),
                                child: _isUploadingImage 
                                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                  : const Icon(Icons.camera_alt, size: 16, color: Colors.white),
                              ),
                            ),
                          ],
                        ),
                      ),
                      TextButton(
                         onPressed: () => _pickAndCropImage(setSheetState),
                         child: const Text("Change Photo"),
                      ),
                      // ---------------------------

                      const SizedBox(height: 16),
                      TextFormField(
                        controller: nameController,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          labelText: 'Full Name',
                          labelStyle: TextStyle(color: Colors.grey),
                          border: OutlineInputBorder(),
                          enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.grey)),
                        ),
                        validator: (value) => value!.isEmpty ? 'Name cannot be empty' : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: bioController,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          labelText: 'Your Bio',
                          labelStyle: TextStyle(color: Colors.grey),
                          border: OutlineInputBorder(),
                          enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.grey)),
                        ),
                        maxLines: 3,
                        maxLength: 150,
                      ),
                      const SizedBox(height: 24),
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
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
                          child: const Text('Save Changes', style: TextStyle(color: Colors.white)),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }
          );
        },
      ),
    );
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
              expandedHeight: 280.0, 
              pinned: true,
              backgroundColor: Theme.of(context).scaffoldBackgroundColor,
              title: innerBoxIsScrolled ? Text(user?.name ?? 'My Space') : null,
              centerTitle: true,
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
                      const SizedBox(height: 60),
                      
                      // --- MAIN PROFILE PICTURE SECTION ---
                      GestureDetector(
                        onTap: () {
                          if (avatarUrl != null && avatarUrl.isNotEmpty) {
                            _openFullScreenImage(avatarUrl);
                          }
                        },
                        child: Hero(
                          tag: 'profile_avatar',
                          child: CircleAvatar(
                            radius: 50,
                            backgroundColor: Colors.blueAccent,
                            child: CircleAvatar(
                              radius: 47,
                              backgroundColor: Colors.grey[900],
                              child: (avatarUrl != null && avatarUrl.isNotEmpty)
                                  ? ClipOval(
                                      child: Image.network(
                                        avatarUrl,
                                        width: 94,
                                        height: 94,
                                        fit: BoxFit.cover,
                                        loadingBuilder: (context, child, loadingProgress) {
                                          if (loadingProgress == null) return child;
                                          return const Center(child: CircularProgressIndicator(strokeWidth: 2));
                                        },
                                        errorBuilder: (context, error, stackTrace) {
                                          return Text(
                                            user?.name.isNotEmpty == true ? user!.name[0].toUpperCase() : 'G',
                                            style: const TextStyle(fontSize: 36, color: Colors.white),
                                          );
                                        },
                                      ),
                                    )
                                  : Text(
                                      user?.name.isNotEmpty == true ? user!.name[0].toUpperCase() : 'G',
                                      style: const TextStyle(fontSize: 36, color: Colors.white),
                                    ),
                            ),
                          ),
                        ),
                      ),
                      // ---------------------

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