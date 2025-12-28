// lib/presentation/widgets/shorts_player.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
<<<<<<< HEAD
// CORRECTION: Package name must match pubspec.yaml (ofgconnects)
=======
>>>>>>> ae3527dc080370e17b52e3164c73699c33084bda
import 'package:ofgconnects/models/video.dart' as model;
import 'package:ofgconnects/logic/shorts_provider.dart';
import 'package:ofgconnects/presentation/pages/shorts_page.dart';

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
    _player.dispose();
    super.dispose();
  }

  Future<void> _initPlayer() async {
    // FIX: Using videoUrl directly for speed, as requested.
    // Ensure your database contains the full, valid URL.
    try {
      await _player.open(Media(widget.video.videoUrl), play: false); 
      await _player.setPlaylistMode(PlaylistMode.loop); // Loops video automatically

      if (mounted) {
        setState(() => _isInitialized = true);
        _checkAutoPlay();
      }
    } catch (e) {
      debugPrint("Error loading video: $e");
    }
  }

  void _checkAutoPlay() {
    final activeIndex = ref.read(activeShortsIndexProvider);
    if (activeIndex == widget.index) {
      _player.play();
    }
  }

  @override
  Widget build(BuildContext context) {
    // 1. Listen for swipe changes (Auto play/pause)
    ref.listen(activeShortsIndexProvider, (prev, next) {
      if (!_isInitialized) return;
      if (next == widget.index) {
        _player.play();
      } else {
        _player.pause();
        _player.seek(Duration.zero); // Reset position
      }
    });

    // 2. Listen for manual play/pause tap
    ref.listen(shortsPlayPauseProvider(widget.video.id), (prev, isPlaying) {
      if (isPlaying) {
        _player.play();
      } else {
        _player.pause();
      }
      
      // Temporary animation overlay
      if (mounted) {
        setState(() => _showPauseIcon = true);
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) setState(() => _showPauseIcon = false);
        });
      }
    });

    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          color: Colors.black,
          child: Center(
            child: _isInitialized
                // FIX: IgnorePointer prevents the Video widget from stealing swipes
                ? IgnorePointer(
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
            ref.read(shortsPlayPauseProvider(widget.video.id)) ? Icons.play_arrow : Icons.pause,
            size: 80,
            color: Colors.white.withOpacity(0.5),
          ),
      ],
    );
  }
}