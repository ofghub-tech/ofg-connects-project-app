// lib/presentation/widgets/shorts_player.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'dart:async';
import 'package:ofgconnects/models/video.dart' as model;
import 'package:ofgconnects/logic/shorts_provider.dart';
import 'package:ofgconnects/logic/video_stream_resolver.dart';
import 'package:ofgconnects/logic/data_saver.dart';

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
  ProviderSubscription<int>? _activeIndexSub;
  ProviderSubscription<bool>? _playPauseSub;
  Timer? _pauseIconTimer;
  
  bool _isInitialized = false;
  bool _showPauseIcon = false;
  bool _isDisposed = false;
  bool _isSwitchingQuality = false;
  
  // Track if we have initiated the network download
  bool _hasOpenedMedia = false; 
  bool _isOpeningMedia = false;
  Timer? _adaptiveTimer;
  List<String> _adaptiveUrls = const [];
  int _qualityIndex = 0;

  @override
  void initState() {
    super.initState();
    
    // Keep a smaller buffer size for faster startup on slow networks.
    _player = Player(
      configuration: PlayerConfiguration(
        bufferSize: kDataSaverEnabled ? 256 * 1024 : 1 * 1024 * 1024,
      ),
    );
    
    _controller = VideoController(
      _player,
      configuration: const VideoControllerConfiguration(
        scale: 1.0,
        enableHardwareAcceleration: true,
      ),
    );

    // Wait for the UI to build, then evaluate if we should start downloading
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final initialIndex = ref.read(activeShortsIndexProvider);
        _evaluateMediaState(initialIndex);
      }
    });

    _activeIndexSub = ref.listenManual<int>(
      activeShortsIndexProvider,
      (prev, next) {
        _evaluateMediaState(next);

        if (!_isInitialized) return;
        if (next == widget.index) {
          _player.play();
        } else {
          // Pause only. Avoid seeking to zero on every swipe to reduce flush/reconfigure churn.
          _player.pause();
        }
      },
      fireImmediately: false,
    );

    _playPauseSub = ref.listenManual<bool>(
      shortsPlayPauseProvider(widget.video.id),
      (prev, isPlaying) {
        if (_isDisposed) return;
        if (isPlaying) {
          _player.play();
        } else {
          _player.pause();
        }

        if (mounted) {
          setState(() => _showPauseIcon = true);
          _pauseIconTimer?.cancel();
          _pauseIconTimer = Timer(const Duration(milliseconds: 500), () {
            if (!_isDisposed && mounted) {
              setState(() => _showPauseIcon = false);
            }
          });
        }
      },
      fireImmediately: false,
    );
  }

  @override
  void dispose() {
    _isDisposed = true;
    _activeIndexSub?.close();
    _playPauseSub?.close();
    _pauseIconTimer?.cancel();
    _adaptiveTimer?.cancel();
    _isInitialized = false;
    _player.dispose();
    super.dispose();
  }

  void _startAdaptiveMonitor() {
    _adaptiveTimer?.cancel();
    _adaptiveTimer = Timer.periodic(const Duration(seconds: 6), (_) async {
      if (_isDisposed || !_isInitialized || _adaptiveUrls.length < 2 || _isSwitchingQuality) {
        return;
      }

      if (_player.state.buffering && _qualityIndex > 0) {
        await _switchQuality(_qualityIndex - 1);
        return;
      }

      final stablePlayback =
          _player.state.playing &&
          !_player.state.buffering &&
          _player.state.position > const Duration(seconds: 8);
      if (!kDataSaverEnabled &&
          stablePlayback &&
          _qualityIndex < _adaptiveUrls.length - 1) {
        await _switchQuality(_qualityIndex + 1);
      }
    });
  }

  Future<void> _switchQuality(int newIndex) async {
    if (_isDisposed ||
        _isSwitchingQuality ||
        newIndex == _qualityIndex ||
        newIndex < 0 ||
        newIndex >= _adaptiveUrls.length) {
      return;
    }

    _isSwitchingQuality = true;
    final shouldPlay = _player.state.playing;
    final resumeAt = _player.state.position;
    try {
      await _player
          .open(Media(_adaptiveUrls[newIndex]), play: false)
          .timeout(const Duration(seconds: 6));
      if (resumeAt > Duration.zero) {
        await _player.seek(resumeAt);
      }
      if (shouldPlay) {
        await _player.play();
      }
      _qualityIndex = newIndex;
    } catch (_) {
      // Keep current quality.
    } finally {
      _isSwitchingQuality = false;
    }
  }

  /// Evaluates whether this specific video should be downloading or paused in memory
  Future<void> _evaluateMediaState(int activeIndex) async {
    if (_isDisposed) return;
    final distance = (activeIndex - widget.index).abs();

    // On slow networks, only open the active video first to avoid parallel buffering.
    if (distance == 0 && !_hasOpenedMedia && !_isOpeningMedia) {
      _isOpeningMedia = true;
      _hasOpenedMedia = true;

      try {
        final urls = resolvePlayableVideoUrls(widget.video);
        if (urls.isEmpty) return;
        _adaptiveUrls = urls;
        _qualityIndex = 0;

        Object? lastError;
        var opened = false;
        for (var i = 0; i < urls.length; i++) {
          if (_isDisposed) return;
          try {
            await _player
                .open(Media(urls[i]), play: false)
                .timeout(const Duration(seconds: 6));
            opened = true;
            _qualityIndex = i;
            break;
          } catch (e) {
            lastError = e;
          }
        }
        if (!opened) {
          debugPrint("Error loading video variants: $lastError");
          return;
        }

        if (_isDisposed || !mounted) return;

        await _player.setPlaylistMode(PlaylistMode.loop); 

        if (!_isDisposed && mounted) {
          setState(() => _isInitialized = true);
          _startAdaptiveMonitor();
          // If this is the active video, start playing immediately
          if (activeIndex == widget.index) {
            _player.play();
          }
        }
      } catch (e) {
        debugPrint("Error loading video: $e");
      } finally {
        _isOpeningMedia = false;
      }
    } 
    
    // Keep decoder warm when swiping to avoid frequent destroy/recreate cycles on Android codecs.
    else if (distance > 2 && _hasOpenedMedia) {
      _player.pause();
    }
  }

  @override
  Widget build(BuildContext context) {
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
                : const Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(color: Colors.white),
                      SizedBox(height: 10),
                      Text(
                        'Loading low-data stream...',
                        style: TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ],
                  ),
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
