import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
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

  // --- FIX: Cropper UI Safe Area ---
  Future<void> _pickAndCropImage(StateSetter updateSheetState) async {
    final user = ref.read(authProvider).user;
    if (user == null) return;

    try {
      final XFile? pickedFile = await _picker.pickImage(source: ImageSource.gallery);
      if (pickedFile == null) return;

      final CroppedFile? croppedFile = await ImageCropper().cropImage(
        sourcePath: pickedFile.path,
        aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Adjust Photo',
            // --- THIS IS THE KEY FIX ---
            // By setting statusBarColor to black, we force the toolbar to render BELOW the status bar.
            statusBarColor: Colors.black, 
            toolbarColor: Colors.black,
            toolbarWidgetColor: Colors.white,
            backgroundColor: const Color(0xFF121212),
            activeControlsWidgetColor: Colors.blueAccent,
            initAspectRatio: CropAspectRatioPreset.square,
            lockAspectRatio: true,
            hideBottomControls: false, 
          ),
          IOSUiSettings(
            title: 'Adjust Photo',
            aspectRatioLockEnabled: true,
            resetAspectRatioEnabled: false,
            doneButtonTitle: 'Save', 
            cancelButtonTitle: 'Cancel',
          ),
        ],
      );

      if (croppedFile == null) return; 

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

  void _openFullScreenImage(String imageUrl) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(icon: const Icon(Icons.close, color: Colors.white), onPressed: () => Navigator.pop(context)),
          ),
          body: Center(child: InteractiveViewer(child: Image.network(imageUrl))),
        ),
      ),
    );
  }

  void _showEditProfileSheet() {
    final user = ref.read(authProvider).user;
    final nameController = TextEditingController(text: user?.name ?? 'Guest');
    final bioController = TextEditingController(text: user?.prefs.data['bio'] ?? '');
    final formKey = GlobalKey<FormState>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) {
          // Using Scaffold inside bottom sheet to handle keyboard and FAB cleanly
          return Scaffold(
            backgroundColor: Colors.transparent,
            resizeToAvoidBottomInset: true,
            body: Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
              child: Form(
                key: formKey,
                child: ListView(
                  children: [
                    Text('Edit Profile', style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Colors.white)),
                    const SizedBox(height: 24),
                    
                    // Avatar Edit
                    GestureDetector(
                      onTap: () => _pickAndCropImage(setSheetState),
                      child: Center(
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            CircleAvatar(
                              radius: 45,
                              backgroundColor: Colors.blueAccent,
                              child: CircleAvatar(
                                radius: 42,
                                backgroundColor: Colors.grey[800],
                                backgroundImage: (user?.prefs.data['avatar'] != null) ? NetworkImage(user!.prefs.data['avatar']) : null,
                                child: (user?.prefs.data['avatar'] == null) ? const Icon(Icons.person, size: 40, color: Colors.white) : null,
                              ),
                            ),
                            Positioned(
                              bottom: 0, right: 0,
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: const BoxDecoration(color: Colors.blueAccent, shape: BoxShape.circle),
                                child: _isUploadingImage 
                                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                  : const Icon(Icons.camera_alt, size: 16, color: Colors.white),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    // Input Fields
                    TextFormField(
                      controller: nameController,
                      style: const TextStyle(color: Colors.white),
                      decoration: _inputDecoration('Full Name'),
                      validator: (value) => value!.isEmpty ? 'Name cannot be empty' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: bioController,
                      style: const TextStyle(color: Colors.white),
                      decoration: _inputDecoration('Your Bio'),
                      maxLines: 3,
                      maxLength: 150,
                    ),
                    const SizedBox(height: 80), // Space for FAB
                  ],
                ),
              ),
            ),
            // FAB: Bottom Right (Tick Icon) for "Save"
            floatingActionButton: FloatingActionButton(
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  try {
                    await ref.read(authProvider.notifier).updateUserProfile(
                      name: nameController.text,
                      bio: bioController.text,
                    );
                    if (context.mounted) Navigator.pop(context);
                    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile updated!'), backgroundColor: Colors.green));
                  } catch (e) {
                    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
                  }
                }
              },
              backgroundColor: Colors.blueAccent,
              child: const Icon(Icons.check, color: Colors.white),
            ),
          );
        },
      ),
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.grey),
      filled: true,
      fillColor: Colors.white.withOpacity(0.05),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.blueAccent)),
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
              expandedHeight: 300.0, 
              pinned: true,
              backgroundColor: Theme.of(context).scaffoldBackgroundColor,
              title: innerBoxIsScrolled ? Text(user?.name ?? 'My Space') : null,
              centerTitle: true,
              actions: [
                if (!isGuest)
                  IconButton(
                    icon: const Icon(Icons.edit_outlined),
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
                      colors: [Colors.blueAccent.withOpacity(0.15), Theme.of(context).scaffoldBackgroundColor],
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 60),
                      GestureDetector(
                        onTap: () { if (avatarUrl != null) _openFullScreenImage(avatarUrl); },
                        child: Hero(
                          tag: 'profile_avatar',
                          child: CircleAvatar(
                            radius: 50,
                            backgroundColor: Colors.blueAccent,
                            child: CircleAvatar(
                              radius: 47,
                              backgroundColor: Colors.grey[900],
                              backgroundImage: (avatarUrl != null) ? NetworkImage(avatarUrl) : null,
                              child: (avatarUrl == null) ? Text(user?.name.isNotEmpty == true ? user!.name[0].toUpperCase() : 'G', style: const TextStyle(fontSize: 36, color: Colors.white)) : null,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(user?.name ?? 'Guest', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
                      if (bio.isNotEmpty) Padding(padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 4), child: Text(bio, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70, fontSize: 14), maxLines: 2, overflow: TextOverflow.ellipsis)),
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
                tabs: const [Tab(text: 'My Videos'), Tab(text: 'Library')],
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
    return Column(mainAxisSize: MainAxisSize.min, children: [Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white)), Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey))]);
  }

  Widget _buildMyVideosTab(WidgetRef ref) {
    final userVideosState = ref.watch(paginatedUserVideosProvider);
    final videos = userVideosState.items;
    if (videos.isEmpty && userVideosState.isLoadingMore) {
      Future.microtask(() => ref.read(paginatedUserVideosProvider.notifier).fetchFirstBatch());
      return const Center(child: CircularProgressIndicator());
    }
    if (videos.isEmpty) return const Center(child: Padding(padding: EdgeInsets.only(bottom: 100), child: Text('No videos yet.', style: TextStyle(color: Colors.white54))));

    return NotificationListener<ScrollNotification>(
      onNotification: (ScrollNotification scrollInfo) {
        if (!userVideosState.isLoadingMore && userVideosState.hasMore && scrollInfo.metrics.pixels >= scrollInfo.metrics.maxScrollExtent - 200) {
          ref.read(paginatedUserVideosProvider.notifier).fetchMore();
        }
        return false;
      },
      child: ListView.builder(
        padding: const EdgeInsets.only(top: 8, bottom: 100),
        itemCount: videos.length + (userVideosState.hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == videos.length) return const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator()));
          return VideoCard(video: videos[index]);
        },
      ),
    );
  }

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