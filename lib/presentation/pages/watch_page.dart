import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:appwrite/appwrite.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:intl/intl.dart';

import 'package:ofgconnects_mobile/api/appwrite_client.dart';
import 'package:ofgconnects_mobile/logic/auth_provider.dart';
import 'package:ofgconnects_mobile/logic/video_provider.dart';
import 'package:ofgconnects_mobile/models/video.dart';
import 'package:ofgconnects_mobile/presentation/widgets/comments_sheet.dart';
import 'package:ofgconnects_mobile/presentation/widgets/suggested_video_card.dart';

class WatchPage extends ConsumerStatefulWidget {
  final String videoId;
  const WatchPage({super.key, required this.videoId});

  @override
  ConsumerState<WatchPage> createState() => _WatchPageState();
}

class _WatchPageState extends ConsumerState<WatchPage> {
  VideoPlayerController? _videoPlayerController;
  ChewieController? _chewieController;
  
  bool _isPlayerInitialized = false;
  bool _isInitializing = false; 
  String _currentQualityLabel = "Auto";
  
  bool _isLiked = false;
  bool _isSaved = false;
  bool _isSubscribed = false;
  bool _isDescriptionExpanded = false;
  int _localLikeCount = 0;
  int? _localViewCount;

  @override
  void initState() {
    super.initState();
    _logView();
  }

  @override
  void dispose() {
    _videoPlayerController?.dispose();
    _chewieController?.dispose();
    super.dispose();
  }

  // --- URL Helper ---
  String _getStreamingUrl(String url) {
    String finalUrl = url;
    if (!finalUrl.startsWith('http')) {
      finalUrl = AppwriteClient.storage.getFileView(
        bucketId: AppwriteClient.bucketIdVideos,
        fileId: url,
      ).toString();
    }
    if (finalUrl.contains('localhost')) {
      finalUrl = finalUrl.replaceFirst('localhost', '10.0.2.2');
    }
    if (!finalUrl.startsWith('http')) {
      finalUrl = 'http://$finalUrl';
    }
    return finalUrl;
  }

  Future<void> _logView() async {
    final user = ref.read(authProvider).user;
    if (user == null) return;
    try {
      final databases = ref.read(databasesProvider);
      final historyCheck = await databases.listDocuments(
        databaseId: AppwriteClient.databaseId, 
        collectionId: AppwriteClient.collectionIdHistory, 
        queries: [Query.equal('userId', user.$id), Query.equal('videoId', widget.videoId), Query.limit(1)]
      );
      if (historyCheck.total > 0) return;
      await databases.createDocument(
        databaseId: AppwriteClient.databaseId, 
        collectionId: AppwriteClient.collectionIdHistory, 
        documentId: ID.unique(), 
        data: {'userId': user.$id, 'videoId': widget.videoId}
      );
      final doc = await databases.getDocument(
        databaseId: AppwriteClient.databaseId, 
        collectionId: AppwriteClient.collectionIdVideos, 
        documentId: widget.videoId
      );
      final newCount = (doc.data['view_count'] ?? 0) + 1;
      await databases.updateDocument(
        databaseId: AppwriteClient.databaseId, 
        collectionId: AppwriteClient.collectionIdVideos, 
        documentId: widget.videoId, 
        data: {'view_count': newCount}
      );
      if (mounted) setState(() => _localViewCount = newCount);
    } catch (e) {
      debugPrint("View Log Failed: $e");
    }
  }

  // --- STRICT PLAYBACK LOGIC ---
  Future<void> _initializePlayer(Video video, {String? specificUrl, Duration? startAt}) async {
    if ((_isPlayerInitialized && specificUrl == null) || _isInitializing) return;
    _isInitializing = true;

    try {
      String playUrl;
      
      if (specificUrl != null) {
        // User selected specific quality
        playUrl = specificUrl;
      } else {
        // "Auto" Logic
        if (video.compressionStatus == 'Done') {
          // STRICT RULE: If done, NEVER play raw. Pick best available.
          // Prioritize 720p for mobile balance, then 480p, then 1080p.
          playUrl = video.url720p ?? video.url480p ?? video.url1080p ?? video.url360p!; 
        } else {
          // STRICT RULE: Only play raw if processing is not done
          playUrl = video.videoUrl;
        }
      }

      final finalUrl = _getStreamingUrl(playUrl);
      debugPrint("Streaming: $finalUrl");

      final newController = VideoPlayerController.networkUrl(Uri.parse(finalUrl));
      await newController.initialize();
      
      if (startAt != null) {
        await newController.seekTo(startAt);
      }

      _chewieController?.dispose();
      final oldController = _videoPlayerController;
      
      setState(() {
        _videoPlayerController = newController;
        _chewieController = ChewieController(
          videoPlayerController: _videoPlayerController!,
          autoPlay: true,
          aspectRatio: 16 / 9,
          allowFullScreen: true,
          materialProgressColors: ChewieProgressColors(playedColor: Colors.blueAccent),
          errorBuilder: (context, errorMessage) {
            return const Center(child: Text("Playback Error", style: TextStyle(color: Colors.white)));
          },
        );
        _isPlayerInitialized = true;
      });
      oldController?.dispose();

    } catch (e) {
      debugPrint("Player Init Error: $e");
    } finally {
      if (mounted) _isInitializing = false;
    }
  }

  void _showQualitySelector(Video video) {
    // Only show qualities that actually exist
    final Map<String, String?> qualities = {};
    
    // Always have "Auto"
    qualities['Auto'] = null;

    if (video.compressionStatus == 'Done') {
      if (video.url1080p != null) qualities['1080p'] = video.url1080p;
      if (video.url720p != null) qualities['720p'] = video.url720p;
      if (video.url480p != null) qualities['480p'] = video.url480p;
      if (video.url360p != null) qualities['360p'] = video.url360p;
      // NOTE: "Original" (Raw) is intentionally OMITTED if compression is Done.
    } else {
      qualities['Original'] = video.videoUrl;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text("Quality", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              ),
              ...qualities.entries.map((entry) {
                return ListTile(
                  leading: _currentQualityLabel == entry.key 
                      ? const Icon(Icons.check, color: Colors.blueAccent) 
                      : const SizedBox(width: 24),
                  title: Text(entry.key, style: const TextStyle(color: Colors.white)),
                  onTap: () {
                    Navigator.pop(context);
                    if (_currentQualityLabel != entry.key) {
                      final currentPos = _videoPlayerController?.value.position;
                      setState(() {
                        _currentQualityLabel = entry.key;
                        _isPlayerInitialized = false; 
                      });
                      _initializePlayer(video, specificUrl: entry.value, startAt: currentPos);
                    }
                  },
                );
              }),
            ],
          ),
        );
      },
    );
  }

  void _toggleLike() => setState(() => _isLiked = !_isLiked);
  void _toggleSave() => setState(() => _isSaved = !_isSaved);
  void _toggleSubscribe() => setState(() => _isSubscribed = !_isSubscribed);

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

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      body: SafeArea(
        child: videoAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, _) => Center(child: Text("Error: $err", style: const TextStyle(color: Colors.white))),
          data: (video) {
            // --- 1. ADMIN APPROVAL CHECK ---
            if (video.adminStatus != 'approved') {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.lock_clock, size: 60, color: Colors.orange),
                    const SizedBox(height: 16),
                    Text("This video is ${video.adminStatus}.", style: const TextStyle(color: Colors.white, fontSize: 18)),
                    const SizedBox(height: 8),
                    const Text("It has not been approved by an admin yet.", style: TextStyle(color: Colors.grey)),
                  ],
                ),
              );
            }

            if (!_isPlayerInitialized) {
               Future.microtask(() => _initializePlayer(video));
            }
            if (_localLikeCount == 0) _localLikeCount = video.likeCount;

            return Column(
              children: [
                AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Container(
                    color: Colors.black,
                    child: _isPlayerInitialized 
                        ? Chewie(controller: _chewieController!)
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
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Text(
                                      video.title,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white),
                                    onPressed: () => setState(() => _isDescriptionExpanded = !_isDescriptionExpanded),
                                  )
                                ],
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Text(
                                    '${NumberFormat.compact().format(_localViewCount ?? video.viewCount)} views',
                                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '•  ${DateFormat.yMMMd().format(video.createdAt)}',
                                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                                  ),
                                  const Spacer(),
                                  IconButton(
                                    icon: const Icon(Icons.settings_outlined, color: Colors.white, size: 20),
                                    onPressed: () => _showQualitySelector(video),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        
                        // Action Bar
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                          child: Row(
                            children: [
                              _buildActionButton(_isLiked ? Icons.thumb_up : Icons.thumb_up_outlined, NumberFormat.compact().format(_localLikeCount), _toggleLike, isActive: _isLiked),
                              const SizedBox(width: 10),
                              _buildActionButton(Icons.share_outlined, "Share", () {}),
                              const SizedBox(width: 10),
                              _buildActionButton(_isSaved ? Icons.bookmark : Icons.bookmark_outline, "Save", _toggleSave, isActive: _isSaved),
                            ],
                          ),
                        ),

                        const Divider(color: Colors.white10),

                        // Comments
                        ListTile(
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
                          trailing: const Icon(Icons.unfold_more, color: Colors.white, size: 20),
                        ),
                        
                        const Divider(color: Colors.white10),

                        // Up Next
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                          child: Text("Up Next", style: Theme.of(context).textTheme.titleSmall?.copyWith(color: Colors.white)),
                        ),
                        suggestedAsync.when(
                          data: (videos) => Column(
                            children: videos.map((v) => SuggestedVideoCard(video: v)).toList(),
                          ),
                          loading: () => const Padding(padding: EdgeInsets.all(20), child: Center(child: CircularProgressIndicator())),
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