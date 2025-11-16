import 'package:appwrite/appwrite.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ofgconnects_mobile/api/appwrite_client.dart';
import 'package:ofgconnects_mobile/logic/auth_provider.dart';
// --- ADD THIS IMPORT ---
import 'package:ofgconnects_mobile/logic/interaction_provider.dart';
// ---
import 'package:ofgconnects_mobile/logic/storage_provider.dart';
import 'package:ofgconnects_mobile/logic/video_provider.dart';
import 'package:ofgconnects_mobile/models/video.dart';
import 'package:ofgconnects_mobile/presentation/widgets/suggested_video_card.dart';
import 'package:video_player/video_player.dart';

import 'package:ofgconnects_mobile/logic/subscription_provider.dart'; 

class WatchPage extends ConsumerStatefulWidget {
  final String videoId; 

  const WatchPage({super.key, required this.videoId});

  @override
  ConsumerState<WatchPage> createState() => _WatchPageState();
}

class _WatchPageState extends ConsumerState<WatchPage> {
  VideoPlayerController? _controller;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initializePlayer();
    _recordHistory(); 
  }

  @override
  void didUpdateWidget(WatchPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.videoId != widget.videoId) {
      _disposePlayer(); 
      setState(() {
        _isLoading = true; 
        _errorMessage = null;
      });
      _initializePlayer(); 
      _recordHistory();    
    }
  }

  Future<void> _recordHistory() async {
    final user = ref.read(authProvider).user;
    if (user == null) return;

    // --- GRAB THE VIDEO DETAILS TO LOG VIEW COUNT ---
    final video = await ref.read(videoDetailsProvider(widget.videoId).future);
    if (video == null) return;

    try {
      // --- Use the Interaction Provider to handle view logging ---
      // It handles the logic for checking history and incrementing the count
      await ref.read(interactionProvider).logVideoView(widget.videoId, video.viewCount);
    
    } catch (e) {
      print('Error recording history: $e');
    }
  }

  Future<void> _initializePlayer() async {
    try {
      final video = await ref.read(videoDetailsProvider(widget.videoId).future);
      
      if (video == null) {
        if (mounted) setState(() => _errorMessage = "Video not found");
        return;
      }
      
      // FIX: Use 'video.videoId' which holds the URL
      final streamUrl = await ref.read(videoStreamUrlProvider(video.videoId).future);

      _controller = VideoPlayerController.networkUrl(Uri.parse(streamUrl));
      await _controller!.initialize();
      
      _controller!.play();

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      print("Error initializing player: $e");
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = "Error loading video: $e";
        });
      }
    }
  }

  void _disposePlayer() {
    _controller?.dispose();
    _controller = null;
  }

  @override
  void dispose() {
    _disposePlayer();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final videoAsync = ref.watch(videoDetailsProvider(widget.videoId));

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // --- VIDEO PLAYER AREA ---
            AspectRatio(
              aspectRatio: 16 / 9,
              child: Container(
                color: Colors.black,
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _errorMessage != null
                        ? Center(child: Text(_errorMessage!, style: const TextStyle(color: Colors.white)))
                        : Stack(
                            alignment: Alignment.bottomCenter,
                            children: [
                              VideoPlayer(_controller!),
                              GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _controller!.value.isPlaying
                                        ? _controller!.pause()
                                        : _controller!.play();
                                  });
                                },
                                child: Center(
                                  child: Icon(
                                    _controller!.value.isPlaying
                                        ? Icons.pause_circle_outline
                                        : Icons.play_circle_outline,
                                    size: 64,
                                    color: Colors.white.withOpacity(0.7),
                                  ),
                                ),
                              ),
                              VideoProgressIndicator(_controller!, allowScrubbing: true),
                            ],
                          ),
              ),
            ),

            // --- VIDEO DETAILS & SUGGESTIONS ---
            Expanded(
              child: videoAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, stack) => Center(child: Text('Error: $err', style: const TextStyle(color: Colors.white))),
                data: (video) {
                  if (video == null) return const Center(child: Text('Video not found', style: TextStyle(color: Colors.white)));
                  return ListView(
                    padding: const EdgeInsets.all(12),
                    children: [
                      // Title
                      Text(
                        video.title,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      const SizedBox(height: 8),

                      // --- VIEW COUNT AND LIKE COUNT ---
                      Text(
                        // Use the viewCount from the video model
                        '${video.viewCount} views • ${video.likeCount} likes',
                        style: const TextStyle(color: Colors.grey, fontSize: 14),
                      ),
                      const SizedBox(height: 16),

                      // Creator Info
                      _buildCreatorInfo(context, video),
                      
                      // --- ACTION BUTTONS (LIKE, SAVE) ---
                      _buildActionButtons(context, video),
                      
                      const SizedBox(height: 16),
                      const Divider(color: Colors.grey),
                      const Text("Suggested Videos", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                      const SizedBox(height: 8),
                      
                      // Suggested Videos List
                      Consumer(
                        builder: (context, ref, child) {
                          final suggestedAsync = ref.watch(suggestedVideosProvider(widget.videoId));
                          return suggestedAsync.when(
                            loading: () => const SizedBox(height: 100, child: Center(child: CircularProgressIndicator())),
                            error: (e, s) => const Text("Failed to load suggestions", style: TextStyle(color: Colors.white)),
                            data: (videos) {
                              return Column(
                                children: videos.map<Widget>((v) => SuggestedVideoCard(
                                  video: v,
                                )).toList(),
                              );
                            },
                          );
                        },
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  // --- WIDGET FOR CREATOR INFO & FOLLOW BUTTON ---
  Widget _buildCreatorInfo(BuildContext context, Video video) {
    // ... (This widget remains unchanged)
    final isFollowingAsync = ref.watch(isFollowingProvider(video.creatorId));

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            CircleAvatar(
              child: Text(video.creatorName.isNotEmpty ? video.creatorName[0] : 'U'),
            ),
            const SizedBox(width: 12.0),
            Text(
              video.creatorName,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.white),
            ),
          ],
        ),

        isFollowingAsync.when(
          data: (isFollowing) {
            return ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: isFollowing ? Colors.grey[800] : Colors.red,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                final notifier = ref.read(subscriptionNotifierProvider.notifier);
                if (isFollowing) {
                  notifier.unfollowUser(video.creatorId);
                } else {
                  notifier.followUser(video);
                }
              },
              child: Text(isFollowing ? 'Following' : 'Follow'),
            );
          },
          loading: () => const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)),
          error: (e, s) => const Icon(Icons.error, color: Colors.red),
        ),
      ],
    );
  }

  // ---
  // --- NEW WIDGET FOR ACTION BUTTONS ---
  // ---
  Widget _buildActionButtons(BuildContext context, Video video) {
    // Watch the new provider to see if the video is liked
    final isLikedAsync = ref.watch(isLikedProvider(video.id));
    // Watch the existing provider to see if the video is saved
    final isSavedAsync = ref.watch(interactionProvider).isVideoSaved(video.id);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          // --- LIKE BUTTON ---
          isLikedAsync.when(
            data: (isLiked) {
              return TextButton.icon(
                style: TextButton.styleFrom(foregroundColor: Colors.white),
                onPressed: () {
                  // Call the new toggleLike function
                  ref.read(interactionProvider).toggleLike(video.id, video.likeCount);
                },
                icon: Icon(
                  isLiked ? Icons.thumb_up : Icons.thumb_up_outlined,
                  color: isLiked ? Colors.blue : Colors.white,
                ),
                label: const Text('Like'),
              );
            },
            loading: () => const Padding(padding: EdgeInsets.all(8.0), child: CircularProgressIndicator(strokeWidth: 2)),
            error: (e, s) => const Icon(Icons.error, color: Colors.red),
          ),
          
          const SizedBox(width: 8),

          // --- SAVE (WATCH LATER) BUTTON ---
          FutureBuilder<bool>(
            future: isSavedAsync,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Padding(padding: EdgeInsets.all(8.0), child: CircularProgressIndicator(strokeWidth: 2));
              }
              final isSaved = snapshot.data ?? false;
              return TextButton.icon(
                style: TextButton.styleFrom(foregroundColor: Colors.white),
                onPressed: () async {
                  // Call the existing toggleWatchLater function
                  await ref.read(interactionProvider).toggleWatchLater(video.id);
                  // Manually trigger a rebuild to update the icon
                  setState(() {}); 
                },
                icon: Icon(
                  isSaved ? Icons.bookmark_added : Icons.bookmark_add_outlined,
                  color: isSaved ? Colors.blue : Colors.white,
                ),
                label: const Text('Save'),
              );
            },
          ),
          
          // You can add more buttons here (e.g., Share, Download)
        ],
      ),
    );
  }
}

// Helper provider for fetching details of a SINGLE video
final videoDetailsProvider = FutureProvider.family<Video?, String>((ref, videoId) async {
  // ... (This provider remains unchanged)
  final databases = ref.watch(databasesProvider);
  try {
    final doc = await databases.getDocument(
      databaseId: AppwriteClient.databaseId,
      collectionId: AppwriteClient.collectionIdVideos,
      documentId: videoId,
    );
    return Video.fromAppwrite(doc);
  } catch (e) {
    return null;
  }
});

// Helper provider for fetching suggested videos (excludes current one)
final suggestedVideosProvider = FutureProvider.family<List<Video>, String>((ref, currentVideoId) async {
  // ... (This provider remains unchanged)
  final databases = ref.watch(databasesProvider);
  final response = await databases.listDocuments(
    databaseId: AppwriteClient.databaseId,
    collectionId: AppwriteClient.collectionIdVideos,
    queries: [
      Query.limit(10),
      Query.orderDesc('\$createdAt'),
    ],
  );
  
  final allVideos = response.documents.map((d) => Video.fromAppwrite(d)).toList();
  return allVideos.where((v) => v.id != currentVideoId).toList();
});