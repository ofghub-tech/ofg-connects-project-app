// lib/presentation/pages/shorts_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import 'package:ofgconnects/logic/interaction_provider.dart';
import 'package:ofgconnects/logic/subscription_provider.dart';
import 'package:ofgconnects/logic/shorts_provider.dart'; 
import 'package:ofgconnects/models/video.dart';
import 'package:ofgconnects/presentation/widgets/shorts_player.dart';
import 'package:ofgconnects/presentation/widgets/comments_sheet.dart';

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

  void _animateToNextPage() {
    _pageController.nextPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
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
                allowImplicitScrolling: false, 
                physics: const ClampingScrollPhysics(),
                onPageChanged: (index) {
                  final int realIndex = index % state.items.length;
                  ref.read(activeShortsIndexProvider.notifier).state = realIndex;
                  ref.read(interactionProvider).logVideoView(state.items[realIndex].id);
                  
                  if (realIndex >= state.items.length - 2) {
                    ref.read(shortsListProvider.notifier).fetchMore();
                  }
                },
                itemBuilder: (context, index) {
                  final int realIndex = index % state.items.length;
                  final video = state.items[realIndex];

                  return _ShortsItem(
                    video: video, 
                    index: realIndex,
                    onNextPressed: _animateToNextPage,
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
  final VoidCallback onNextPressed;

  const _ShortsItem({required this.video, required this.index, required this.onNextPressed});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isSaved = ref.watch(isSavedProvider(video.id)).valueOrNull ?? false;
    final isFollowing = ref.watch(isFollowingProvider(video.creatorId)).valueOrNull ?? false;
    
    final double bottomOffset = MediaQuery.of(context).padding.bottom + 20;

    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              final currentState = ref.read(shortsPlayPauseProvider(video.id));
              ref.read(shortsPlayPauseProvider(video.id).notifier).state = !currentState;
            },
            child: ShortsPlayer(key: ValueKey(video.id), video: video, index: index),
          ),
        ),
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

        // ACTION BUTTONS (Removed Like Button)
        Positioned(
          right: 12,
          bottom: bottomOffset + 60, 
          child: Column(
            children: [
              _InteractionButton(icon: Icons.keyboard_arrow_down_rounded, label: "Next", onTap: onNextPressed, iconSize: 34),
              const SizedBox(height: 18),
              _InteractionButton(icon: Icons.chat_bubble_outline, label: "Comments", onTap: () => _showComments(context, video.id)),
              const SizedBox(height: 18),
              _InteractionButton(icon: Icons.share_outlined, label: "Share", onTap: () => Share.share("Watch: ${video.title}\nhttps://ofgconnects.com/shorts?id=${video.id}")),
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

        // INFO (Bottom Left)
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
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
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
                      isFollowing ? notifier.unfollowUser(video.creatorId) : notifier.followUser(creatorId: video.creatorId, creatorName: video.creatorName);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(video.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 14)),
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
        decoration: BoxDecoration(color: isFollowing ? Colors.white.withOpacity(0.2) : Colors.white, borderRadius: BorderRadius.circular(20)),
        child: Text(isFollowing ? "Following" : "Follow", style: TextStyle(color: isFollowing ? Colors.white : Colors.black, fontSize: 11, fontWeight: FontWeight.bold)),
      ),
    );
  }
}

class _InteractionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color color;
  final double iconSize;

  const _InteractionButton({required this.icon, required this.label, required this.onTap, this.color = Colors.white, this.iconSize = 28});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: const BoxDecoration(color: Colors.black26, shape: BoxShape.circle),
            child: Icon(icon, color: color, size: iconSize),
          ),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}