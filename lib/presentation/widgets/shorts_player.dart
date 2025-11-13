// lib/presentation/widgets/shorts_player.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ofgconnects_mobile/logic/storage_provider.dart';
import 'package:ofgconnects_mobile/logic/shorts_provider.dart';
import 'package:ofgconnects_mobile/models/video.dart';
import 'package:video_player/video_player.dart';

class ShortsPlayer extends ConsumerStatefulWidget {
  final Video video;
  final int index;

  const ShortsPlayer({
    super.key,
    required this.video,
    required this.index,
  });

  @override
  ConsumerState<ShortsPlayer> createState() => _ShortsPlayerState();
}

class _ShortsPlayerState extends ConsumerState<ShortsPlayer> {
  VideoPlayerController? _controller;
  Future<void>? _initializeVideoPlayerFuture;

  @override
  void initState() {
    super.initState();
    // Start initializing the player
    _initializePlayer();
  }

  Future<void> _initializePlayer() async {
    try {
      // --- THIS IS THE FIX (STREAMING LOGIC) ---
      
      // 1. Check if the Video File ID is empty
      if (widget.video.videoId.isEmpty) {
        throw Exception('Video file ID is empty');
      }

      // 2. Get the streamable URL using the File ID
      // We use ref.read here because we are in initState
      final streamUrl = await ref.read(videoStreamUrlProvider(widget.video.videoId).future);

      // 3. Initialize the player with the network URL
      final controller = VideoPlayerController.networkUrl(
        Uri.parse(streamUrl)
      );
      // --- END FIX ---
      
      setState(() {
        _controller = controller;
        // Start loading the video, set it to loop
        _initializeVideoPlayerFuture = controller.initialize().then((_) {
          _controller?.setLooping(true);

          // Only auto-play if this is the active video when it's built.
          final activeIndex = ref.read(activeShortsIndexProvider);
          if (widget.index == activeIndex) {
            _controller?.play();
          }
          setState(() {});
        });
      });

    } catch (e) {
      print("Error initializing shorts player: $e");
      setState(() {
        _initializeVideoPlayerFuture = Future.error(e);
      });
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Listen to the active page index
    ref.listen<int>(activeShortsIndexProvider, (previousIndex, nextIndex) {
      if (nextIndex == widget.index) {
        _controller?.play(); // Play if this is the active short
      } else {
        _controller?.pause(); // Pause if not
      }
    });

    return FutureBuilder(
      future: _initializeVideoPlayerFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done && snapshot.error == null) {
          // --- Main Player UI ---
          return GestureDetector(
            onTap: () {
              // Simple tap to play/pause
              setState(() {
                _controller!.value.isPlaying
                    ? _controller!.pause()
                    : _controller!.play();
              });
            },
            child: Stack(
              fit: StackFit.expand,
              children: [
                // The Video Player
                AspectRatio(
                  aspectRatio: _controller!.value.aspectRatio,
                  child: VideoPlayer(_controller!),
                ),
                
                // Show a loading spinner if buffering
                if (_controller!.value.isBuffering)
                  const Center(child: CircularProgressIndicator()),

                // --- Video Info Overlay ---
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '@${widget.video.creatorName}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          shadows: [Shadow(blurRadius: 4)],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        widget.video.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          shadows: [Shadow(blurRadius: 4)],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        } else if (snapshot.error != null) {
          // --- Error UI ---
          return Container(
            color: Colors.black,
            child: Center(
              child: Text(
                'Error: ${snapshot.error}',
                style: const TextStyle(color: Colors.red),
              ),
            ),
          );
        } else {
          // --- Loading UI ---
          return Container(
            color: Colors.black,
            child: const Center(child: CircularProgressIndicator()),
          );
        }
      },
    );
  }
}