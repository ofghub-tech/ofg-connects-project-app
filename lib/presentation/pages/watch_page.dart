import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:appwrite/appwrite.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:intl/intl.dart';

// Import your project files
import 'package:ofgconnects_mobile/api/appwrite_client.dart';
import 'package:ofgconnects_mobile/logic/auth_provider.dart';
import 'package:ofgconnects_mobile/logic/video_provider.dart'; 
import 'package:ofgconnects_mobile/models/video.dart';

class WatchPage extends ConsumerStatefulWidget {
  final String videoId;

  const WatchPage({super.key, required this.videoId});

  @override
  ConsumerState<WatchPage> createState() => _WatchPageState();
}

class _WatchPageState extends ConsumerState<WatchPage> {
  // Video Player State
  VideoPlayerController? _videoPlayerController;
  ChewieController? _chewieController;
  bool _isPlayerInitialized = false;

  // Logic State
  bool _isSaved = false;
  String? _savedDocId;
  bool _isTogglingSave = false;
  
  // Local view count to update UI instantly without refetching
  int? _localViewCount; 

  @override
  void initState() {
    super.initState();
    // 1. Check if video is saved (Watch Later)
    _checkSavedStatus();
    // 2. Log View
    _logView();
  }

  @override
  void dispose() {
    _videoPlayerController?.dispose();
    _chewieController?.dispose();
    super.dispose();
  }

  // --- LOGIC: CHECK SAVED STATUS ---
  Future<void> _checkSavedStatus() async {
    final user = ref.read(authProvider).user;
    if (user == null) return;

    try {
      final databases = ref.read(databasesProvider);
      final response = await databases.listDocuments(
        databaseId: AppwriteClient.databaseId,
        collectionId: AppwriteClient.collectionIdWatchLater,
        queries: [
          Query.equal('userId', user.$id),
          Query.equal('videoId', widget.videoId),
          Query.limit(1),
        ],
      );

      if (mounted) {
        if (response.total > 0) {
          setState(() {
            _isSaved = true;
            _savedDocId = response.documents[0].$id;
          });
        } else {
          setState(() {
            _isSaved = false;
            _savedDocId = null;
          });
        }
      }
    } catch (e) {
      print("Failed to check watch later: $e");
    }
  }

  // --- LOGIC: TOGGLE SAVE ---
  Future<void> _toggleSave() async {
    final user = ref.read(authProvider).user;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please log in to save videos")));
      return;
    }

    if (_isTogglingSave) return;
    setState(() => _isTogglingSave = true);

    try {
      final databases = ref.read(databasesProvider);

      if (_isSaved && _savedDocId != null) {
        // Remove
        await databases.deleteDocument(
          databaseId: AppwriteClient.databaseId,
          collectionId: AppwriteClient.collectionIdWatchLater,
          documentId: _savedDocId!,
        );
        setState(() {
          _isSaved = false;
          _savedDocId = null;
        });
      } else {
        // Add
        final uniqueId = ID.unique();
        final response = await databases.createDocument(
          databaseId: AppwriteClient.databaseId,
          collectionId: AppwriteClient.collectionIdWatchLater,
          documentId: uniqueId,
          data: {
            'userId': user.$id,
            'videoId': widget.videoId,
          },
          permissions: [
            Permission.read(Role.user(user.$id)),
            Permission.write(Role.user(user.$id)),
          ],
        );
        setState(() {
          _isSaved = true;
          _savedDocId = response.$id;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Failed to update: $e")));
    } finally {
      setState(() => _isTogglingSave = false);
    }
  }

  // --- LOGIC: LOG VIEW COUNT ---
  Future<void> _logView() async {
    final user = ref.read(authProvider).user;
    // Note: You might want to allow anonymous view logging, but mirroring React logic:
    if (user == null) return; 

    try {
      final databases = ref.read(databasesProvider);
      
      // 1. Check History
      final historyCheck = await databases.listDocuments(
        databaseId: AppwriteClient.databaseId,
        collectionId: AppwriteClient.collectionIdHistory,
        queries: [
          Query.equal('userId', user.$id),
          Query.equal('videoId', widget.videoId),
          Query.limit(1),
        ],
      );

      // If already viewed, stop
      if (historyCheck.total > 0) return;

      // 2. Add to History
      await databases.createDocument(
        databaseId: AppwriteClient.databaseId,
        collectionId: AppwriteClient.collectionIdHistory,
        documentId: ID.unique(),
        data: {'userId': user.$id, 'videoId': widget.videoId},
        permissions: [Permission.read(Role.user(user.$id)), Permission.write(Role.user(user.$id))],
      );

      // 3. Update Video View Count
      // We need current count first. We can get it from the provider state if loaded,
      // or fetch fresh. Let's fetch fresh to be safe (atomic increment isn't available via client SDK easily)
      final doc = await databases.getDocument(
        databaseId: AppwriteClient.databaseId,
        collectionId: AppwriteClient.collectionIdVideos,
        documentId: widget.videoId,
      );

      final currentCount = doc.data['view_count'] ?? 0;
      final newCount = currentCount + 1;

      await databases.updateDocument(
        databaseId: AppwriteClient.databaseId,
        collectionId: AppwriteClient.collectionIdVideos,
        documentId: widget.videoId,
        data: {'view_count': newCount},
      );

      if (mounted) {
        setState(() {
          _localViewCount = newCount;
        });
      }
    } catch (e) {
      print("View log failed: $e");
    }
  }

  // --- PLAYER INITIALIZATION ---
  Future<void> _initializePlayer(String videoUrl) async {
    if (_isPlayerInitialized) return;

    _videoPlayerController = VideoPlayerController.networkUrl(Uri.parse(videoUrl));
    await _videoPlayerController!.initialize();

    _chewieController = ChewieController(
      videoPlayerController: _videoPlayerController!,
      autoPlay: true,
      looping: false,
      aspectRatio: _videoPlayerController!.value.aspectRatio,
      materialProgressColors: ChewieProgressColors(
        playedColor: Colors.blueAccent,
        handleColor: Colors.blueAccent,
        backgroundColor: Colors.grey,
        bufferedColor: Colors.white24,
      ),
      placeholder: Container(color: Colors.black),
      errorBuilder: (context, errorMessage) {
        return Center(child: Text("Video Error: $errorMessage", style: TextStyle(color: Colors.white)));
      },
    );

    setState(() {
      _isPlayerInitialized = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    // 1. Fetch Video Details
    final videoAsync = ref.watch(videoDetailsProvider(widget.videoId));

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: SafeArea(
        child: videoAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, stack) => Center(child: Text('Error: $err', style: TextStyle(color: Colors.red))),
          data: (video) {
            
            // Initialize player once we have data
            final urlToPlay = video.videoUrl;
            if (urlToPlay.isNotEmpty) {
              _initializePlayer(urlToPlay);
            }

            // Use local incremented count if available, else DB count
            final displayViews = _localViewCount ?? video.viewCount;

            return Column(
              children: [
                // --- VIDEO PLAYER SECTION ---
                AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Container(
                    color: Colors.black,
                    child: _isPlayerInitialized && _chewieController != null
                        ? Chewie(controller: _chewieController!)
                        : const Center(child: CircularProgressIndicator(color: Colors.white24)),
                  ),
                ),

                // --- SCROLLABLE CONTENT ---
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // INFO PANEL
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Title
                              Text(
                                video.title,
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                              ),
                              const SizedBox(height: 8),
                              
                              // Views & Date
                              Row(
                                children: [
                                  Icon(Icons.visibility_outlined, size: 16, color: Colors.grey[400]),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${NumberFormat.compact().format(displayViews)} views',
                                    style: TextStyle(color: Colors.grey[400], fontSize: 13),
                                  ),
                                  // Add Date here if needed
                                ],
                              ),
                              const SizedBox(height: 16),

                              // --- CHANNEL & ACTIONS ROW ---
                              Row(
                                children: [
                                  // Avatar
                                  CircleAvatar(
                                    radius: 18,
                                    backgroundColor: Colors.blueAccent,
                                    child: Text(
                                      video.creatorName.isNotEmpty ? video.creatorName[0].toUpperCase() : "?",
                                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  // Name
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(video.creatorName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                                        // Optional: Subscriber count here
                                      ],
                                    ),
                                  ),
                                  // Follow Button (Placeholder logic)
                                  ElevatedButton(
                                    onPressed: () { /* Follow Logic */ },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.white,
                                      foregroundColor: Colors.black,
                                      padding: const EdgeInsets.symmetric(horizontal: 16),
                                      minimumSize: const Size(0, 36)
                                    ),
                                    child: const Text("Subscribe"),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 16),

                              // --- ACTION BUTTONS (Scrollable Row) ---
                              SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: Row(
                                  children: [
                                    _ActionButton(
                                      icon: Icons.thumb_up_outlined,
                                      label: "${video.likeCount}",
                                      onTap: () { /* Like Logic */ },
                                    ),
                                    const SizedBox(width: 12),
                                    _ActionButton(
                                      icon: Icons.share_outlined,
                                      label: "Share",
                                      onTap: () { /* Share Logic */ },
                                    ),
                                    const SizedBox(width: 12),
                                    _ActionButton(
                                      icon: _isSaved ? Icons.bookmark : Icons.bookmark_border,
                                      label: _isSaved ? "Saved" : "Save",
                                      activeColor: _isSaved,
                                      onTap: _isTogglingSave ? null : _toggleSave,
                                    ),
                                  ],
                                ),
                              ),

                              const SizedBox(height: 16),

                              // --- DESCRIPTION ---
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.05),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  video.description.isNotEmpty ? video.description : "No description.",
                                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const Divider(color: Colors.white10),

                        // --- SUGGESTED VIDEOS ---
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          child: Text("Up Next", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                        ),
                        
                        _SuggestedVideosList(currentVideoId: video.id),
                        
                        const SizedBox(height: 20),
                        
                        // --- COMMENTS ---
                        // You can navigate to a bottom sheet or show them here
                        Center(
                           child: TextButton(
                             onPressed: () {
                               // Open Comments Bottom Sheet
                             },
                             child: const Text("Show Comments"),
                           ),
                        ),
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

// --- SUB-WIDGET: ACTION BUTTON ---
class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool activeColor;

  const _ActionButton({required this.icon, required this.label, this.onTap, this.activeColor = false});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: activeColor ? Colors.white : Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: activeColor ? Colors.black : Colors.white),
            const SizedBox(width: 8),
            Text(label, style: TextStyle(color: activeColor ? Colors.black : Colors.white, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}

// --- SUB-WIDGET: SUGGESTED VIDEOS ---
class _SuggestedVideosList extends ConsumerWidget {
  final String currentVideoId;
  const _SuggestedVideosList({required this.currentVideoId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final suggestionsAsync = ref.watch(suggestedVideosProvider(currentVideoId));

    return suggestionsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => const SizedBox.shrink(),
      data: (videos) {
        if (videos.isEmpty) return const Padding(padding: EdgeInsets.all(16), child: Text("No related videos.", style: TextStyle(color: Colors.grey)));

        return ListView.builder(
          shrinkWrap: true, // Important inside SingleChildScrollView
          physics: const NeverScrollableScrollPhysics(),
          itemCount: videos.length,
          itemBuilder: (context, index) {
            final v = videos[index];
            return ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              onTap: () {
                // Navigate to this video (Replace or Push)
                context.push('/home/watch/${v.id}');
              },
              leading: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  v.thumbnailUrl ?? '', 
                  width: 100, 
                  height: 56, 
                  fit: BoxFit.cover,
                  errorBuilder: (c, o, s) => Container(width: 100, height: 56, color: Colors.grey),
                ),
              ),
              title: Text(v.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 14)),
              subtitle: Text(v.creatorName, style: const TextStyle(color: Colors.grey, fontSize: 12)),
              trailing: const Icon(Icons.more_vert, size: 16, color: Colors.grey),
            );
          },
        );
      },
    );
  }
}