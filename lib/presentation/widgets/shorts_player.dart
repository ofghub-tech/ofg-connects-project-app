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
    
    // --- PERFORMANCE FIX: Increased Buffer & Hardware Config ---
    _player = Player(
      configuration: const PlayerConfiguration(
        bufferSize: 32 * 1024 * 1024, // 32MB Buffer for smoother playback
        vo: 'gpu', // Force GPU rendering (Android/iOS)
      ),
    );
    
    _controller = VideoController(
      _player,
      configuration: const VideoControllerConfiguration(
        scale: 1.0,
        enableHardwareAcceleration: true,
        hwdec: 'auto', // Auto-detect best hardware decoder
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
    try {
      String url = widget.video.compressionStatus == 'Done' 
          ? (widget.video.url360p ?? widget.video.videoUrl) 
          : widget.video.videoUrl;

      if (!url.startsWith('http')) {
        url = AppwriteClient.storage.getFileView(
          bucketId: AppwriteClient.bucketIdVideos, 
          fileId: url
        ).toString();
      }

      // --- SPEED FIX: Don't wait for headers to play ---
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
    if (activeIndex == widget.index) {
      _player.play();
    } else {
      _player.pause();
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(activeShortsIndexProvider, (prev, next) {
      if (!_isInitialized) return;
      if (next == widget.index) {
        _player.play();
      } else {
        _player.pause();
        _player.seek(Duration.zero); 
      }
    });

    ref.listen<bool>(shortsPlayPauseProvider(widget.video.id), (prev, isPlaying) {
      if (isPlaying) {
        _player.play();
      } else {
        _player.pause();
      }
      
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