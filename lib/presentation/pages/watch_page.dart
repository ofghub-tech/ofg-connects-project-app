import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:timeago/timeago.dart' as timeago;

import 'package:ofgconnects_mobile/api/appwrite_client.dart';
import 'package:ofgconnects_mobile/logic/video_provider.dart';
import 'package:ofgconnects_mobile/logic/interaction_provider.dart';
import 'package:ofgconnects_mobile/logic/subscription_provider.dart';
import 'package:ofgconnects_mobile/models/video.dart' as model;
import 'package:ofgconnects_mobile/presentation/widgets/comments_sheet.dart';
import 'package:ofgconnects_mobile/presentation/widgets/suggested_video_card.dart';

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
    String url = video.compressionStatus == 'Done' ? (video.url720p ?? video.videoUrl) : video.videoUrl;
    if (!url.startsWith('http')) {
      url = AppwriteClient.storage.getFileView(bucketId: AppwriteClient.bucketIdVideos, fileId: url).toString();
    }
    await _player.open(Media(url));
    if (mounted) setState(() => _isPlayerInitialized = true);
  }

  @override
  Widget build(BuildContext context) {
    final videoAsync = ref.watch(videoDetailsProvider(widget.videoId));
    final isLiked = ref.watch(isLikedProvider(widget.videoId)).value ?? false;
    final isSaved = ref.watch(isSavedProvider(widget.videoId)).value ?? false;

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      body: SafeArea(
        child: videoAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, _) => Center(child: Text("Error: $err")),
          data: (video) {
            _initPlayer(video);
            final isFollowing = ref.watch(isFollowingProvider(video.creatorId)).value ?? false;

            return Column(
              children: [
                AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Container(
                    color: Colors.black,
                    child: _isPlayerInitialized 
                        ? Video(controller: _controller, controls: MaterialVideoControls)
                        : const Center(child: CircularProgressIndicator(color: Colors.blueAccent)),
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(video.title, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        child: Text("${NumberFormat.compact().format(video.viewCount)} views • ${timeago.format(video.createdAt)}", style: const TextStyle(color: Colors.grey, fontSize: 12)),
                      ),
                      _buildActionRow(video, isLiked, isSaved),
                      const Divider(color: Colors.white10),
                      _buildCreatorRow(video, isFollowing),
                      const Divider(color: Colors.white10),
                      ListTile(
                        onTap: () => _showComments(video.id),
                        title: const Text("Comments", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        trailing: const Icon(Icons.keyboard_arrow_down, color: Colors.white),
                        subtitle: Text("Add a comment...", style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                      ),
                      const Divider(color: Colors.white10),
                      _buildSuggestions(),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildActionRow(model.Video video, bool isLiked, bool isSaved) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          _actionBtn(isLiked ? Icons.thumb_up : Icons.thumb_up_outlined, video.likeCount.toString(), isLiked, 
            () => ref.read(isLikedProvider(widget.videoId).notifier).toggle()),
          const SizedBox(width: 8),
          _actionBtn(Icons.share_outlined, "Share", false, 
            () => Share.share("Check this out: ${video.title}\n${video.videoUrl}")),
          const SizedBox(width: 8),
          _actionBtn(isSaved ? Icons.bookmark : Icons.bookmark_outline, "Save", isSaved, 
            () => ref.read(isSavedProvider(widget.videoId).notifier).toggle()),
        ],
      ),
    );
  }

  Widget _buildCreatorRow(model.Video video, bool isFollowing) {
    return ListTile(
      leading: CircleAvatar(backgroundColor: Colors.blueAccent, child: Text(video.creatorName[0])),
      title: Text(video.creatorName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      trailing: ElevatedButton(
        onPressed: () => isFollowing 
            ? ref.read(subscriptionNotifierProvider.notifier).unfollowUser(video.creatorId)
            : ref.read(subscriptionNotifierProvider.notifier).followUser(creatorId: video.creatorId, creatorName: video.creatorName),
        style: ElevatedButton.styleFrom(backgroundColor: isFollowing ? Colors.white12 : Colors.white),
        child: Text(isFollowing ? "Following" : "Follow", style: TextStyle(color: isFollowing ? Colors.white : Colors.black)),
      ),
    );
  }

  Widget _buildSuggestions() {
    return ref.watch(suggestedVideosProvider(widget.videoId)).when(
      data: (list) => Column(children: list.map((v) => SuggestedVideoCard(video: v)).toList()),
      loading: () => const SizedBox(),
      error: (_, __) => const SizedBox(),
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

  Widget _actionBtn(IconData icon, String label, bool active, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(color: active ? Colors.white24 : Colors.white12, borderRadius: BorderRadius.circular(20)),
        child: Row(children: [Icon(icon, size: 18, color: active ? Colors.blueAccent : Colors.white), const SizedBox(width: 8), Text(label, style: const TextStyle(color: Colors.white, fontSize: 13))]),
      ),
    );
  }
}