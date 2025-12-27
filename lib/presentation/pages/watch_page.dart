import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:appwrite/appwrite.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';

import 'package:ofgconnects_mobile/api/appwrite_client.dart';
import 'package:ofgconnects_mobile/logic/auth_provider.dart';
import 'package:ofgconnects_mobile/logic/video_provider.dart';
import 'package:ofgconnects_mobile/models/video.dart';
import 'package:ofgconnects_mobile/presentation/widgets/comments_sheet.dart'; 
import 'package:ofgconnects_mobile/logic/interaction_provider.dart'; 

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

  bool _isSaved = false;
  String? _savedDocId;
  bool _isTogglingSave = false;
  bool _isDescriptionExpanded = false;
  int? _localViewCount; 

  @override
  void initState() {
    super.initState();
    _checkSavedStatus();
    _logView();
  }

  @override
  void dispose() {
    _videoPlayerController?.dispose();
    _chewieController?.dispose();
    super.dispose();
  }

  Future<void> _checkSavedStatus() async {
    final user = ref.read(authProvider).user;
    if (user == null) return;
    try {
      final response = await ref.read(databasesProvider).listDocuments(
        databaseId: AppwriteClient.databaseId, collectionId: AppwriteClient.collectionIdWatchLater,
        queries: [Query.equal('userId', user.$id), Query.equal('videoId', widget.videoId), Query.limit(1)],
      );
      if (mounted && response.total > 0) { setState(() { _isSaved = true; _savedDocId = response.documents[0].$id; }); }
    } catch (e) { print("Watch Later Check Failed: $e"); }
  }

  Future<void> _logView() async {
    final user = ref.read(authProvider).user;
    if (user == null) return; 
    try {
      final databases = ref.read(databasesProvider);
      final historyCheck = await databases.listDocuments(databaseId: AppwriteClient.databaseId, collectionId: AppwriteClient.collectionIdHistory, queries: [Query.equal('userId', user.$id), Query.equal('videoId', widget.videoId), Query.limit(1)]);
      if (historyCheck.total > 0) return;
      await databases.createDocument(databaseId: AppwriteClient.databaseId, collectionId: AppwriteClient.collectionIdHistory, documentId: ID.unique(), data: {'userId': user.$id, 'videoId': widget.videoId});
      final doc = await databases.getDocument(databaseId: AppwriteClient.databaseId, collectionId: AppwriteClient.collectionIdVideos, documentId: widget.videoId);
      final newCount = (doc.data['view_count'] ?? 0) + 1;
      await databases.updateDocument(databaseId: AppwriteClient.databaseId, collectionId: AppwriteClient.collectionIdVideos, documentId: widget.videoId, data: {'view_count': newCount});
      if (mounted) setState(() => _localViewCount = newCount);
    } catch (e) { print("View Log Failed: $e"); }
  }

  // Adaptive Bitrate Logic: Generate Master Playlist
  Future<File> _createMasterPlaylist(Video video) async {
    final tempDir = await getTemporaryDirectory();
    final file = File('${tempDir.path}/${video.id}_master.m3u8');
    
    if (await file.exists()) return file;

    StringBuffer content = StringBuffer();
    content.writeln("#EXTM3U");
    
    // Low Quality First (For Faster Initial Loading)
    if (video.url360p != null) {
      content.writeln("#EXT-X-STREAM-INF:BANDWIDTH=800000,RESOLUTION=640x360");
      content.writeln(video.url360p);
    }
    if (video.url480p != null) {
      content.writeln("#EXT-X-STREAM-INF:BANDWIDTH=1500000,RESOLUTION=854x480");
      content.writeln(video.url480p);
    }
    if (video.url720p != null) {
      content.writeln("#EXT-X-STREAM-INF:BANDWIDTH=3000000,RESOLUTION=1280x720");
      content.writeln(video.url720p);
    }
    if (video.url1080p != null) {
      content.writeln("#EXT-X-STREAM-INF:BANDWIDTH=5000000,RESOLUTION=1920x1080");
      content.writeln(video.url1080p);
    }

    await file.writeAsString(content.toString());
    return file;
  }

  Future<void> _initializePlayer(Video video) async {
    if (_isPlayerInitialized) return;
    try {
      VideoPlayerController controller;
      if (video.compressionStatus == 'Done') {
        final masterFile = await _createMasterPlaylist(video);
        controller = VideoPlayerController.file(masterFile);
      } else {
        controller = VideoPlayerController.networkUrl(Uri.parse(video.videoUrl));
      }
      
      await controller.initialize();
      _videoPlayerController = controller;
      _chewieController = ChewieController(
        videoPlayerController: _videoPlayerController!,
        autoPlay: true,
        aspectRatio: _videoPlayerController!.value.aspectRatio,
        materialProgressColors: ChewieProgressColors(playedColor: Colors.blueAccent),
      );
      if (mounted) setState(() => _isPlayerInitialized = true);
    } catch (e) { print("Player Init Error: $e"); }
  }

  @override
  Widget build(BuildContext context) {
    final videoAsync = ref.watch(videoDetailsProvider(widget.videoId));
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      body: videoAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
        data: (video) {
          if (!_isPlayerInitialized) Future.microtask(() => _initializePlayer(video));
          return Column(
            children: [
              Container(color: Colors.black, child: SafeArea(bottom: false, child: AspectRatio(aspectRatio: 16 / 9, child: _isPlayerInitialized ? Chewie(controller: _chewieController!) : const Center(child: CircularProgressIndicator())))),
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(video.title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                        const SizedBox(height: 8),
                        Text('${NumberFormat.compact().format(_localViewCount ?? video.viewCount)} views', style: const TextStyle(color: Colors.grey)),
                        const SizedBox(height: 16),
                        Row(children: [CircleAvatar(radius: 18, backgroundColor: Colors.grey[800], child: Text(video.creatorName[0].toUpperCase())), const SizedBox(width: 12), Text(video.creatorName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))]),
                        const SizedBox(height: 16),
                        Text(video.description, style: const TextStyle(color: Colors.white70)),
                      ],
                    ),
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