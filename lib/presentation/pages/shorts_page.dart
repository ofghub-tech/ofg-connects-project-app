// lib/presentation/pages/shorts_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';

import 'package:ofgconnects_mobile/logic/interaction_provider.dart';
import 'package:ofgconnects_mobile/logic/subscription_provider.dart';
import 'package:ofgconnects_mobile/logic/shorts_provider.dart'; 
import 'package:ofgconnects_mobile/models/video.dart';
import 'package:ofgconnects_mobile/presentation/widgets/shorts_player.dart';
import 'package:ofgconnects_mobile/presentation/widgets/comments_sheet.dart';

// Provider to track manual play/pause state per video
final shortsPlayPauseProvider = StateProvider.family<bool, String>((ref, id) => true);

class ShortsPage extends ConsumerStatefulWidget {
  final String? videoId;
  const ShortsPage({super.key, this.videoId});

  @override
  ConsumerState<ShortsPage> createState() => _ShortsPageState();
}

class _ShortsPageState extends ConsumerState<ShortsPage> {
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(shortsListProvider.notifier).init(widget.videoId);
      ref.read(activeShortsIndexProvider.notifier).state = 0;
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(shortsListProvider);

    return PopScope(
      canPop: context.canPop(), 
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        context.go('/home'); 
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        extendBodyBehindAppBar: true, 
        body: state.items.isEmpty
            ? (state.isLoadingMore
                ? const Center(child: CircularProgressIndicator(color: Colors.white))
                : const Center(child: Text("No Shorts Available", style: TextStyle(color: Colors.white))))
            : PageView.builder(
                controller: _pageController,
                scrollDirection: Axis.vertical,
                // OPTIMIZATION: Renders the previous/next video in memory for faster swipes
                allowImplicitScrolling: true, 
                physics: const AlwaysScrollableScrollPhysics(),
                itemCount: state.items.length,
                onPageChanged: (index) {
                  ref.read(activeShortsIndexProvider.notifier).state = index;
                  if (index >= state.items.length - 2) {
                    ref.read(shortsListProvider.notifier).fetchMore();
                  }
                  ref.read(interactionProvider).logVideoView(state.items[index].id);
                },
                itemBuilder: (context, index) {
                  return _ShortsItem(
                    video: state.items[index], 
                    index: index,
                  );
                },
              ),
      ),
    );
  }
}

class _ShortsItem extends ConsumerWidget {
  final Video video;
  final int index;

  const _ShortsItem({required this.video, required this.index});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLiked = ref.watch(isLikedProvider(video.id)).valueOrNull ?? false;
    final isSaved = ref.watch(isSavedProvider(video.id)).valueOrNull ?? false;
    final isFollowing = ref.watch(isFollowingProvider(video.creatorId)).valueOrNull ?? false;

    final double bottomOffset = MediaQuery.of(context).padding.bottom + 20;

    return Stack(
      children: [
        // VIDEO LAYER
        Positioned.fill(
          child: GestureDetector(
            onTap: () {
              // Handle Play/Pause here because ShortsPlayer ignores pointers
              final currentState = ref.read(shortsPlayPauseProvider(video.id));
              ref.read(shortsPlayPauseProvider(video.id).notifier).state = !currentState;
            },
            child: ShortsPlayer(video: video, index: index),
          ),
        ),

        // GRADIENT LAYER (Visuals only, ignores touches)
        Positioned.fill(
          child: IgnorePointer(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.black.withOpacity(0.2), Colors.transparent, Colors.black.withOpacity(0.8)],
                ),
              ),
            ),
          ),
        ),

        // RIGHT ACTION BUTTONS
        Positioned(
          right: 12,
          bottom: bottomOffset + 60, 
          child: Column(
            children: [
              _InteractionButton(
                icon: isLiked ? Icons.favorite : Icons.favorite_border,
                label: NumberFormat.compact().format(video.likeCount),
                color: isLiked ? Colors.red : Colors.white,
                onTap: () => ref.read(isLikedProvider(video.id).notifier).toggle(),
              ),
              const SizedBox(height: 18),
              _InteractionButton(
                icon: Icons.chat_bubble_outline,
                label: "Comments",
                onTap: () => _showComments(context, video.id),
              ),
              const SizedBox(height: 18),
              _InteractionButton(
                icon: Icons.share_outlined,
                label: "Share",
                onTap: () => Share.share("Watch: ${video.title}\nhttps://ofgconnects.com/shorts?id=${video.id}"),
              ),
              const SizedBox(height: 18),
              _InteractionButton(
                icon: isSaved ? Icons.bookmark : Icons.bookmark_outline,
                label: isSaved ? "Saved" : "Save",
                color: isSaved ? Colors.blueAccent : Colors.white,
                onTap: () => ref.read(isSavedProvider(video.id).notifier).toggle(),
              ),
            ],
          ),
        ),

        // BOTTOM LEFT INFO
        Positioned(
          left: 16,
          right: 80,
          bottom: bottomOffset, 
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: Colors.blueAccent,
                    child: Text(
                      video.creatorName.isNotEmpty ? video.creatorName[0].toUpperCase() : '?', 
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      video.creatorName,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 10),
                  _FollowButton(
                    isFollowing: isFollowing,
                    onTap: () {
                      final notifier = ref.read(subscriptionNotifierProvider.notifier);
                      isFollowing 
                        ? notifier.unfollowUser(video.creatorId)
                        : notifier.followUser(creatorId: video.creatorId, creatorName: video.creatorName);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                video.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white, fontSize: 14),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showComments(BuildContext context, String videoId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.65,
        maxChildSize: 0.9,
        builder: (_, controller) => CommentsSheet(videoId: videoId, scrollController: controller),
      ),
    );
  }
}

class _FollowButton extends StatelessWidget {
  final bool isFollowing;
  final VoidCallback onTap;
  const _FollowButton({required this.isFollowing, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: isFollowing ? Colors.white.withOpacity(0.2) : Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          isFollowing ? "Following" : "Follow",
          style: TextStyle(color: isFollowing ? Colors.white : Colors.black, fontSize: 11, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}

class _InteractionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color color;

  const _InteractionButton({required this.icon, required this.label, required this.onTap, this.color = Colors.white});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: const BoxDecoration(color: Colors.black26, shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}