import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart'; 
import 'package:ofgconnects_mobile/logic/interaction_provider.dart';
import 'package:ofgconnects_mobile/logic/shorts_provider.dart';
import 'package:ofgconnects_mobile/models/video.dart';
import 'package:video_player/video_player.dart';
import 'package:ofgconnects_mobile/presentation/widgets/comments_sheet.dart';
// REMOVED: guest_login_dialog import

class BouncyLikeButton extends StatefulWidget {
  final bool isLiked;
  final VoidCallback onTap;
  const BouncyLikeButton({super.key, required this.isLiked, required this.onTap});
  @override
  State<BouncyLikeButton> createState() => _BouncyLikeButtonState();
}

class _BouncyLikeButtonState extends State<BouncyLikeButton> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scale;
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 150));
    _scale = Tween<double>(begin: 1.0, end: 1.3).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }
  @override
  void didUpdateWidget(covariant BouncyLikeButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isLiked && !oldWidget.isLiked) { _controller.forward().then((_) => _controller.reverse()); }
  }
  @override
  void dispose() { _controller.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: ScaleTransition(
        scale: _scale,
        child: Icon(widget.isLiked ? Icons.favorite : Icons.favorite_border, color: widget.isLiked ? const Color(0xFFFF2C55) : Colors.white, size: 35, shadows: const [Shadow(color: Colors.black38, blurRadius: 8)]),
      ),
    );
  }
}

class ShortsPlayer extends ConsumerStatefulWidget {
  final Video video;
  final int index;
  const ShortsPlayer({super.key, required this.video, required this.index});
  @override
  ConsumerState<ShortsPlayer> createState() => _ShortsPlayerState();
}

class _ShortsPlayerState extends ConsumerState<ShortsPlayer> {
  VideoPlayerController? _controller;
  bool _isInitialized = false;
  bool _isBuffering = true;
  bool _hasLoggedView = false;
  late int _localLikeCount;
  bool? _localIsLiked;

  @override
  void initState() {
    super.initState();
    _localLikeCount = widget.video.likeCount;
    _initializePlayer();
  }

  Future<void> _initializePlayer() async {
    try {
      final controller = VideoPlayerController.networkUrl(
        Uri.parse(widget.video.videoUrl),
        videoPlayerOptions: VideoPlayerOptions(mixWithOthers: false),
      );
      controller.addListener(() {
        if (!mounted) return;
        final isBuffering = controller.value.isBuffering;
        if (isBuffering != _isBuffering) setState(() => _isBuffering = isBuffering);
      });
      await controller.initialize();
      controller.setLooping(true);
      if (mounted) {
        setState(() { _controller = controller; _isInitialized = true; _isBuffering = false; });
        if (ref.read(activeShortsIndexProvider) == widget.index) _playAndLog();
      }
    } catch (e) {
      print("Error loading short: $e");
      if(mounted) setState(() => _isBuffering = false);
    }
  }

  void _playAndLog() {
    if (_controller == null || !_controller!.value.isInitialized) return;
    _controller!.play();
    if (!_hasLoggedView) {
      _hasLoggedView = true;
      ref.read(interactionProvider).logVideoView(widget.video.id);
    }
  }

  void _toggleLike() async {
    // REMOVED GUEST CHECK
    final isLikedAsync = ref.read(isLikedProvider(widget.video.id));
    final currentStatus = _localIsLiked ?? isLikedAsync.value ?? false;
    setState(() {
      _localIsLiked = !currentStatus;
      _localLikeCount += _localIsLiked! ? 1 : -1;
    });
    try {
      await ref.read(interactionProvider).toggleLike(widget.video.id);
    } catch (e) {
      setState(() {
        _localIsLiked = currentStatus;
        _localLikeCount -= _localIsLiked! ? 1 : -1;
      });
    }
  }

  void _toggleSave() async {
    // REMOVED GUEST CHECK
    await ref.read(interactionProvider).toggleWatchLater(widget.video.id);
    ref.invalidate(isSavedProvider(widget.video.id));
  }

  void _showComments(BuildContext context) async {
    // REMOVED GUEST CHECK
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent, 
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        builder: (_, controller) => CommentsSheet(videoId: widget.video.id, scrollController: controller),
      ),
    );
  }

  @override
  void dispose() { _controller?.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    ref.listen<int>(activeShortsIndexProvider, (prev, next) {
      if (next == widget.index) _playAndLog();
      else _controller?.pause();
    });

    return Stack(
      fit: StackFit.expand,
      children: [
        GestureDetector(
          onTap: () {
            if (_controller != null && _controller!.value.isInitialized) {
               if (_controller!.value.isPlaying) _controller!.pause();
               else _playAndLog();
               setState(() {}); 
            }
          },
          child: Container(
            color: Colors.black,
            child: Center(
              child: _isInitialized
                  ? SizedBox.expand(
                      child: FittedBox(
                        fit: BoxFit.cover, 
                        child: SizedBox(
                          width: _controller!.value.size.width,
                          height: _controller!.value.size.height,
                          child: VideoPlayer(_controller!),
                        ),
                      ),
                    )
                  : const SizedBox(), 
            ),
          ),
        ),
        if (!_isInitialized || _isBuffering)
          const Center(child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3)),
        if (_isInitialized && !_controller!.value.isPlaying && !_isBuffering)
          Center(child: IgnorePointer(child: Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.black45, borderRadius: BorderRadius.circular(50)), child: const Icon(Icons.play_arrow, size: 48, color: Colors.white)))),
          
        _buildGradientOverlay(),
        _buildRightSideActions(context),
        _buildBottomInfo(),
      ],
    );
  }

  Widget _buildGradientOverlay() {
    return Positioned(
      bottom: 0, left: 0, right: 0,
      child: IgnorePointer(
        child: Container(
          height: 300,
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [Colors.black.withOpacity(0.9), Colors.transparent], begin: Alignment.bottomCenter, end: Alignment.topCenter),
          ),
        ),
      ),
    );
  }

  Widget _buildRightSideActions(BuildContext context) {
    return Positioned(
      right: 8,
      bottom: 150, 
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
            Consumer(builder: (context, ref, child) {
                final isLikedAsync = ref.watch(isLikedProvider(widget.video.id));
                final isLiked = _localIsLiked ?? isLikedAsync.value ?? false;
                return Column(
                  children: [
                    BouncyLikeButton(isLiked: isLiked, onTap: _toggleLike),
                    const SizedBox(height: 2),
                    Text('$_localLikeCount', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13, shadows: [Shadow(color: Colors.black38, blurRadius: 4)])),
                  ],
                );
            }),
          const SizedBox(height: 20),
          _buildShadowWrapper(child: _buildActionButton(icon: Icons.comment_rounded, label: 'Comment', onTap: () => _showComments(context))),
          const SizedBox(height: 20),
          _buildShadowWrapper(child: Consumer(builder: (context, ref, child) {
              final isSavedAsync = ref.watch(isSavedProvider(widget.video.id));
              final isSaved = isSavedAsync.value ?? false;
              return _buildActionButton(icon: isSaved ? Icons.bookmark : Icons.bookmark_border, label: 'Save', iconColor: isSaved ? Colors.blueAccent : Colors.white, onTap: _toggleSave);
          })),
          const SizedBox(height: 20),
          _buildShadowWrapper(child: _buildActionButton(icon: Icons.share_rounded, label: 'Share', onTap: () {})),
        ],
      ),
    );
  }

  Widget _buildBottomInfo() {
    return Positioned(
      bottom: 110, 
      left: 16, 
      right: 80,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () => context.push('/profile/${widget.video.creatorId}?name=${Uri.encodeComponent(widget.video.creatorName)}'),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 1.5)),
                  child: CircleAvatar(radius: 16, backgroundColor: Colors.grey[800], child: Text(widget.video.creatorName.isNotEmpty ? widget.video.creatorName[0].toUpperCase() : 'U', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white))),
                ),
                const SizedBox(width: 10),
                Text('@${widget.video.creatorName}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15, shadows: [Shadow(color: Colors.black, blurRadius: 4)])),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Text(widget.video.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 14, shadows: [Shadow(color: Colors.black, blurRadius: 4)])),
        ],
      ),
    );
  }

  Widget _buildShadowWrapper({required Widget child}) {
    return Container(decoration: const BoxDecoration(shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 8, spreadRadius: 1)]), child: child);
  }

  Widget _buildActionButton({required IconData icon, required String label, required VoidCallback onTap, Color iconColor = Colors.white}) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Icon(icon, color: iconColor, size: 30),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold, shadows: [Shadow(color: Colors.black, blurRadius: 4)])),
        ],
      ),
    );
  }
}