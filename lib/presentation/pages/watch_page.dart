import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';       
import 'package:media_kit_video/media_kit_video.dart'; 
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import 'package:ofgconnects_mobile/api/appwrite_client.dart';
import 'package:ofgconnects_mobile/logic/auth_provider.dart';
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
  bool _isDescriptionExpanded = false;

  @override
  void initState() {
    super.initState();
    _player = Player();
    _controller = VideoController(_player);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(interactionProvider).logVideoView(widget.videoId);
    });
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  String _getStreamingUrl(String url) {
    String finalUrl = url;
    if (!finalUrl.startsWith('http')) {
      finalUrl = AppwriteClient.storage.getFileView(
        bucketId: AppwriteClient.bucketIdVideos,
        fileId: url,
      ).toString();
    }
    if (finalUrl.contains('localhost')) finalUrl = finalUrl.replaceFirst('localhost', '10.0.2.2');
    if (!finalUrl.startsWith('http')) finalUrl = 'http://$finalUrl';
    return finalUrl;
  }

  Future<void> _initializePlayer(model.Video video, {String? specificUrl}) async {
    if (_isPlayerInitialized && specificUrl == null) return;
    try {
      String playUrl = specificUrl ?? (video.compressionStatus == 'Done' 
          ? video.url720p ?? video.url480p ?? video.url1080p ?? video.url360p ?? video.videoUrl
          : video.videoUrl);
      
      await _player.open(Media(_getStreamingUrl(playUrl)));
      if (mounted) setState(() => _isPlayerInitialized = true);
    } catch (e) {
      debugPrint("Player Init Error: $e");
    }
  }

  void _shareVideo(model.Video video) {
    Share.share("Check out this video: ${video.title}\nhttps://ofgconnects.com/watch/${video.id}");
  }

  Widget _buildActionButton(IconData icon, String label, VoidCallback onTap, {bool isActive = false}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? Colors.white.withOpacity(0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white12),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: isActive ? Colors.blueAccent : Colors.white),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(color: isActive ? Colors.blueAccent : Colors.white, fontSize: 12)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final videoAsync = ref.watch(videoDetailsProvider(widget.videoId));
    final suggestedAsync = ref.watch(suggestedVideosProvider(widget.videoId));
    final isLikedAsync = ref.watch(isLikedProvider(widget.videoId));
    final isSavedAsync = ref.watch(isSavedProvider(widget.videoId));

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      body: SafeArea(
        child: videoAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, _) => Center(child: Text("Error: $err", style: const TextStyle(color: Colors.white))),
          data: (video) {
            if (video.adminStatus != 'approved') {
              return const Center(child: Text("Video unavailable", style: TextStyle(color: Colors.white)));
            }
            if (!_isPlayerInitialized) Future.microtask(() => _initializePlayer(video));
            final isFollowingAsync = ref.watch(isFollowingProvider(video.creatorId));

            return Column(
              children: [
                // 1. FORCE 16:9 ASPECT RATIO ALWAYS
                AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Container(
                    color: Colors.black,
                    child: _isPlayerInitialized 
                        ? Video(controller: _controller, controls: MaterialVideoControls)
                        : const Center(child: CircularProgressIndicator()),
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(video.title, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Text('${NumberFormat.compact().format(video.viewCount)} views', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                                  const SizedBox(width: 8),
                                  Text('•  ${DateFormat.yMMMd().format(video.createdAt)}', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  GestureDetector(
                                    onTap: () => context.push('/profile/${video.creatorId}'),
                                    child: CircleAvatar(backgroundColor: Colors.grey[800], radius: 18, child: Text(video.creatorName.isNotEmpty ? video.creatorName[0] : '?', style: const TextStyle(color: Colors.white))),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: GestureDetector(
                                      onTap: () => context.push('/profile/${video.creatorId}'),
                                      child: Text(video.creatorName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15))
                                    )
                                  ),
                                  isFollowingAsync.when(
                                    data: (isFollowing) => SizedBox(
                                      height: 32,
                                      child: ElevatedButton(
                                        onPressed: () {
                                          final notifier = ref.read(subscriptionNotifierProvider.notifier);
                                          if (isFollowing) notifier.unfollowUser(video.creatorId);
                                          else notifier.followUser(creatorId: video.creatorId, creatorName: video.creatorName);
                                        },
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: isFollowing ? Colors.white.withOpacity(0.1) : Colors.white,
                                          foregroundColor: isFollowing ? Colors.white : Colors.black,
                                          padding: const EdgeInsets.symmetric(horizontal: 16),
                                        ),
                                        child: Text(isFollowing ? "Subscribed" : "Subscribe"),
                                      ),
                                    ),
                                    loading: () => const SizedBox.shrink(),
                                    error: (_,__) => const SizedBox.shrink(),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                          child: Row(
                            children: [
                              _buildActionButton(isLikedAsync.valueOrNull == true ? Icons.thumb_up : Icons.thumb_up_outlined, NumberFormat.compact().format(video.likeCount), () => ref.read(isLikedProvider(video.id).notifier).toggle(), isActive: isLikedAsync.valueOrNull == true),
                              const SizedBox(width: 10),
                              _buildActionButton(Icons.share_outlined, "Share", () => _shareVideo(video)),
                              const SizedBox(width: 10),
                              _buildActionButton(isSavedAsync.valueOrNull == true ? Icons.bookmark : Icons.bookmark_outline, "Save", () => ref.read(isSavedProvider(video.id).notifier).toggle(), isActive: isSavedAsync.valueOrNull == true),
                            ],
                          ),
                        ),

                        const Divider(color: Colors.white10),

                        Padding(
                           padding: const EdgeInsets.symmetric(horizontal: 12),
                           child: InkWell(
                             onTap: () => setState(() => _isDescriptionExpanded = !_isDescriptionExpanded),
                             child: Container(
                               width: double.infinity,
                               padding: const EdgeInsets.all(12),
                               decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(12)),
                               child: Column(
                                 crossAxisAlignment: CrossAxisAlignment.start,
                                 children: [
                                   Text(video.description.isEmpty ? "No description" : video.description, maxLines: _isDescriptionExpanded ? null : 2, overflow: _isDescriptionExpanded ? TextOverflow.visible : TextOverflow.ellipsis, style: const TextStyle(color: Colors.white70, fontSize: 13)),
                                   if (!_isDescriptionExpanded && video.description.isNotEmpty) const Text("...more", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12))
                                 ],
                               ),
                             ),
                           ),
                        ),
                        
                        ListTile(
                          onTap: () => showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: Colors.transparent, builder: (context) => DraggableScrollableSheet(initialChildSize: 0.75, maxChildSize: 0.9, builder: (_, controller) => CommentsSheet(videoId: video.id, scrollController: controller))),
                          title: const Text("Comments", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          trailing: const Icon(Icons.unfold_more, color: Colors.white, size: 20),
                        ),
                        
                        suggestedAsync.when(
                          data: (videos) => Column(children: videos.map((v) => SuggestedVideoCard(video: v)).toList()),
                          loading: () => const SizedBox(height: 100, child: Center(child: CircularProgressIndicator())),
                          error: (e, s) => const SizedBox(),
                        ),
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}