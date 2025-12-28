// lib/presentation/widgets/comments_sheet.dart
import 'package:appwrite/models.dart' as models;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ofgconnects/logic/comments_provider.dart'; 

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
    final text = _commentController.text.trim();
    if (text.isEmpty) return;
    
    final replyingTo = ref.read(replyingToCommentProvider);
    setState(() => _isPosting = true);
    
    try {
      await ref.read(commentsProvider.notifier).postComment(
        videoId: widget.videoId,
        content: text,
        parentId: replyingTo?.$id,
      );
      
      _commentController.clear();
      ref.read(replyingToCommentProvider.notifier).state = null;
      FocusScope.of(context).unfocus();
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
    final replyingTo = ref.watch(replyingToCommentProvider);

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF1E1E1E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[600], borderRadius: BorderRadius.circular(2))),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text("Comments (${commentsState.comments.length})", style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          ),
          
          Expanded(
            child: commentsState.isLoading && commentsState.comments.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : commentsState.comments.isEmpty
                  ? const Center(child: Text("No comments yet.", style: TextStyle(color: Colors.grey)))
                  : ListView.builder(
                      controller: widget.scrollController,
                      itemCount: commentsState.comments.length,
                      itemBuilder: (context, index) => CommentTile(comment: commentsState.comments[index]),
                    ),
          ),

          // Input Area
          _buildInputArea(replyingTo),
        ],
      ),
    );
  }

  Widget _buildInputArea(models.Document? replyingTo) {
    return Container(
      padding: EdgeInsets.only(left: 16, right: 16, top: 12, bottom: MediaQuery.of(context).viewInsets.bottom + 16),
      decoration: const BoxDecoration(color: Color(0xFF121212), border: Border(top: BorderSide(color: Colors.white10))),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (replyingTo != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Row(
                children: [
                  Text('Replying to ${replyingTo.data['username']}', style: const TextStyle(color: Colors.blueAccent, fontSize: 12)),
                  const Spacer(),
                  GestureDetector(onTap: () => ref.read(replyingToCommentProvider.notifier).state = null, child: const Icon(Icons.close, size: 16, color: Colors.grey)),
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
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.05),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              _isPosting 
                ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                : IconButton(onPressed: _postComment, icon: const Icon(Icons.send, color: Colors.blueAccent)),
            ],
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
    final userId = data['userId'];

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: () => context.push('/profile/$userId?name=$username'),
                child: CircleAvatar(radius: 16, child: Text(username[0].toUpperCase())),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(username, style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 2),
                    Text(data['content'] ?? '', style: const TextStyle(color: Colors.white, fontSize: 14)),
                    const SizedBox(height: 4),
                    GestureDetector(
                      onTap: () => ref.read(replyingToCommentProvider.notifier).state = widget.comment,
                      child: const Text('Reply', style: TextStyle(color: Colors.grey, fontSize: 12)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          // Replies Section
          Padding(
            padding: const EdgeInsets.only(left: 44),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextButton(
                  onPressed: () => setState(() => _showReplies = !_showReplies),
                  child: Text(_showReplies ? 'Hide Replies' : 'View Replies', style: const TextStyle(color: Colors.blueAccent, fontSize: 12)),
                ),
                if (_showReplies)
                  ref.watch(repliesProvider(widget.comment.$id)).when(
                    data: (replies) => Column(children: replies.map((r) => CommentTile(comment: r)).toList()),
                    loading: () => const LinearProgressIndicator(),
                    error: (_, __) => const SizedBox(),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}