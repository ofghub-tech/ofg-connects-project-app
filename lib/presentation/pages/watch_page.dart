import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:share_plus/share_plus.dart';
import 'package:timeago/timeago.dart' as timeago;

import 'package:ofgconnects/api/appwrite_client.dart';
import 'package:ofgconnects/logic/interaction_provider.dart';
import 'package:ofgconnects/logic/subscription_provider.dart';
import 'package:ofgconnects/logic/video_provider.dart';
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

  @override
  void initState() {
    super.initState();
    _player = Player();
    _controller = VideoController(_player);
    Future.microtask(() => ref.read(interactionProvider).logVideoView(widget.videoId));
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _initPlayer(model.Video video) async {
    if (_isPlayerInitialized) return;
    String url = video.compressionStatus == 'Done'
        ? (video.url360p ?? video.videoUrl)
        : video.videoUrl;
    if (!url.startsWith('http')) {
      url = AppwriteClient.storage
          .getFileView(bucketId: AppwriteClient.bucketIdVideos, fileId: url)
          .toString();
    }
    await _player.open(Media(url));
    if (mounted) setState(() => _isPlayerInitialized = true);
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
                              child: CircularProgressIndicator(color: OfgUi.accent),
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
                        OfgUi.sectionHeader(title: 'Up Next'),
                        const SizedBox(height: 8),
                        _buildSuggestions(),
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
