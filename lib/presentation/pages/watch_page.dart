// lib/presentation/pages/watch_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ofgconnects_mobile/logic/auth_provider.dart';
import 'package:ofgconnects_mobile/logic/comments_provider.dart'; // Import comments provider
import 'package:ofgconnects_mobile/logic/interaction_provider.dart';
import 'package:ofgconnects_mobile/logic/video_provider.dart';
import 'package:ofgconnects_mobile/models/video.dart';
import 'package:ofgconnects_mobile/presentation/widgets/suggested_video_card.dart';
import 'package:ofgconnects_mobile/logic/subscription_provider.dart';
import 'package:video_player/video_player.dart';
import 'package:appwrite/models.dart' as models; // To avoid conflict with Video model if needed

class WatchPage extends ConsumerStatefulWidget {
  final String videoId; 

  const WatchPage({super.key, required this.videoId});

  @override
  ConsumerState<WatchPage> createState() => _WatchPageState();
}

class _WatchPageState extends ConsumerState<WatchPage> {
  VideoPlayerController? _controller;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initializePage();
  }

  @override
  void didUpdateWidget(WatchPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.videoId != widget.videoId) {
      _disposePlayer(); 
      setState(() {
        _isLoading = true; 
        _errorMessage = null;
      });
      _initializePage(); 
    }
  }

  Future<void> _initializePage() async {
    try {
      final video = await ref.read(videoDetailsProvider(widget.videoId).future);
      
      if (video == null) {
        if (mounted) setState(() => _errorMessage = "Video not found");
        return;
      }
      
      if (video.videoUrl.isEmpty) {
         if (mounted) setState(() => _errorMessage = "Video URL is invalid");
         return;
      }

      _controller = VideoPlayerController.networkUrl(Uri.parse(video.videoUrl));
      await _controller!.initialize();
      
      _controller!.play();
      
      // Log history in background
      _recordHistory(video);

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      print("Error initializing player: $e");
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = "Error loading video: $e";
        });
      }
    }
  }

  Future<void> _recordHistory(Video video) async {
    final user = ref.read(authProvider).user;
    if (user == null) return;

    try {
      await ref.read(interactionProvider).logVideoView(video.id, video.viewCount);
    } catch (e) {
      print('Error recording history: $e');
    }
  }

  void _disposePlayer() {
    _controller?.dispose();
    _controller = null;
  }

  @override
  void dispose() {
    _disposePlayer();
    super.dispose();
  }

  void _showComments(BuildContext context, String videoId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // Allows the sheet to be taller
      backgroundColor: Colors.grey[900],
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) {
          return CommentsSheet(videoId: videoId, scrollController: scrollController);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final videoAsync = ref.watch(videoDetailsProvider(widget.videoId));

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // --- VIDEO PLAYER ---
            AspectRatio(
              aspectRatio: 16 / 9,
              child: Container(
                color: Colors.black,
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _errorMessage != null
                        ? Center(child: Text(_errorMessage!, style: const TextStyle(color: Colors.white)))
                        : GestureDetector(
                            onTap: () {
                              setState(() {
                                _controller!.value.isPlaying
                                    ? _controller!.pause()
                                    : _controller!.play();
                              });
                            },
                            child: Stack(
                              alignment: Alignment.bottomCenter,
                              children: [
                                VideoPlayer(_controller!),
                                if (!_controller!.value.isPlaying)
                                  const Center(
                                    child: Icon(Icons.play_circle_outline, size: 64, color: Colors.white54),
                                  ),
                                VideoProgressIndicator(_controller!, allowScrubbing: true),
                              ],
                            ),
                          ),
              ),
            ),

            // --- DETAILS ---
            Expanded(
              child: videoAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, stack) => Center(child: Text('Error: $err', style: const TextStyle(color: Colors.white))),
                data: (video) {
                  if (video == null) return const SizedBox.shrink();
                  return ListView(
                    padding: const EdgeInsets.all(12),
                    children: [
                      Text(
                        video.title,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      const SizedBox(height: 8),

                      Text(
                        '${video.viewCount} views • ${video.likeCount} likes',
                        style: const TextStyle(color: Colors.grey, fontSize: 14),
                      ),
                      const SizedBox(height: 16),

                      _buildCreatorInfo(context, video),
                      
                      // Pass the videoId to the action buttons to open comments
                      _buildActionButtons(context, video),
                      
                      const SizedBox(height: 16),
                      const Divider(color: Colors.grey),
                      const Text("Suggested Videos", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                      const SizedBox(height: 8),
                      
                      Consumer(
                        builder: (context, ref, child) {
                          final suggestedAsync = ref.watch(suggestedVideosProvider(widget.videoId));
                          return suggestedAsync.when(
                            loading: () => const SizedBox(height: 100, child: Center(child: CircularProgressIndicator())),
                            error: (e, s) => const Text("Failed to load suggestions", style: TextStyle(color: Colors.white)),
                            data: (videos) {
                              return Column(
                                children: videos.map<Widget>((v) => SuggestedVideoCard(
                                  video: v,
                                )).toList(),
                              );
                            },
                          );
                        },
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildCreatorInfo(BuildContext context, Video video) {
    final isFollowingAsync = ref.watch(isFollowingProvider(video.creatorId));

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            CircleAvatar(
              child: Text(video.creatorName.isNotEmpty ? video.creatorName[0] : 'U'),
            ),
            const SizedBox(width: 12.0),
            Text(
              video.creatorName,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.white),
            ),
          ],
        ),

        isFollowingAsync.when(
          data: (isFollowing) {
            return ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: isFollowing ? Colors.grey[800] : Colors.red,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                final notifier = ref.read(subscriptionNotifierProvider.notifier);
                if (isFollowing) {
                  notifier.unfollowUser(video.creatorId);
                } else {
                  notifier.followUser(video);
                }
              },
              child: Text(isFollowing ? 'Following' : 'Follow'),
            );
          },
          loading: () => const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)),
          error: (e, s) => const Icon(Icons.error, color: Colors.red),
        ),
      ],
    );
  }

  Widget _buildActionButtons(BuildContext context, Video video) {
    final isLikedAsync = ref.watch(isLikedProvider(video.id));
    final isSavedAsync = ref.watch(interactionProvider).isVideoSaved(video.id);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          isLikedAsync.when(
            data: (isLiked) {
              return TextButton.icon(
                style: TextButton.styleFrom(foregroundColor: Colors.white),
                onPressed: () {
                  ref.read(interactionProvider).toggleLike(video.id, video.likeCount);
                },
                icon: Icon(
                  isLiked ? Icons.thumb_up : Icons.thumb_up_outlined,
                  color: isLiked ? Colors.blue : Colors.white,
                ),
                label: const Text('Like'),
              );
            },
            loading: () => const Padding(padding: EdgeInsets.all(8.0), child: CircularProgressIndicator(strokeWidth: 2)),
            error: (e, s) => const Icon(Icons.error, color: Colors.red),
          ),
          
          TextButton.icon(
            style: TextButton.styleFrom(foregroundColor: Colors.white),
            onPressed: () => _showComments(context, video.id),
            icon: const Icon(Icons.comment_outlined, color: Colors.white),
            label: const Text('Comment'),
          ),

          const SizedBox(width: 8),

          FutureBuilder<bool>(
            future: isSavedAsync,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Padding(padding: EdgeInsets.all(8.0), child: CircularProgressIndicator(strokeWidth: 2));
              }
              final isSaved = snapshot.data ?? false;
              return TextButton.icon(
                style: TextButton.styleFrom(foregroundColor: Colors.white),
                onPressed: () async {
                  await ref.read(interactionProvider).toggleWatchLater(video.id);
                  setState(() {}); 
                },
                icon: Icon(
                  isSaved ? Icons.bookmark_added : Icons.bookmark_add_outlined,
                  color: isSaved ? Colors.blue : Colors.white,
                ),
                label: const Text('Save'),
              );
            },
          ),
        ],
      ),
    );
  }
}

// We'll store the comment we're replying to in a simple StateProvider
final replyingToCommentProvider = StateProvider<models.Document?>((ref) => null);

class CommentsSheet extends ConsumerStatefulWidget {
  final String videoId;
  final ScrollController scrollController;

  const CommentsSheet({
    super.key,
    required this.videoId,
    required this.scrollController,
  });

  @override
  ConsumerState<CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends ConsumerState<CommentsSheet> {
  final TextEditingController _commentController = TextEditingController();
  bool _isPosting = false;

  @override
  void initState() {
    super.initState();
    // Clear the reply state when the sheet opens
    Future.microtask(() {
      ref.read(replyingToCommentProvider.notifier).state = null;
      ref.read(commentsProvider.notifier).loadComments(widget.videoId);
    });
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _postComment() async {
    if (_commentController.text.trim().isEmpty) return;
    
    // Get the comment we are replying to (if any)
    final replyingTo = ref.read(replyingToCommentProvider);

    setState(() => _isPosting = true);
    try {
      await ref.read(commentsProvider.notifier).postComment(
        videoId: widget.videoId,
        content: _commentController.text.trim(),
        parentId: replyingTo?.$id, // Pass the parentId
      );
      _commentController.clear();
      // Clear the reply state
      ref.read(replyingToCommentProvider.notifier).state = null;
      // Dismiss keyboard
      FocusManager.instance.primaryFocus?.unfocus();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to post: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isPosting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // --- THIS WAS THE FIX ---
    final commentsAsync = ref.watch(commentsProvider);
    // ------------------------
    // Watch the reply state to show UI feedback
    final replyingTo = ref.watch(replyingToCommentProvider);

    return Column(
      children: [
        // Handle bar
        const SizedBox(height: 12),
        Container(
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: Colors.grey[600],
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const Padding(
          padding: EdgeInsets.all(16.0),
          child: Text("Comments", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        ),
        
        // Comments List
        Expanded(
          child: commentsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, s) => Center(child: Text('Error loading comments: $e', style: const TextStyle(color: Colors.white))),
            data: (comments) {
              if (comments.isEmpty) {
                return const Center(child: Text('No comments yet. Be the first!', style: TextStyle(color: Colors.grey)));
              }
              return ListView.builder(
                controller: widget.scrollController,
                itemCount: comments.length,
                itemBuilder: (context, index) {
                  final comment = comments[index];
                  // Use our new CommentTile widget
                  return CommentTile(comment: comment);
                },
              );
            },
          ),
        ),

        // Input Field
        Container(
          padding: EdgeInsets.only(
            left: 16, 
            right: 16, 
            top: 8, // Reduced padding
            bottom: MediaQuery.of(context).viewInsets.bottom + 16
          ),
          decoration: const BoxDecoration(
            color: Colors.black,
            border: Border(top: BorderSide(color: Colors.grey)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Show "Replying to..." if we are replying
              if (replyingTo != null)
                Row(
                  children: [
                    Text(
                      'Replying to ${replyingTo.data['username'] ?? 'Unknown'}',
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                    const Spacer(),
                    IconButton(
                      iconSize: 16,
                      icon: const Icon(Icons.close, color: Colors.grey),
                      onPressed: () {
                        ref.read(replyingToCommentProvider.notifier).state = null;
                      },
                    )
                  ],
                ),
              // Main input row
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _commentController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: replyingTo != null ? 'Add a reply...' : 'Add a comment...',
                        hintStyle: const TextStyle(color: Colors.grey),
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                  _isPosting
                      ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                      : IconButton(
                          onPressed: _postComment,
                          icon: const Icon(Icons.send, color: Colors.blue),
                        ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}


class CommentTile extends ConsumerStatefulWidget {
  final models.Document comment;
  const CommentTile({super.key, required this.comment});

  @override
  ConsumerState<CommentTile> createState() => _CommentTileState();
}

class _CommentTileState extends ConsumerState<CommentTile> {
  bool _showReplies = false;

  @override
  Widget build(BuildContext context) {
    final data = widget.comment.data;
    final username = data['username'] ?? 'Unknown';
    final content = data['content'] ?? '';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. The main comment body
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: Colors.blueGrey,
                child: Text(
                  username[0].toUpperCase(),
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      username,
                      style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      content,
                      style: const TextStyle(color: Colors.white70),
                    ),
                    const SizedBox(height: 8),
                    // Reply button
                    GestureDetector(
                      onTap: () {
                        // Set this comment as the one to reply to
                        ref.read(replyingToCommentProvider.notifier).state = widget.comment;
                      },
                      child: const Text(
                        'REPLY',
                        style: TextStyle(color: Colors.blue, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // 2. "View Replies" button and the replies list
          Padding(
            padding: const EdgeInsets.only(left: 44.0), // Indent replies
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // "View Replies" button (watches the provider)
                Consumer(
                  builder: (context, ref, child) {
                    final repliesAsync = ref.watch(repliesProvider(widget.comment.$id));
                    return repliesAsync.when(
                      data: (replies) {
                        if (replies.isEmpty) return const SizedBox.shrink(); // No replies, show nothing
                        
                        return TextButton(
                          onPressed: () => setState(() => _showReplies = !_showReplies),
                          child: Text(
                            _showReplies ? 'Hide Replies' : 'View ${replies.length} Replies',
                            style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold),
                          ),
                        );
                      },
                      loading: () => const Padding(
                        padding: EdgeInsets.all(8.0),
                        child: SizedBox(height: 10, width: 10, child: CircularProgressIndicator(strokeWidth: 2)),
                      ),
                      error: (e, s) => const Text('Error loading replies', style: TextStyle(color: Colors.red)),
                    );
                  },
                ),

                // The Replies List (conditionally shown)
                if (_showReplies)
                  Consumer(
                    builder: (context, ref, child) {
                      final repliesAsync = ref.watch(repliesProvider(widget.comment.$id));
                      return repliesAsync.when(
                        data: (replies) => Column(
                          children: replies.map((reply) => CommentTile(comment: reply)).toList(),
                        ),
                        loading: () => const Center(child: CircularProgressIndicator()),
                        error: (e, s) => const Text('Error loading replies', style: TextStyle(color: Colors.red)),
                      );
                    },
                  )
              ],
            ),
          ),
        ],
      ),
    );
  }
}