// lib/presentation/widgets/shorts_player.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ofgconnects_mobile/logic/interaction_provider.dart';
import 'package:ofgconnects_mobile/logic/shorts_provider.dart';
import 'package:ofgconnects_mobile/models/video.dart';
import 'package:video_player/video_player.dart';

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
  bool _isBuffering = false; // New state to track buffering

  @override
  void initState() {
    super.initState();
    _initializePlayer();
  }

  Future<void> _initializePlayer() async {
    try {
      final controller = VideoPlayerController.networkUrl(Uri.parse(widget.video.videoUrl));
      
      // Listen for buffering events
      controller.addListener(() {
        final isBuffering = controller.value.isBuffering;
        if (isBuffering != _isBuffering) {
           if (mounted) setState(() => _isBuffering = isBuffering);
        }
      });

      await controller.initialize();
      controller.setLooping(true);
      
      if (mounted) {
        setState(() {
          _controller = controller;
          _isInitialized = true;
        });
        
        if (ref.read(activeShortsIndexProvider) == widget.index) {
          controller.play();
        }
      }
    } catch (e) {
      print("Error loading short: $e");
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<int>(activeShortsIndexProvider, (prev, next) {
      if (next == widget.index) {
        _controller?.play();
      } else {
        _controller?.pause();
      }
    });

    return Stack(
      fit: StackFit.expand, // Ensure Stack takes full space
      children: [
        // 1. Video Layer (Full Screen)
        GestureDetector(
          onTap: () {
            if (_controller != null && _controller!.value.isInitialized) {
               _controller!.value.isPlaying ? _controller!.pause() : _controller!.play();
               setState(() {}); 
            }
          },
          child: Container(
            color: Colors.black,
            child: Center(
              child: _isInitialized
                  ? SizedBox.expand(
                      child: FittedBox(
                        // This makes it immersive like TikTok (fills screen)
                        // If you want to see the whole video without cropping, change to BoxFit.contain
                        fit: BoxFit.cover, 
                        child: SizedBox(
                          width: _controller!.value.size.width,
                          height: _controller!.value.size.height,
                          child: VideoPlayer(_controller!),
                        ),
                      ),
                    )
                  : const SizedBox(), // Show nothing while initializing (spinner is below)
            ),
          ),
        ),

        // 2. Buffering / Loading Indicator (Center)
        if (!_isInitialized || _isBuffering)
          const Center(
            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
          ),
          
        // 3. Play/Pause Icon (Transient feedback)
        if (_isInitialized && !_controller!.value.isPlaying && !_isBuffering)
          const Center(
            child: Icon(Icons.play_arrow, size: 60, color: Colors.white54),
          ),

        // 4. Gradient Overlay (Bottom)
        Positioned(
          bottom: 0, left: 0, right: 0,
          child: Container(
            height: 250, // Taller gradient for better readability
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.black.withOpacity(0.9), Colors.transparent],
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
              ),
            ),
          ),
        ),

        // 5. Right Side Actions
        Positioned(
          right: 8,
          bottom: 100, // Adjusted to not overlap with nav bar
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
               // Like Button (Connected to Logic)
               Consumer(
                builder: (context, ref, child) {
                   final isLikedAsync = ref.watch(isLikedProvider(widget.video.id));
                   final isLiked = isLikedAsync.value ?? false;
                   
                   return _buildActionButton(
                    icon: Icons.favorite,
                    label: '${widget.video.likeCount}',
                    color: isLiked ? Colors.red : Colors.white,
                    onTap: () => ref.read(interactionProvider).toggleLike(widget.video.id, widget.video.likeCount),
                  );
                },
               ),
              const SizedBox(height: 24),
              
              _buildActionButton(
                icon: Icons.comment_rounded,
                label: 'Comment',
                color: Colors.white,
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Comments coming soon!")));
                },
              ),
              const SizedBox(height: 24),
              
              _buildActionButton(
                icon: Icons.share_rounded,
                label: 'Share',
                color: Colors.white,
                onTap: () {},
              ),
              const SizedBox(height: 24),
              
               _buildActionButton(
                icon: Icons.more_horiz,
                label: 'More',
                color: Colors.white,
                onTap: () {},
              ),
            ],
          ),
        ),

        // 6. Bottom Info
        Positioned(
          bottom: 20,
          left: 16,
          right: 80, // Leave space for right buttons
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundImage: null, // You can add user image URL here
                    backgroundColor: Colors.grey[800],
                    child: Text(
                      widget.video.creatorName.isNotEmpty ? widget.video.creatorName[0].toUpperCase() : 'U',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    '@${widget.video.creatorName}',
                    style: const TextStyle(
                      color: Colors.white, 
                      fontWeight: FontWeight.w600, 
                      fontSize: 16,
                      shadows: [Shadow(color: Colors.black, blurRadius: 2)],
                    ),
                  ),
                  const SizedBox(width: 8),
                  
                  // Optional Follow Button
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.white54),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text("Follow", style: TextStyle(color: Colors.white, fontSize: 10)),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                widget.video.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white, 
                  fontSize: 14,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton({required IconData icon, required String label, required Color color, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1), // Glassmorphism background
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 32),
          ),
          const SizedBox(height: 6),
          Text(
            label, 
            style: const TextStyle(
              color: Colors.white, 
              fontSize: 12, 
              fontWeight: FontWeight.w600,
              shadows: [Shadow(color: Colors.black, blurRadius: 2)]
            )
          ),
        ],
      ),
    );
  }
}