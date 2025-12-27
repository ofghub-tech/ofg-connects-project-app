import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:appwrite/appwrite.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:intl/intl.dart';

import 'package:ofgconnects_mobile/api/appwrite_client.dart';
import 'package:ofgconnects_mobile/logic/auth_provider.dart';
import 'package:ofgconnects_mobile/logic/video_provider.dart';
import 'package:ofgconnects_mobile/models/video.dart';

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
      // Logic for saved status UI would go here
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

  // --- FIXED: Use networkUrl directly for HLS/MP4 streams ---
  Future<void> _initializePlayer(Video video) async {
    if (_isPlayerInitialized) return;
    try {
      VideoPlayerController controller;
      
      // Determine the best URL to play
      String playUrl = video.videoUrl; // Default to raw
      if (video.compressionStatus == 'Done') {
        // Prefer highest quality available for Watch Page
        playUrl = video.url1080p ?? video.url720p ?? video.url480p ?? video.url360p ?? video.videoUrl;
      }

      controller = VideoPlayerController.networkUrl(Uri.parse(playUrl));
      
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