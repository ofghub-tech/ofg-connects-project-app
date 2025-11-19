// lib/presentation/widgets/comments_sheet.dart
import 'package:appwrite/models.dart' as models;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// --- THIS IMPORT WAS MISSING OR INCORRECT ---
import 'package:ofgconnects_mobile/logic/comments_provider.dart'; 
// --------------------------------------------

// Shared provider to track who we are replying to
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
    
    final replyingTo = ref.read(replyingToCommentProvider);

    setState(() => _isPosting = true);
    try {
      await ref.read(commentsProvider.notifier).postComment(
        videoId: widget.videoId,
        content: _commentController.text.trim(),
        parentId: replyingTo?.$id,
      );
      _commentController.clear();
      ref.read(replyingToCommentProvider.notifier).state = null;
      FocusManager.instance.primaryFocus?.unfocus();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to post: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isPosting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final commentsState = ref.watch(commentsProvider);
    final comments = commentsState.comments;
    final replyingTo = ref.watch(replyingToCommentProvider);

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 20)]
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[600],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              "Comments (${comments.length})", 
              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)
            ),
          ),
          
          Expanded(
            child: commentsState.isLoading && comments.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : comments.isEmpty
                  ? const Center(child: Text("No comments yet. Be the first!", style: TextStyle(color: Colors.grey)))
                  : NotificationListener<ScrollNotification>(
                      onNotification: (scrollInfo) {
                        if (!commentsState.isLoading && 
                             commentsState.hasMore && 
                             scrollInfo.metrics.pixels >= scrollInfo.metrics.maxScrollExtent - 100) {
                          ref.read(commentsProvider.notifier).loadMore(widget.videoId);
                        }
                        return false;
                      },
                      child: ListView.builder(
                        controller: widget.scrollController,
                        itemCount: comments.length + (commentsState.hasMore ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index == comments.length) {
                            return const Center(child: Padding(
                              padding: EdgeInsets.all(16.0),
                              child: CircularProgressIndicator(),
                            ));
                          }
                          return CommentTile(comment: comments[index]);
                        },
                      ),
                    ),
          ),

          // Input Area
          Container(
            padding: EdgeInsets.only(
              left: 16, 
              right: 16, 
              top: 12, 
              bottom: MediaQuery.of(context).viewInsets.bottom + 16
            ),
            decoration: const BoxDecoration(
              color: Color(0xFF121212),
              border: Border(top: BorderSide(color: Colors.white10)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (replyingTo != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: Row(
                      children: [
                        Text(
                          'Replying to ${replyingTo.data['username'] ?? 'Unknown'}',
                          style: const TextStyle(color: Colors.blueAccent, fontSize: 12),
                        ),
                        const Spacer(),
                        GestureDetector(
                          onTap: () => ref.read(replyingToCommentProvider.notifier).state = null,
                          child: const Icon(Icons.close, size: 16, color: Colors.grey),
                        )
                      ],
                    ),
                  ),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _commentController,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: replyingTo != null ? 'Write a reply...' : 'Add a comment...',
                          hintStyle: const TextStyle(color: Colors.grey),
                          filled: true,
                          fillColor: Colors.white.withOpacity(0.05),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    _isPosting
                        ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                        : CircleAvatar(
                            backgroundColor: Colors.blueAccent,
                            radius: 20,
                            child: IconButton(
                              onPressed: _postComment,
                              icon: const Icon(Icons.send_rounded, color: Colors.white, size: 18),
                            ),
                          ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
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
      padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: Colors.grey[800],
                child: Text(
                  username.isNotEmpty ? username[0].toUpperCase() : 'U',
                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      username,
                      style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      content,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                    ),
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: () {
                        ref.read(replyingToCommentProvider.notifier).state = widget.comment;
                      },
                      child: const Text(
                        'Reply',
                        style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          Padding(
            padding: const EdgeInsets.only(left: 44.0), 
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Consumer(
                  builder: (context, ref, child) {
                    return TextButton(
                      onPressed: () => setState(() => _showReplies = !_showReplies),
                      style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 30), alignment: Alignment.centerLeft),
                      child: Text(
                        _showReplies ? 'Hide Replies' : 'View Replies',
                        style: const TextStyle(color: Colors.blueAccent, fontSize: 12),
                      ),
                    );
                  },
                ),

                if (_showReplies)
                  Consumer(
                    builder: (context, ref, child) {
                      // This works now because we imported comments_provider.dart
                      final repliesAsync = ref.watch(repliesProvider(widget.comment.$id));
                      return repliesAsync.when(
                        data: (replies) => Column(
                          children: replies.map((reply) => CommentTile(comment: reply)).toList(),
                        ),
                        loading: () => const Padding(padding: EdgeInsets.all(8), child: SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))),
                        error: (e, s) => const Text('Error loading replies', style: TextStyle(color: Colors.red, fontSize: 12)),
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