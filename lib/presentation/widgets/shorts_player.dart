// lib/presentation/widgets/shorts_player.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
    _initializePlayer();
  }

  Future<void> _initializePlayer() async {
    try {
      // DIRECT FIX: Use the videoUrl directly from the model.
      // We assume the DB contains a valid full URL.
      if (widget.video.videoUrl.isEmpty) {
        throw Exception('Video URL is empty for video: ${widget.video.title}');
      }

      final controller = VideoPlayerController.networkUrl(
        Uri.parse(widget.video.videoUrl),
      );

      setState(() {
        _controller = controller;
        _initializeVideoPlayerFuture = controller.initialize().then((_) {
          _controller?.setLooping(true);

          // Only auto-play if this is the currently active page
          final activeIndex = ref.read(activeShortsIndexProvider);
          if (widget.index == activeIndex) {
            _controller?.play();
          }
          // Rebuild to show the player
          if (mounted) setState(() {});
        });
      });
    } catch (e) {
      print("Error initializing shorts player: $e");
      if (mounted) {
        setState(() {
          _initializeVideoPlayerFuture = Future.error(e);
        });
      }
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<int>(activeShortsIndexProvider, (previous, next) {
      if (next == widget.index) {
        _controller?.play();
      } else {
        _controller?.pause();
      }
    });

    return FutureBuilder(
      future: _initializeVideoPlayerFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done &&
            snapshot.error == null &&
            _controller != null &&
            _controller!.value.isInitialized) {
          return GestureDetector(
            onTap: () {
              setState(() {
                _controller!.value.isPlaying
                    ? _controller!.pause()
                    : _controller!.play();
              });
            },
            child: Stack(
              fit: StackFit.expand,
              children: [
                AspectRatio(
                  aspectRatio: _controller!.value.aspectRatio,
                  child: VideoPlayer(_controller!),
                ),
                if (_controller!.value.isBuffering)
                  const Center(child: CircularProgressIndicator()),
                // Overlay Info
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
        } else if (snapshot.hasError) {
          return Container(
            color: Colors.black,
            child: Center(
              child: Text(
                'Error: ${snapshot.error}',
                style: const TextStyle(color: Colors.white),
                textAlign: TextAlign.center,
              ),
            ),
          );
        } else {
          return Container(
            color: Colors.black,
            child: const Center(child: CircularProgressIndicator()),
          );
        }
      },
    );
  }
}