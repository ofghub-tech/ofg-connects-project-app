import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:async';
import 'package:intl/intl.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:share_plus/share_plus.dart';
import 'package:timeago/timeago.dart' as timeago;

import 'package:ofgconnects/logic/interaction_provider.dart';
import 'package:ofgconnects/logic/subscription_provider.dart';
import 'package:ofgconnects/logic/video_provider.dart';
import 'package:ofgconnects/logic/video_stream_resolver.dart';
import 'package:ofgconnects/logic/data_saver.dart';
import 'package:ofgconnects/models/video.dart' as model;
import 'package:ofgconnects/presentation/theme/ofg_ui.dart';
import 'package:ofgconnects/presentation/widgets/comments_sheet.dart';
import 'package:ofgconnects/presentation/widgets/suggested_video_card.dart';

class WatchPage extends ConsumerStatefulWidget {
  final String videoId;
  const WatchPage({super.key, required this.videoId});

  @override
  ConsumerState<WatchPage> createState() => _WatchPageState();
}

class _WatchPageState extends ConsumerState<WatchPage> {
  late final Player _player;
  late final VideoController _controller;
  bool _isPlayerInitialized = false;
  bool _isOpeningPlayer = false;
  bool _isSwitchingQuality = false;
  bool _canLoadSuggestions = false;
  Timer? _suggestionsTimer;
  Timer? _adaptiveTimer;
  List<String> _adaptiveUrls = const [];
  int _qualityIndex = 0;

  @override
  void initState() {
    super.initState();
    _player = Player(
      configuration: PlayerConfiguration(
        bufferSize: kDataSaverEnabled ? 256 * 1024 : 2 * 1024 * 1024,
      ),
    );
    _controller = VideoController(_player);
    Future.microtask(() => ref.read(interactionProvider).logVideoView(widget.videoId));
  }

  @override
  void dispose() {
    _suggestionsTimer?.cancel();
    _adaptiveTimer?.cancel();
    _player.dispose();
    super.dispose();
  }

  void _startAdaptiveMonitor() {
    _adaptiveTimer?.cancel();
    _adaptiveTimer = Timer.periodic(const Duration(seconds: 6), (_) async {
      if (!mounted || _adaptiveUrls.length < 2 || _isSwitchingQuality) return;

      // If buffering, step down quality immediately.
      if (_player.state.buffering && _qualityIndex > 0) {
        await _switchQuality(_qualityIndex - 1);
        return;
      }

      // If stable playback, step up gradually (except in hard data saver mode).
      final stablePlayback =
          _player.state.playing &&
          !_player.state.buffering &&
          _player.state.position > const Duration(seconds: 12);
      if (!kDataSaverEnabled &&
          stablePlayback &&
          _qualityIndex < _adaptiveUrls.length - 1) {
        await _switchQuality(_qualityIndex + 1);
      }
    });
  }

  Future<void> _switchQuality(int newIndex) async {
    if (newIndex == _qualityIndex ||
        newIndex < 0 ||
        newIndex >= _adaptiveUrls.length ||
        _isSwitchingQuality) {
      return;
    }

    _isSwitchingQuality = true;
    final shouldPlay = _player.state.playing;
    final resumeAt = _player.state.position;
    try {
      await _player
          .open(Media(_adaptiveUrls[newIndex]), play: false)
          .timeout(const Duration(seconds: 8));
      if (resumeAt > Duration.zero) {
        await _player.seek(resumeAt);
      }
      if (shouldPlay) {
        await _player.play();
      }
      _qualityIndex = newIndex;
    } catch (_) {
      // Keep current stream if switching fails.
    } finally {
      _isSwitchingQuality = false;
    }
  }

  Future<void> _initPlayer(model.Video video) async {
    if (_isPlayerInitialized || _isOpeningPlayer) return;
    _isOpeningPlayer = true;
    try {
      final urls = resolvePlayableVideoUrls(video);
      if (urls.isEmpty) return;
      _adaptiveUrls = urls;
      _qualityIndex = 0;

      Object? lastError;
      var opened = false;
      for (var i = 0; i < urls.length; i++) {
        try {
          await _player
              .open(Media(urls[i]), play: false)
              .timeout(const Duration(seconds: 8));
          opened = true;
          _qualityIndex = i;
          break;
        } catch (e) {
          lastError = e;
        }
      }
      if (!opened) {
        debugPrint('Watch player failed to open all variants: $lastError');
        return;
      }

      if (!mounted) return;
      setState(() => _isPlayerInitialized = true);
      _player.play();
      _startAdaptiveMonitor();
      if (!kDataSaverEnabled) {
        _suggestionsTimer?.cancel();
        _suggestionsTimer = Timer(const Duration(seconds: 3), () {
          if (mounted) {
            setState(() => _canLoadSuggestions = true);
          }
        });
      }
    } finally {
      _isOpeningPlayer = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final videoAsync = ref.watch(videoDetailsProvider(widget.videoId));
    final isSaved = ref.watch(isSavedProvider(widget.videoId)).value ?? false;

    return Scaffold(
      backgroundColor: OfgUi.bg,
      body: SafeArea(
        child: videoAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, _) => Center(child: Text('Error: $err')),
          data: (video) {
            _initPlayer(video);
            final isFollowing = ref.watch(isFollowingProvider(video.creatorId)).value ?? false;
            return Container(
              decoration: const BoxDecoration(gradient: OfgUi.appBackground),
              child: Column(
                children: [
                  AspectRatio(
                    aspectRatio: 16 / 9,
                    child: Container(
                      color: Colors.black,
                      child: _isPlayerInitialized
                          ? Video(controller: _controller, controls: MaterialVideoControls)
                          : const Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  CircularProgressIndicator(color: OfgUi.accent),
                                  SizedBox(height: 10),
                                  Text(
                                    'Optimizing stream for your network...',
                                    style: TextStyle(color: OfgUi.muted2, fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                    ),
                  ),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
                      children: [
                        Text(
                          video.title,
                          style: const TextStyle(
                            fontFamily: 'Cinzel',
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            height: 1.35,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${NumberFormat.compact().format(video.viewCount)} views - ${timeago.format(video.createdAt)}',
                          style: const TextStyle(color: OfgUi.muted2, fontSize: 12),
                        ),
                        const SizedBox(height: 14),
                        _buildActionBar(video, isSaved),
                        const SizedBox(height: 14),
                        _buildCreatorRow(video, isFollowing),
                        const SizedBox(height: 12),
                        _buildDescription(video),
                        const SizedBox(height: 14),
                        _buildCommentsTile(video.id),
                        const SizedBox(height: 14),
                        if (!kDataSaverEnabled) ...[
                          OfgUi.sectionHeader(title: 'Up Next'),
                          const SizedBox(height: 8),
                          _buildSuggestions(),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildActionBar(model.Video video, bool isSaved) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: OfgUi.border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: _actionCell(
              icon: Icons.share_outlined,
              label: 'Share',
              active: false,
              onTap: () => Share.share('Check this out: ${video.title}\n${video.videoUrl}'),
            ),
          ),
          Expanded(
            child: _actionCell(
              icon: isSaved ? Icons.bookmark : Icons.bookmark_outline,
              label: 'Save',
              active: isSaved,
              onTap: () => ref.read(isSavedProvider(widget.videoId).notifier).toggle(),
            ),
          ),
          Expanded(
            child: _actionCell(
              icon: Icons.chat_bubble_outline_rounded,
              label: 'Comment',
              active: false,
              onTap: () => _showComments(video.id),
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionCell({
    required IconData icon,
    required String label,
    required bool active,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: active ? OfgUi.accent : OfgUi.muted2, size: 19),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: active ? OfgUi.accent : OfgUi.muted2,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCreatorRow(model.Video video, bool isFollowing) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: OfgUi.cardDecoration(),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: OfgUi.accent,
            child: Text(
              video.creatorName.isNotEmpty ? video.creatorName[0].toUpperCase() : 'U',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  video.creatorName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                const Text('Content Creator', style: TextStyle(color: OfgUi.muted2, fontSize: 11)),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: () => isFollowing
                ? ref.read(subscriptionNotifierProvider.notifier).unfollowUser(video.creatorId)
                : ref
                    .read(subscriptionNotifierProvider.notifier)
                    .followUser(creatorId: video.creatorId, creatorName: video.creatorName),
            style: ElevatedButton.styleFrom(
              backgroundColor: isFollowing ? OfgUi.surface2 : OfgUi.accent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            ),
            child: Text(isFollowing ? 'Following' : 'Follow'),
          ),
        ],
      ),
    );
  }

  Widget _buildDescription(model.Video video) {
    if (video.description.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: OfgUi.cardDecoration(),
      child: Text(
        video.description,
        style: const TextStyle(color: OfgUi.muted2, fontSize: 13, height: 1.6),
      ),
    );
  }

  Widget _buildCommentsTile(String videoId) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
      onTap: () => _showComments(videoId),
      title: const Text(
        'Comments',
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
      ),
      trailing: const Icon(Icons.keyboard_arrow_down_rounded, color: OfgUi.muted2),
      subtitle: const Text('Add a comment...', style: TextStyle(color: OfgUi.muted2, fontSize: 12)),
    );
  }

  Widget _buildSuggestions() {
    if (!_canLoadSuggestions) return const SizedBox.shrink();
    return ref.watch(suggestedVideosProvider(widget.videoId)).when(
          data: (list) => Column(children: list.map((v) => SuggestedVideoCard(video: v)).toList()),
          loading: () => const SizedBox.shrink(),
          error: (_, __) => const SizedBox.shrink(),
        );
  }

  void _showComments(String videoId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        maxChildSize: 0.95,
        builder: (_, ctrl) => CommentsSheet(videoId: videoId, scrollController: ctrl),
      ),
    );
  }
}
