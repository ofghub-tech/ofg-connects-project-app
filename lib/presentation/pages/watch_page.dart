// lib/presentation/pages/watch_page.dart
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
  int? _localViewCount; 
  String _selectedQuality = "Auto";

  @override
  void initState() {
    super.initState();
    _logView(); // Logs the view to Appwrite
  }

  @override
  void dispose() {
    _chewieController?.dispose();
    _videoPlayerController?.dispose();
    super.dispose();
  }

  /// Correctly generates the Appwrite URL for streaming
  String _getStreamingUrl(String fileUrlOrId) {
    if (fileUrlOrId.startsWith('http')) return fileUrlOrId;
    
    // If it's just a File ID, construct the proper Appwrite View URL
    return AppwriteClient.storage.getFileView(
      bucketId: AppwriteClient.bucketIdVideos,
      fileId: fileUrlOrId,
    ).toString();
  }

  Future<void> _logView() async {
    final user = ref.read(authProvider).user;
    if (user == null) return; 
    try {
      final databases = ref.read(databasesProvider);
      
      // 1. Check history
      final historyCheck = await databases.listDocuments(
        databaseId: AppwriteClient.databaseId, 
        collectionId: AppwriteClient.collectionIdHistory, 
        queries: [Query.equal('userId', user.$id), Query.equal('videoId', widget.videoId), Query.limit(1)]
      );
      
      if (historyCheck.total > 0) return;
      
      // 2. Add to history
      await databases.createDocument(
        databaseId: AppwriteClient.databaseId, 
        collectionId: AppwriteClient.collectionIdHistory, 
        documentId: ID.unique(), 
        data: {'userId': user.$id, 'videoId': widget.videoId}
      );
      
      // 3. Increment views
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

  Future<void> _changeQuality(String url, String label) async {
    if (_selectedQuality == label || _videoPlayerController == null) return;

    final Duration currentPosition = _videoPlayerController!.value.position;
    final bool wasPlaying = _videoPlayerController!.value.isPlaying;

    setState(() {
      _isPlayerInitialized = false;
      _selectedQuality = label;
    });

    _chewieController?.dispose(); 
    await _videoPlayerController?.dispose(); 

    // Use corrected URL construction
    final streamingUrl = _getStreamingUrl(url);
    _videoPlayerController = VideoPlayerController.networkUrl(Uri.parse(streamingUrl));
    
    try {
      await _videoPlayerController!.initialize();
      await _videoPlayerController!.seekTo(currentPosition);
      
      _chewieController = ChewieController(
        videoPlayerController: _videoPlayerController!,
        autoPlay: wasPlaying,
        aspectRatio: _videoPlayerController!.value.aspectRatio,
        materialProgressColors: ChewieProgressColors(playedColor: Colors.blueAccent),
      );

      if (mounted) setState(() => _isPlayerInitialized = true);
    } catch (e) {
      debugPrint("Quality Change Error: $e");
    }
  }

  void _showQualitySelector(Video video) {
    final Map<String, String> qualities = {
      if (video.url1080p != null) '1080p': video.url1080p!,
      if (video.url720p != null) '720p': video.url720p!,
      if (video.url480p != null) '480p': video.url480p!,
      if (video.url360p != null) '360p': video.url360p!,
      'Original': video.videoUrl,
    };

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: qualities.entries.map((entry) => ListTile(
            leading: Icon(Icons.check, color: _selectedQuality == entry.key ? Colors.blueAccent : Colors.transparent),
            title: Text(entry.key, style: const TextStyle(color: Colors.white)),
            onTap: () {
              Navigator.pop(context);
              _changeQuality(entry.value, entry.key);
            },
          )).toList(),
        ),
      ),
    );
  }

  Future<void> _initializePlayer(Video video) async {
    if (_isPlayerInitialized) return;
    try {
      String playUrl = video.videoUrl;
      String initialLabel = "Original";

      // Select highest quality automatically
      if (video.compressionStatus == 'Done') {
        if (video.url1080p != null) { playUrl = video.url1080p!; initialLabel = "1080p"; }
        else if (video.url720p != null) { playUrl = video.url720p!; initialLabel = "720p"; }
      }

      final streamingUrl = _getStreamingUrl(playUrl);
      _videoPlayerController = VideoPlayerController.networkUrl(Uri.parse(streamingUrl));
      
      await _videoPlayerController!.initialize();
      _chewieController = ChewieController(
        videoPlayerController: _videoPlayerController!,
        autoPlay: true,
        aspectRatio: _videoPlayerController!.value.aspectRatio,
      );

      if (mounted) {
        setState(() {
          _selectedQuality = initialLabel;
          _isPlayerInitialized = true;
        });
      }
    } catch (e) {
      debugPrint("Player Init Error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final videoAsync = ref.watch(videoDetailsProvider(widget.videoId));
    
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      body: videoAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error loading video: $err')),
        data: (video) {
          if (!_isPlayerInitialized && _videoPlayerController == null) {
             Future.microtask(() => _initializePlayer(video));
          }
          return Column(
            children: [
              Container(
                color: Colors.black, 
                child: SafeArea(
                  bottom: false, 
                  child: AspectRatio(
                    aspectRatio: 16 / 9, 
                    child: _isPlayerInitialized 
                      ? Chewie(controller: _chewieController!) 
                      : const Center(child: CircularProgressIndicator())
                  )
                )
              ),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      ListTile(
                        title: Text(video.title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        subtitle: Text('${NumberFormat.compact().format(_localViewCount ?? video.viewCount)} views • Quality: $_selectedQuality'),
                        trailing: IconButton(
                          icon: const Icon(Icons.settings, color: Colors.white),
                          onPressed: () => _showQualitySelector(video),
                        ),
                      ),
                      const Divider(color: Colors.white10),
                      ListTile(
                        onTap: () => showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          builder: (context) => DraggableScrollableSheet(
                            initialChildSize: 0.75,
                            maxChildSize: 0.9,
                            builder: (_, controller) => CommentsSheet(videoId: video.id, scrollController: controller),
                          ),
                        ),
                        leading: const Icon(Icons.comment_outlined, color: Colors.blueAccent),
                        title: const Text("Comments", style: TextStyle(color: Colors.white)),
                        trailing: const Icon(Icons.keyboard_arrow_up, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}