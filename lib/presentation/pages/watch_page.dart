// lib/presentation/pages/watch_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ofgconnects_mobile/logic/auth_provider.dart';
import 'package:ofgconnects_mobile/logic/interaction_provider.dart';
import 'package:ofgconnects_mobile/logic/video_provider.dart';
import 'package:ofgconnects_mobile/models/video.dart';
import 'package:ofgconnects_mobile/presentation/widgets/suggested_video_card.dart';
import 'package:ofgconnects_mobile/logic/subscription_provider.dart';
import 'package:video_player/video_player.dart';
import 'package:ofgconnects_mobile/presentation/widgets/comments_sheet.dart';

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
    _initializePage();
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
      _initializePage(); 
    }
  }

  Future<void> _initializePage() async {
    final currentVideoId = widget.videoId;

    try {
      // Use .future to get the value once without setting up a stream listener here
      final video = await ref.read(videoDetailsProvider(widget.videoId).future);
      
      if (!mounted || widget.videoId != currentVideoId) return;

      if (video == null || video.videoUrl.isEmpty) {
         setState(() => _errorMessage = "Video not found or invalid URL");
         return;
      }

      final newController = VideoPlayerController.networkUrl(
        Uri.parse(video.videoUrl),
        videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true), 
      );
      
      await newController.initialize();

      if (!mounted || widget.videoId != currentVideoId) {
        newController.dispose(); 
        return;
      }

      _controller = newController;
      _controller!.play();
      
      // Record history (and increment view count)
      _recordHistory(video);

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      print("Error initializing player: $e");
      if (mounted && widget.videoId == currentVideoId) {
        setState(() {
          _isLoading = false;
          _errorMessage = "Error loading video. Check internet connection.";
        });
      }
    }
  }

  Future<void> _recordHistory(Video video) async {
    final user = ref.read(authProvider).user;
    if (user == null) return;
    try {
      // FIXED: Calling logVideoView with just the ID. 
      // The provider will fetch the latest view count from the DB to increment it accurately.
      await ref.read(interactionProvider).logVideoView(video.id);
    } catch (e) {
      print('Error recording history: $e');
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

  void _showComments(BuildContext context, String videoId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent, 
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        builder: (context, scrollController) {
          return CommentsSheet(videoId: videoId, scrollController: scrollController);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final videoAsync = ref.watch(videoDetailsProvider(widget.videoId));

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Hero(
              tag: 'video_thumbnail_${widget.videoId}', 
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: Container(
                  color: Colors.black,
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator(color: Colors.white))
                      : _errorMessage != null
                          ? Center(child: Text(_errorMessage!, style: const TextStyle(color: Colors.white)))
                          : GestureDetector(
                              onTap: () {
                                setState(() {
                                  _controller!.value.isPlaying
                                      ? _controller!.pause()
                                      : _controller!.play();
                                });
                              },
                              child: Stack(
                                alignment: Alignment.bottomCenter,
                                children: [
                                  VideoPlayer(_controller!),
                                  if (_controller!.value.isBuffering)
                                    const Center(child: CircularProgressIndicator(color: Colors.white)),
                                  if (!_controller!.value.isPlaying && !_controller!.value.isBuffering)
                                    const Center(
                                      child: Icon(Icons.play_circle_outline, size: 64, color: Colors.white54),
                                    ),
                                  VideoProgressIndicator(
                                    _controller!, 
                                    allowScrubbing: true, 
                                    colors: const VideoProgressColors(
                                      playedColor: Colors.blueAccent,
                                      bufferedColor: Colors.white24,
                                      backgroundColor: Colors.grey,
                                    )
                                  ),
                                ],
                              ),
                            ),
                ),
              ),
            ),

            Expanded(
              child: videoAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, stack) => Center(child: Text('Error: $err', style: const TextStyle(color: Colors.white))),
                data: (video) {
                  if (video == null) return const SizedBox.shrink();
                  return ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Text(
                        video.title,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      const SizedBox(height: 8),

                      Text(
                        '${video.viewCount} views • ${video.likeCount} likes',
                        style: const TextStyle(color: Colors.grey, fontSize: 14),
                      ),
                      const SizedBox(height: 24),

                      _buildCreatorInfo(context, video),
                      
                      const SizedBox(height: 16),
                      _buildActionButtons(context, video),
                      
                      const SizedBox(height: 24),
                      const Divider(color: Colors.white12),
                      const Text("Suggested Videos", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                      const SizedBox(height: 12),
                      
                      Consumer(
                        builder: (context, ref, child) {
                          final suggestedAsync = ref.watch(suggestedVideosProvider(widget.videoId));
                          return suggestedAsync.when(
                            loading: () => const SizedBox(height: 100, child: Center(child: CircularProgressIndicator())),
                            error: (e, s) => const Text("Failed to load suggestions", style: TextStyle(color: Colors.white)),
                            data: (videos) {
                              if (videos.isEmpty) return const Padding(padding: EdgeInsets.all(16), child: Text("No suggestions available.", style: TextStyle(color: Colors.grey)));
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
  
  Widget _buildCreatorInfo(BuildContext context, Video video) {
    final isFollowingAsync = ref.watch(isFollowingProvider(video.creatorId));

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: Colors.grey[800],
              child: Text(
                video.creatorName.isNotEmpty ? video.creatorName[0].toUpperCase() : 'U', 
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)
              ),
            ),
            const SizedBox(width: 12.0),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  video.creatorName,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w600),
                ),
                const Text("Creator", style: TextStyle(color: Colors.grey, fontSize: 12)),
              ],
            ),
          ],
        ),

        isFollowingAsync.when(
          data: (isFollowing) {
            return ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: isFollowing ? Colors.grey[800] : Colors.blueAccent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                elevation: 0,
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

  Widget _buildActionButtons(BuildContext context, Video video) {
    final isLikedAsync = ref.watch(isLikedProvider(video.id));
    final isSavedAsync = ref.watch(isSavedProvider(video.id));

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        // Like Button
        isLikedAsync.when(
          data: (isLiked) {
            return InkWell(
              onTap: () => ref.read(interactionProvider).toggleLike(video.id),
              borderRadius: BorderRadius.circular(30),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
                child: Column(
                  children: [
                    Icon(
                      isLiked ? Icons.thumb_up : Icons.thumb_up_outlined,
                      color: isLiked ? Colors.blueAccent : Colors.white,
                      size: 28,
                    ),
                    const SizedBox(height: 4),
                    Text(isLiked ? 'Liked' : 'Like', style: TextStyle(color: isLiked ? Colors.blueAccent : Colors.white70, fontSize: 12)),
                  ],
                ),
              ),
            );
          },
          loading: () => const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)),
          error: (e, s) => const Icon(Icons.error, color: Colors.red),
        ),
        
        // Comment Button
        InkWell(
          onTap: () => _showComments(context, video.id),
          borderRadius: BorderRadius.circular(30),
          child: const Padding(
            padding: EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
            child: Column(
              children: [
                Icon(Icons.comment_outlined, color: Colors.white, size: 28),
                SizedBox(height: 4),
                Text('Comment', style: TextStyle(color: Colors.white70, fontSize: 12)),
              ],
            ),
          ),
        ),

        // Save Button (Watch Later)
        isSavedAsync.when(
          data: (isSaved) {
            return InkWell(
              onTap: () async {
                await ref.read(interactionProvider).toggleWatchLater(video.id);
              },
              borderRadius: BorderRadius.circular(30),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
                child: Column(
                  children: [
                    Icon(
                      isSaved ? Icons.bookmark : Icons.bookmark_border,
                      color: isSaved ? Colors.blueAccent : Colors.white,
                      size: 28,
                    ),
                    const SizedBox(height: 4),
                    Text(isSaved ? 'Saved' : 'Save', style: TextStyle(color: isSaved ? Colors.blueAccent : Colors.white70, fontSize: 12)),
                  ],
                ),
              ),
            );
          },
          loading: () => const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)),
          error: (e,s) => const Icon(Icons.error, color: Colors.grey),
        ),
        
        // Share Button
        InkWell(
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Share functionality coming soon!")));
          },
          borderRadius: BorderRadius.circular(30),
          child: const Padding(
            padding: EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
            child: Column(
              children: [
                Icon(Icons.share_outlined, color: Colors.white, size: 28),
                SizedBox(height: 4),
                Text('Share', style: TextStyle(color: Colors.white70, fontSize: 12)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}