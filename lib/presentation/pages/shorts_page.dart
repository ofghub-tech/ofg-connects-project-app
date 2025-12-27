import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';

import 'package:ofgconnects_mobile/logic/video_provider.dart';
import 'package:ofgconnects_mobile/logic/interaction_provider.dart';
import 'package:ofgconnects_mobile/logic/subscription_provider.dart';
import 'package:ofgconnects_mobile/logic/shorts_provider.dart'; // Ensure this is imported for activeShortsIndexProvider
import 'package:ofgconnects_mobile/models/video.dart';
import 'package:ofgconnects_mobile/presentation/widgets/shorts_player.dart';
import 'package:ofgconnects_mobile/presentation/widgets/comments_sheet.dart';

class ShortsPage extends ConsumerStatefulWidget {
  final String? videoId;
  const ShortsPage({super.key, this.videoId});

  @override
  ConsumerState<ShortsPage> createState() => _ShortsPageState();
}

class _ShortsPageState extends ConsumerState<ShortsPage> {
  final PageController _pageController = PageController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(shortsListProvider.notifier).init(widget.videoId);
      // Reset index to 0 on entry
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

    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text("Shorts", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.camera_alt_outlined),
            onPressed: () => context.push('/upload'),
          ),
        ],
      ),
      body: state.items.isEmpty
          ? (state.isLoadingMore
              ? const Center(child: CircularProgressIndicator())
              : const Center(child: Text("No Shorts Available", style: TextStyle(color: Colors.white))))
          : PageView.builder(
              controller: _pageController,
              scrollDirection: Axis.vertical,
              itemCount: state.items.length,
              onPageChanged: (index) {
                // 1. Update the Active Index Provider
                ref.read(activeShortsIndexProvider.notifier).state = index;

                // 2. Load more data if needed
                if (index >= state.items.length - 2) {
                  ref.read(shortsListProvider.notifier).fetchMore();
                }
                
                // 3. Log View
                ref.read(interactionProvider).logVideoView(state.items[index].id);
              },
              itemBuilder: (context, index) {
                return _ShortsItem(
                  video: state.items[index], 
                  index: index, // Pass index here
                );
              },
            ),
    );
  }
}

class _ShortsItem extends ConsumerWidget {
  final Video video;
  final int index;

  const _ShortsItem({required this.video, required this.index});

  void _showComments(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        minChildSize: 0.4,
        builder: (_, controller) => CommentsSheet(videoId: video.id, scrollController: controller),
      ),
    );
  }

  void _shareVideo() {
    Share.share("Watch this short: ${video.title}\nhttps://ofgconnects.com/shorts?id=${video.id}");
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLikedAsync = ref.watch(isLikedProvider(video.id));
    final isSavedAsync = ref.watch(isSavedProvider(video.id));
    final isFollowingAsync = ref.watch(isFollowingProvider(video.creatorId));

    return Stack(
      children: [
        // 1. VIDEO PLAYER
        Positioned.fill(
          child: ShortsPlayer(
            video: video, // Correct parameter
            index: index, // Correct parameter
          ),
        ),

        // 2. GRADIENT OVERLAY
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.transparent,
                  Colors.black.withOpacity(0.6),
                ],
                stops: const [0.0, 0.6, 1.0],
              ),
            ),
          ),
        ),

        // 3. RIGHT SIDE BUTTONS
        Positioned(
          right: 16,
          bottom: 100,
          child: Column(
            children: [
              _InteractionButton(
                icon: isLikedAsync.valueOrNull == true ? Icons.favorite : Icons.favorite_border,
                label: NumberFormat.compact().format(video.likeCount),
                color: isLikedAsync.valueOrNull == true ? Colors.red : Colors.white,
                onTap: () => ref.read(isLikedProvider(video.id).notifier).toggle(),
              ),
              const SizedBox(height: 20),
              _InteractionButton(
                icon: Icons.comment,
                label: "Comment",
                onTap: () => _showComments(context),
              ),
              const SizedBox(height: 20),
              _InteractionButton(
                icon: Icons.share,
                label: "Share",
                onTap: _shareVideo,
              ),
              const SizedBox(height: 20),
              _InteractionButton(
                icon: isSavedAsync.valueOrNull == true ? Icons.bookmark : Icons.bookmark_outline,
                label: "Save",
                color: isSavedAsync.valueOrNull == true ? Colors.blue : Colors.white,
                onTap: () => ref.read(isSavedProvider(video.id).notifier).toggle(),
              ),
            ],
          ),
        ),

        // 4. BOTTOM INFO
        Positioned(
          left: 16,
          right: 80,
          bottom: 24,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  GestureDetector(
                    onTap: () => context.push('/profile/${video.creatorId}'),
                    child: CircleAvatar(
                      radius: 18,
                      backgroundColor: Colors.white24,
                      child: Text(video.creatorName.isNotEmpty ? video.creatorName[0].toUpperCase() : "?", style: const TextStyle(color: Colors.white)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  GestureDetector(
                    onTap: () => context.push('/profile/${video.creatorId}'),
                    child: Text(
                      video.creatorName,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ),
                  const SizedBox(width: 10),
                  if (isFollowingAsync.valueOrNull == false)
                    GestureDetector(
                      onTap: () => ref.read(subscriptionNotifierProvider.notifier).followUser(creatorId: video.creatorId, creatorName: video.creatorName),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.white),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text("Subscribe", style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),
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
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.4),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 30),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600, shadows: [Shadow(blurRadius: 2, color: Colors.black)]),
          ),
        ],
      ),
    );
  }
}