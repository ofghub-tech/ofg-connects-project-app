// lib/presentation/pages/watch_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ofgconnects_mobile/logic/video_provider.dart';
import 'package:ofgconnects_mobile/presentation/widgets/suggested_video_card.dart';

// --- ADD THESE IMPORTS ---
import 'dart:io';
import 'package:video_player/video_player.dart';
import 'package:ofgconnects_mobile/logic/storage_provider.dart';
import 'package:ofgconnects_mobile/models/video.dart';

// --- THIS IS THE FIX ---
// No more name conflict, so we can import the whole file
import 'package:ofgconnects_mobile/logic/subscription_provider.dart'; 
// --- END OF FIX ---


// 1. Convert to ConsumerStatefulWidget
class WatchPage extends ConsumerStatefulWidget {
  final String videoId;
  
  const WatchPage({super.key, required this.videoId});

  @override
  ConsumerState<WatchPage> createState() => _WatchPageState();
}

class _WatchPageState extends ConsumerState<WatchPage> {
  // 2. Add Controller and Future variables
  VideoPlayerController? _controller;
  Future<void>? _initializeVideoPlayerFuture;

  @override
  void initState() {
    super.initState();
    // 3. Start initializing the player
    _initializePlayer();
  }

  // 4. New method to load the video file
  Future<void> _initializePlayer() async {
    try {
      final videoFile = await ref.read(videoFileProvider(widget.videoId).future);
      final controller = VideoPlayerController.file(videoFile);
      
      setState(() {
        _controller = controller;
        _initializeVideoPlayerFuture = controller.initialize().then((_) {
          _controller?.play();
          setState(() {});
        });
      });

    } catch (e) {
      print("Error initializing video player: $e");
      setState(() {
        _initializeVideoPlayerFuture = Future.error(e);
      });
    }
  }

  // 5. Clean up the controller when the page is closed
  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final allVideosAsync = ref.watch(videoListProvider);
    final videoDetailsAsync = ref.watch(videoDetailsProvider(widget.videoId));

    return Scaffold(
      appBar: AppBar(
        title: videoDetailsAsync.when(
          data: (video) => Text(video.title),
          loading: () => const Text('Loading...'),
          error: (e, s) => const Text('Error'),
        ),
      ),
      body: ListView(
        children: [
          
          // --- VIDEO PLAYER UI ---
          AspectRatio(
            aspectRatio: 16 / 9,
            child: _initializeVideoPlayerFuture == null
                ? _buildLoadingPlaceholder('Initializing...') 
                : FutureBuilder(
                    future: _initializeVideoPlayerFuture,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.done && snapshot.error == null) {
                        return Stack(
                          alignment: Alignment.bottomCenter,
                          children: [
                            VideoPlayer(_controller!),
                            IconButton(
                              icon: Icon(
                                _controller!.value.isPlaying ? Icons.pause : Icons.play_arrow,
                                color: Colors.white,
                                size: 50,
                              ),
                              onPressed: () {
                                setState(() {
                                  _controller!.value.isPlaying
                                      ? _controller!.pause()
                                      : _controller!.play();
                                });
                              },
                            ),
                            VideoProgressIndicator(_controller!, allowScrubbing: true),
                          ],
                        );
                      } else if (snapshot.error != null) {
                        return _buildErrorPlaceholder(snapshot.error.toString());
                      } else {
                        return _buildLoadingPlaceholder('Loading video...');
                      }
                    },
                  ),
          ),
          
          // --- CREATOR INFO & FOLLOW BUTTON ---
          videoDetailsAsync.when(
            data: (video) => _buildCreatorInfo(context, video),
            loading: () => const Padding(
              padding: EdgeInsets.all(16.0),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, s) => const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text('Error loading video details.'),
            ),
          ),

          const Divider(),

          // --- Suggested Videos List ---
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Text(
              'Suggested Videos',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          
          allVideosAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, stack) => const Center(child: Text('Could not load suggestions')),
            data: (allVideos) {
              final suggestedVideos = allVideos.where((v) => v.id != widget.videoId).toList();

              return ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: suggestedVideos.length,
                itemBuilder: (context, index) {
                  final suggestedVideo = suggestedVideos[index];
                  return SuggestedVideoCard(video: suggestedVideo);
                },
              );
            },
          ),
        ],
      ),
    );
  }

  // --- WIDGET FOR CREATOR INFO & FOLLOW BUTTON ---
  Widget _buildCreatorInfo(BuildContext context, Video video) {
    // This will now work
    final isFollowingAsync = ref.watch(isFollowingProvider(video.creatorId));

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Creator Avatar & Name
          Row(
            children: [
              CircleAvatar(
                child: Text(video.creatorName.isNotEmpty ? video.creatorName[0] : 'U'),
              ),
              const SizedBox(width: 12.0),
              Text(
                video.creatorName,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ],
          ),

          // Follow/Unfollow Button
          isFollowingAsync.when(
            data: (isFollowing) {
              return ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: isFollowing ? Colors.grey[800] : Colors.red,
                  foregroundColor: Colors.white,
                ),
                onPressed: () {
                  // This will also work
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
            loading: () => const ElevatedButton(
              onPressed: null,
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
            error: (e, s) => ElevatedButton(
              onPressed: null,
              child: const Icon(Icons.error, color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  // --- HELPER WIDGETS FOR THE PLAYER ---
  Widget _buildLoadingPlaceholder(String text) {
    return Container(
      color: Colors.black,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(text, style: const TextStyle(color: Colors.white)),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorPlaceholder(String error) {
    return Container(
      color: Colors.black,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 50),
              const SizedBox(height: 16),
              Text(
                'Error loading video: $error',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white),
              ),
            ],
          ),
        ),
      ),
    );
  }
}