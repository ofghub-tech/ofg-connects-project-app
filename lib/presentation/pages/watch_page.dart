// lib/presentation/pages/watch_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';       
import 'package:media_kit_video/media_kit_video.dart'; 
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart'; // Ensure this is in pubspec.yaml

import 'package:ofgconnects_mobile/api/appwrite_client.dart';
import 'package:ofgconnects_mobile/logic/auth_provider.dart';
import 'package:ofgconnects_mobile/logic/video_provider.dart';
import 'package:ofgconnects_mobile/logic/interaction_provider.dart'; //
import 'package:ofgconnects_mobile/logic/subscription_provider.dart'; //
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
  String _currentQualityLabel = "Auto";
  bool _isDescriptionExpanded = false;

  @override
  void initState() {
    super.initState();
    _player = Player();
    _controller = VideoController(_player);
    
    // Log view using the actual interaction logic
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(interactionProvider).logVideoView(widget.videoId);
    });
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  // Implementation for quality and initialization remains similar but uses the video model
  Future<void> _initializePlayer(model.Video video, {String? specificUrl}) async {
    if (_isPlayerInitialized && specificUrl == null) return;
    try {
      String playUrl = specificUrl ?? (video.compressionStatus == 'Done' ? (video.url720p ?? video.videoUrl) : video.videoUrl);
      
      // Handle Appwrite storage IDs
      String finalUrl = playUrl;
      if (!finalUrl.startsWith('http')) {
        finalUrl = AppwriteClient.storage.getFileView(
          bucketId: AppwriteClient.bucketIdVideos,
          fileId: playUrl,
        ).toString();
      }
      
      await _player.open(Media(finalUrl));
      if (mounted) setState(() => _isPlayerInitialized = true);
    } catch (e) {
      debugPrint("Player Init Error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final videoAsync = ref.watch(videoDetailsProvider(widget.videoId));
    final suggestedAsync = ref.watch(suggestedVideosProvider(widget.videoId));

    // --- FUNCTIONAL STATE WATCHERS ---
    final isLiked = ref.watch(isLikedProvider(widget.videoId)).value ?? false; //
    final isSaved = ref.watch(isSavedProvider(widget.videoId)).value ?? false; //

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      body: SafeArea(
        child: videoAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, _) => Center(child: Text("Error: $err", style: const TextStyle(color: Colors.white))),
          data: (video) {
            if (!_isPlayerInitialized) {
              Future.microtask(() => _initializePlayer(video));
            }

            // Watch subscription status
            final isFollowing = ref.watch(isFollowingProvider(video.creatorId)).value ?? false;

            return Column(
              children: [
                // 1. Video Player
                AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Container(
                    color: Colors.black,
                    child: _isPlayerInitialized 
                        ? Video(controller: _controller, controls: MaterialVideoControls)
                        : const Center(child: CircularProgressIndicator()),
                  ),
                ),

                // 2. Content Section
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildTitleSection(video),
                        
                        // --- ACTION BUTTONS (FUNCTIONAL) ---
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                          child: Row(
                            children: [
                              // Like Button
                              _buildActionButton(
                                isLiked ? Icons.thumb_up : Icons.thumb_up_outlined, 
                                NumberFormat.compact().format(video.likeCount), 
                                () => ref.read(isLikedProvider(widget.videoId).notifier).toggle(),
                                isActive: isLiked
                              ),
                              const SizedBox(width: 8),
                              // Share Button
                              _buildActionButton(Icons.share_outlined, "Share", () {
                                Share.share("Check out this video: ${video.title} \n ${video.videoUrl}");
                              }),
                              const SizedBox(width: 8),
                              // Save (Watch Later) Button
                              _buildActionButton(
                                isSaved ? Icons.bookmark : Icons.bookmark_outline, 
                                isSaved ? "Saved" : "Save", 
                                () => ref.read(isSavedProvider(widget.videoId).notifier).toggle(),
                                isActive: isSaved
                              ),
                            ],
                          ),
                        ),

                        const Divider(color: Colors.white10),

                        // --- CREATOR / CHANNEL SECTION (FUNCTIONAL) ---
                        _buildChannelRow(video, isFollowing),

                        const Divider(color: Colors.white10),

                        // Comments Section
                        _buildCommentsSection(video),
                        
                        const Divider(color: Colors.white10),

                        // Suggestions
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                          child: Text("Up Next", style: Theme.of(context).textTheme.titleSmall?.copyWith(color: Colors.white)),
                        ),
                        suggestedAsync.when(
                          data: (videos) => Column(children: videos.map((v) => SuggestedVideoCard(video: v)).toList()),
                          loading: () => const Center(child: CircularProgressIndicator()),
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

  Widget _buildTitleSection(model.Video video) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(video.title, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Text(
            "${NumberFormat.compact().format(video.viewCount)} views • ${DateFormat.yMMMd().format(video.createdAt)}",
            style: const TextStyle(color: Colors.grey, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildChannelRow(model.Video video, bool isFollowing) {
    return ListTile(
      leading: CircleAvatar(backgroundColor: Colors.blueAccent, child: Text(video.creatorName[0])),
      title: Text(video.creatorName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      trailing: TextButton(
        onPressed: () {
          final subNotifier = ref.read(subscriptionNotifierProvider.notifier); //
          if (isFollowing) {
            subNotifier.unfollowUser(video.creatorId);
          } else {
            subNotifier.followUser(creatorId: video.creatorId, creatorName: video.creatorName);
          }
        },
        style: TextButton.styleFrom(
          backgroundColor: isFollowing ? Colors.white10 : Colors.blueAccent,
          foregroundColor: isFollowing ? Colors.white70 : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        ),
        child: Text(isFollowing ? "Following" : "Follow"),
      ),
    );
  }

  Widget _buildCommentsSection(model.Video video) {
    return ListTile(
      onTap: () => showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => DraggableScrollableSheet(
          initialChildSize: 0.75,
          maxChildSize: 0.9,
          builder: (_, controller) => CommentsSheet(videoId: video.id, scrollController: controller),
        ),
      ),
      title: const Text("Comments", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      trailing: const Icon(Icons.keyboard_arrow_down, color: Colors.white),
    );
  }

  Widget _buildActionButton(IconData icon, String label, VoidCallback onTap, {bool isActive = false}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? Colors.white.withOpacity(0.2) : Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20, color: isActive ? Colors.blueAccent : Colors.white),
            const SizedBox(width: 8),
            Text(label, style: const TextStyle(color: Colors.white, fontSize: 13)),
          ],
        ),
      ),
    );
  }
}