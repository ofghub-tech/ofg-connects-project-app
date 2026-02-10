// lib/presentation/widgets/shorts_player.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart'; 
import 'package:media_kit_video/media_kit_video.dart'; 
import 'package:ofgconnects/models/video.dart' as model;
import 'package:ofgconnects/logic/shorts_provider.dart'; 
import 'package:ofgconnects/api/appwrite_client.dart';

class ShortsPlayer extends ConsumerStatefulWidget {
  final model.Video video;
  final int index;
  
  const ShortsPlayer({super.key, required this.video, required this.index});

  @override
  ConsumerState<ShortsPlayer> createState() => _ShortsPlayerState();
}

class _ShortsPlayerState extends ConsumerState<ShortsPlayer> {
  late final Player _player;
  late final VideoController _controller;
  bool _isInitialized = false;
  bool _showPauseIcon = false;

  @override
  void initState() {
    super.initState();
    // 1. Initialize Player
    _player = Player();
    _controller = VideoController(
      _player,
      configuration: const VideoControllerConfiguration(
        scale: 1.0,
        enableHardwareAcceleration: true,
      ),
    );
    _initPlayer();
  }

  @override
  void dispose() {
    // 2. Dispose Player safely
    _player.dispose();
    super.dispose();
  }

  Future<void> _initPlayer() async {
    try {
      // 3. Resolve URL (Handle compression & Appwrite File IDs)
      String url = widget.video.compressionStatus == 'Done' 
          ? (widget.video.url360p ?? widget.video.videoUrl) 
          : widget.video.videoUrl;

      // If it's a File ID (no http), fetch the view URL
      if (!url.startsWith('http')) {
        url = AppwriteClient.storage.getFileView(
          bucketId: AppwriteClient.bucketIdVideos, 
          fileId: url
        ).toString();
      }

      // 4. Open Media
      await _player.open(Media(url), play: false); 
      await _player.setPlaylistMode(PlaylistMode.loop); 

      if (mounted) {
        setState(() => _isInitialized = true);
        _checkAutoPlay();
      }
    } catch (e) {
      debugPrint("Error loading video: $e");
    }
  }

  void _checkAutoPlay() {
    if (!_isInitialized) return;
    
    final activeIndex = ref.read(activeShortsIndexProvider);
    // Only play if this is the active video
    if (activeIndex == widget.index) {
      _player.play();
    } else {
      _player.pause();
    }
  }

  @override
  Widget build(BuildContext context) {
    // 5. Listen: Scroll Changes (Active Index)
    ref.listen(activeShortsIndexProvider, (prev, next) {
      if (!_isInitialized) return;
      if (next == widget.index) {
        _player.play();
      } else {
        _player.pause();
        _player.seek(Duration.zero); // Reset when scrolling away
      }
    });

    // 6. Listen: Manual Play/Pause (Tap)
    // Explicitly typed <bool> to prevent "Object?" errors
    ref.listen<bool>(shortsPlayPauseProvider(widget.video.id), (prev, isPlaying) {
      if (isPlaying) {
        _player.play();
      } else {
        _player.pause();
      }
      
      // Show icon animation
      if (mounted) {
        setState(() => _showPauseIcon = true);
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) setState(() => _showPauseIcon = false);
        });
      }
    });

    // 7. Watch: UI State for Icon
    final isPlaying = ref.watch(shortsPlayPauseProvider(widget.video.id));

    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          color: Colors.black,
          child: Center(
            child: _isInitialized
                ? IgnorePointer(
                    // Ignore pointer to let GestureDetector in parent handle taps
                    child: Video(
                      controller: _controller,
                      fit: BoxFit.cover,
                      controls: NoVideoControls,
                    ),
                  )
                : const CircularProgressIndicator(color: Colors.white),
          ),
        ),
        if (_showPauseIcon)
          Icon(
            isPlaying ? Icons.play_arrow : Icons.pause,
            size: 80,
            color: Colors.white.withOpacity(0.5),
          ),
      ],
    );
  }
}