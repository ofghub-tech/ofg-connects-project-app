import 'dart:io'; // Needed for File
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:appwrite/appwrite.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart'; // Make sure to add this package if missing

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

  // ... (Keep _checkSavedStatus, _toggleSave, and _logView exactly as they were) ...
  Future<void> _checkSavedStatus() async {
    final user = ref.read(authProvider).user;
    if (user == null) return;
    try {
      final databases = ref.read(databasesProvider);
      final response = await databases.listDocuments(
        databaseId: AppwriteClient.databaseId, collectionId: AppwriteClient.collectionIdWatchLater,
        queries: [Query.equal('userId', user.$id), Query.equal('videoId', widget.videoId), Query.limit(1)],
      );
      if (mounted) {
        if (response.total > 0) { setState(() { _isSaved = true; _savedDocId = response.documents[0].$id; }); } 
        else { setState(() { _isSaved = false; _savedDocId = null; }); }
      }
    } catch (e) { print("Failed to check watch later: $e"); }
  }

  Future<void> _toggleSave() async {
    final user = ref.read(authProvider).user;
    if (user == null) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please log in to save videos"))); return; }
    if (_isTogglingSave) return;
    setState(() => _isTogglingSave = true);
    try {
      final databases = ref.read(databasesProvider);
      if (_isSaved && _savedDocId != null) {
        await databases.deleteDocument(databaseId: AppwriteClient.databaseId, collectionId: AppwriteClient.collectionIdWatchLater, documentId: _savedDocId!);
        setState(() { _isSaved = false; _savedDocId = null; });
      } else {
        final uniqueId = ID.unique();
        final response = await databases.createDocument(
          databaseId: AppwriteClient.databaseId, collectionId: AppwriteClient.collectionIdWatchLater, documentId: uniqueId,
          data: { 'userId': user.$id, 'videoId': widget.videoId }, permissions: [Permission.read(Role.user(user.$id)), Permission.write(Role.user(user.$id))],
        );
        setState(() { _isSaved = true; _savedDocId = response.$id; });
      }
    } catch (e) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Failed to update: $e"))); } 
    finally { setState(() => _isTogglingSave = false); }
  }

  Future<void> _logView() async {
    final user = ref.read(authProvider).user;
    if (user == null) return; 
    try {
      final databases = ref.read(databasesProvider);
      final historyCheck = await databases.listDocuments(databaseId: AppwriteClient.databaseId, collectionId: AppwriteClient.collectionIdHistory, queries: [Query.equal('userId', user.$id), Query.equal('videoId', widget.videoId), Query.limit(1)]);
      if (historyCheck.total > 0) return;
      await databases.createDocument(databaseId: AppwriteClient.databaseId, collectionId: AppwriteClient.collectionIdHistory, documentId: ID.unique(), data: {'userId': user.$id, 'videoId': widget.videoId}, permissions: [Permission.read(Role.user(user.$id)), Permission.write(Role.user(user.$id))]);
      final doc = await databases.getDocument(databaseId: AppwriteClient.databaseId, collectionId: AppwriteClient.collectionIdVideos, documentId: widget.videoId);
      final currentCount = doc.data['view_count'] ?? 0;
      final newCount = currentCount + 1;
      await databases.updateDocument(databaseId: AppwriteClient.databaseId, collectionId: AppwriteClient.collectionIdVideos, documentId: widget.videoId, data: {'view_count': newCount});
      if (mounted) setState(() => _localViewCount = newCount);
    } catch (e) { print("View log failed: $e"); }
  }
  // ... (End of preserved logic) ...

  // --- NEW: GENERATE MASTER PLAYLIST ---
  Future<File> _createMasterPlaylist(Video video) async {
    final tempDir = await getTemporaryDirectory();
    final file = File('${tempDir.path}/${video.id}_master.m3u8');
    
    // Construct the Master M3U8 content
    StringBuffer content = StringBuffer();
    content.writeln("#EXTM3U");
    content.writeln("#EXT-X-VERSION:3");

    // Add 1080p (High Bandwidth ~5Mbps)
    if (video.url1080p != null && video.url1080p!.isNotEmpty) {
      content.writeln("#EXT-X-STREAM-INF:BANDWIDTH=5000000,RESOLUTION=1920x1080");
      content.writeln(video.url1080p);
    }
    // Add 720p (Med Bandwidth ~2.5Mbps)
    if (video.url720p != null && video.url720p!.isNotEmpty) {
      content.writeln("#EXT-X-STREAM-INF:BANDWIDTH=2500000,RESOLUTION=1280x720");
      content.writeln(video.url720p);
    }
    // Add 480p (Low Bandwidth ~1Mbps)
    if (video.url480p != null && video.url480p!.isNotEmpty) {
      content.writeln("#EXT-X-STREAM-INF:BANDWIDTH=1000000,RESOLUTION=854x480");
      content.writeln(video.url480p);
    }
    // Add 360p (Min Bandwidth ~600Kbps)
    if (video.url360p != null && video.url360p!.isNotEmpty) {
      content.writeln("#EXT-X-STREAM-INF:BANDWIDTH=600000,RESOLUTION=640x360");
      content.writeln(video.url360p);
    }

    await file.writeAsString(content.toString());
    return file;
  }

  // --- PLAYER INITIALIZATION ---
  Future<void> _initializePlayer(Video video) async {
    if (_isPlayerInitialized) return;

    VideoPlayerController controller;

    try {
      if (video.compressionStatus == 'Done') {
        // 1. ADAPTIVE MODE: Generate and play Master Playlist
        final masterFile = await _createMasterPlaylist(video);
        controller = VideoPlayerController.file(
          masterFile,
          videoPlayerOptions: VideoPlayerOptions(mixWithOthers: false),
        );
        print("Playing Adaptive HLS from: ${masterFile.path}");
      } else {
        // 2. RAW MODE: Play original file
        controller = VideoPlayerController.networkUrl(
          Uri.parse(video.videoUrl),
          videoPlayerOptions: VideoPlayerOptions(mixWithOthers: false),
        );
      }
      
      await controller.initialize();
      _videoPlayerController = controller;

      _chewieController = ChewieController(
        videoPlayerController: _videoPlayerController!,
        autoPlay: true,
        looping: false,
        aspectRatio: _videoPlayerController!.value.aspectRatio,
        allowFullScreen: true,
        materialProgressColors: ChewieProgressColors(
          playedColor: Colors.blueAccent,
          handleColor: Colors.blueAccent,
          backgroundColor: Colors.grey.shade800,
          bufferedColor: Colors.white24,
        ),
        placeholder: Container(color: Colors.black),
        errorBuilder: (context, errorMessage) {
          return Center(child: Text("Video Error: $errorMessage", style: const TextStyle(color: Colors.white)));
        },
      );

      setState(() {
        _isPlayerInitialized = true;
      });
    } catch (e) {
       print("Error initializing player: $e");
    }
  }

  void _showCommentsSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        builder: (_, controller) => CommentsSheet(videoId: widget.videoId, scrollController: controller),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final videoAsync = ref.watch(videoDetailsProvider(widget.videoId));

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      body: videoAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err', style: const TextStyle(color: Colors.red))),
        data: (video) {
          
          if (!_isPlayerInitialized && (video.videoUrl.isNotEmpty || video.url360p != null)) {
            _initializePlayer(video);
          }

          final displayViews = _localViewCount ?? video.viewCount;
          final formattedViews = NumberFormat.compact().format(displayViews);
          final timeAgo = _formatTimeAgo(video.createdAt);

          return Column(
            children: [
              // --- 1. VIDEO PLAYER ---
              Container(
                color: Colors.black,
                child: SafeArea(
                  bottom: false,
                  child: AspectRatio(
                    aspectRatio: 16 / 9,
                    child: _isPlayerInitialized && _chewieController != null
                        ? Chewie(controller: _chewieController!)
                        : const Center(child: CircularProgressIndicator(color: Colors.white24)),
                  ),
                ),
              ),

              // --- 2. CONTENT ---
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(video.title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white, height: 1.3)),
                            const SizedBox(height: 8),
                            Text('$formattedViews views • $timeAgo', style: TextStyle(color: Colors.grey[400], fontSize: 13)),
                            const SizedBox(height: 16),

                            Row(
                              children: [
                                GestureDetector(
                                  onTap: () => context.push('/profile/${video.creatorId}?name=${Uri.encodeComponent(video.creatorName)}'),
                                  child: CircleAvatar(radius: 18, backgroundColor: Colors.grey[800], child: Text(video.creatorName.isNotEmpty ? video.creatorName[0].toUpperCase() : "?", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () => context.push('/profile/${video.creatorId}?name=${Uri.encodeComponent(video.creatorName)}'),
                                    child: Text(video.creatorName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 16)),
                                  ),
                                ),
                                ElevatedButton(
                                  onPressed: () {},
                                  style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.black, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0), minimumSize: const Size(0, 36), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18))),
                                  child: const Text("Subscribe"),
                                ),
                              ],
                            ),

                            const SizedBox(height: 16),
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: [
                                  _PillButton(icon: Icons.thumb_up_outlined, label: "${video.likeCount}", onTap: () => ref.read(interactionProvider).toggleLike(video.id)),
                                  const SizedBox(width: 10),
                                  _PillButton(icon: Icons.share_outlined, label: "Share", onTap: () {}),
                                  const SizedBox(width: 10),
                                  _PillButton(icon: _isSaved ? Icons.bookmark : Icons.bookmark_border, label: _isSaved ? "Saved" : "Save", active: _isSaved, onTap: _isTogglingSave ? null : _toggleSave),
                                  const SizedBox(width: 10),
                                  _PillButton(icon: Icons.flag_outlined, label: "Report", onTap: () {}),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                            GestureDetector(
                              onTap: () => setState(() => _isDescriptionExpanded = !_isDescriptionExpanded),
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text("Description", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                                    const SizedBox(height: 4),
                                    Text(video.description.isNotEmpty ? video.description : "No description provided.", style: const TextStyle(color: Colors.white70, fontSize: 13), maxLines: _isDescriptionExpanded ? null : 2, overflow: _isDescriptionExpanded ? TextOverflow.visible : TextOverflow.ellipsis),
                                    if (video.description.length > 50)
                                      Padding(padding: const EdgeInsets.only(top: 4), child: Text(_isDescriptionExpanded ? "Show less" : "...more", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13))),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      GestureDetector(
                        onTap: () => _showCommentsSheet(context),
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 16),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white10)),
                          child: Row(
                            children: [
                              const Text("Comments", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                              const SizedBox(width: 8),
                              Text("${video.videoUrl.length % 5}", style: TextStyle(color: Colors.grey[400])), 
                              const Spacer(),
                              const Icon(Icons.unfold_more, color: Colors.white54, size: 20),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Divider(color: Colors.white10, thickness: 4),
                      const SizedBox(height: 16),
                      const Padding(padding: EdgeInsets.symmetric(horizontal: 16, vertical: 0), child: Text("Up Next", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18))),
                      const SizedBox(height: 12),
                      _SuggestedVideosList(currentVideoId: video.id),
                      const SizedBox(height: 40),
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

  String _formatTimeAgo(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inDays > 365) return '${(diff.inDays / 365).floor()}y ago';
    if (diff.inDays > 30) return '${(diff.inDays / 30).floor()}mo ago';
    if (diff.inDays > 0) return '${diff.inDays}d ago';
    if (diff.inHours > 0) return '${diff.inHours}h ago';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
    return 'Just now';
  }
}

class _PillButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool active;
  const _PillButton({required this.icon, required this.label, this.onTap, this.active = false});
  @override
  Widget build(BuildContext context) {
    return Material(
      color: active ? Colors.white : Colors.white.withOpacity(0.1),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Row(children: [Icon(icon, size: 18, color: active ? Colors.black : Colors.white), const SizedBox(width: 6), Text(label, style: TextStyle(color: active ? Colors.black : Colors.white, fontWeight: FontWeight.w600, fontSize: 13))]),
        ),
      ),
    );
  }
}

class _SuggestedVideosList extends ConsumerWidget {
  final String currentVideoId;
  const _SuggestedVideosList({required this.currentVideoId});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final suggestionsAsync = ref.watch(suggestedVideosProvider(currentVideoId));
    return suggestionsAsync.when(
      loading: () => const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator())),
      error: (e, _) => const SizedBox.shrink(),
      data: (videos) {
        if (videos.isEmpty) return const Padding(padding: EdgeInsets.all(16), child: Text("No related videos.", style: TextStyle(color: Colors.grey)));
        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: videos.length,
          itemBuilder: (context, index) {
            final v = videos[index];
            return InkWell(
              onTap: () => context.push('/home/watch/${v.id}'),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: SizedBox(
                        width: 140, height: 80,
                        child: Stack(fit: StackFit.expand, children: [Image.network(v.thumbnailUrl, fit: BoxFit.cover, errorBuilder: (_,__,___) => Container(color: Colors.grey[800])), Positioned(bottom: 4, right: 4, child: Container(padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2), decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(4)), child: const Text("VIDEO", style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold))))]),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(v.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500)), const SizedBox(height: 4), Text("${v.creatorName} • ${NumberFormat.compact().format(v.viewCount)} views", style: TextStyle(color: Colors.grey[400], fontSize: 12))])),
                    const Icon(Icons.more_vert, size: 18, color: Colors.grey),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}