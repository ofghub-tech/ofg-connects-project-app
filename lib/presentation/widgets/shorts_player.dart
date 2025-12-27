import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart'; // <--- Needed for ConsumerStatefulWidget
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:ofgconnects_mobile/models/video.dart' as model;
import 'package:ofgconnects_mobile/api/appwrite_client.dart';
import 'package:ofgconnects_mobile/logic/shorts_provider.dart'; // <--- Ensure this is imported

class ShortsPlayer extends ConsumerStatefulWidget {
  final model.Video video;
  final int index; // <--- ADDED THIS PARAMETER
  
  const ShortsPlayer({
    super.key, 
    required this.video, 
    required this.index // <--- ADDED THIS
  });

  @override
  ConsumerState<ShortsPlayer> createState() => _ShortsPlayerState();
}

class _ShortsPlayerState extends ConsumerState<ShortsPlayer> {
  late final Player _player;
  late final VideoController _controller;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _player = Player();
    _controller = VideoController(
      _player,
      configuration: const VideoControllerConfiguration(
        scale: 1.0,
        enableHardwareAcceleration: true,
      )
    );
    _initPlayer();
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _initPlayer() async {
    // 1. Construct URL
    String url = widget.video.videoUrl;
    if (!url.startsWith('http')) {
       url = AppwriteClient.storage.getFileView(
        bucketId: AppwriteClient.bucketIdVideos,
        fileId: widget.video.videoUrl,
      ).toString();
    }
    // Android Emulator Fix
    if (url.contains('localhost')) {
      url = url.replaceFirst('localhost', '10.0.2.2');
    }
    if (!url.startsWith('http')) {
      url = 'http://$url';
    }

    // 2. Open Media (Start Paused)
    await _player.open(Media(url), play: false); 
    await _player.setPlaylistMode(PlaylistMode.single); 

    if (mounted) {
      setState(() {
        _isInitialized = true;
      });
      // 3. Check if we should play immediately (e.g. first video)
      _checkAutoPlay();
    }
  }

  void _checkAutoPlay() {
    final activeIndex = ref.read(activeShortsIndexProvider);
    if (activeIndex == widget.index) {
      _player.play();
    } else {
      _player.pause();
    }
  }

  @override
  Widget build(BuildContext context) {
    // 4. Listen to index changes to Play/Pause automatically
    ref.listen(activeShortsIndexProvider, (previous, next) {
      if (!_isInitialized) return;
      
      if (next == widget.index) {
        _player.play();
      } else {
        _player.pause();
      }
    });

    return Container(
      color: Colors.black,
      child: Center(
        child: _isInitialized
            ? Video(
                controller: _controller,
                fit: BoxFit.cover, // Shorts cover the whole screen
                controls: NoVideoControls, // Clean UI for shorts
              )
            : const CircularProgressIndicator(color: Colors.white),
      ),
    );
  }
}