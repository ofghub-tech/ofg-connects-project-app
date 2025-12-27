// lib/logic/interaction_provider.dart
import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ofgconnects_mobile/api/appwrite_client.dart';
import 'package:ofgconnects_mobile/logic/auth_provider.dart';
import 'package:ofgconnects_mobile/logic/video_provider.dart';

// --- 1. VIEW LOGIC (Kept simple) ---
final interactionProvider = Provider((ref) => InteractionLogic(ref));

class InteractionLogic {
  final Ref ref;
  final Databases _db = AppwriteClient.databases;
  InteractionLogic(this.ref);

  Future<void> logVideoView(String videoId) async {
    final user = ref.read(authProvider).user;
    if (user == null) return;
    try {
      // Check if already viewed
      final check = await _db.listDocuments(
        databaseId: AppwriteClient.databaseId,
        collectionId: AppwriteClient.collectionIdHistory,
        queries: [Query.equal('userId', user.$id), Query.equal('videoId', videoId), Query.limit(1)],
      );

      if (check.total == 0) {
        // Create History Record
        await _db.createDocument(
          databaseId: AppwriteClient.databaseId,
          collectionId: AppwriteClient.collectionIdHistory,
          documentId: ID.unique(),
          data: {'userId': user.$id, 'videoId': videoId},
        );
        // Increment View Count
        _incrementViewCount(videoId);
      }
    } catch (e) {
      print("View Log Error: $e");
    }
  }

  Future<void> _incrementViewCount(String videoId) async {
    try {
      final doc = await _db.getDocument(
        databaseId: AppwriteClient.databaseId,
        collectionId: AppwriteClient.collectionIdVideos,
        documentId: videoId
      );
      final current = doc.data['view_count'] ?? 0;
      await _db.updateDocument(
        databaseId: AppwriteClient.databaseId,
        collectionId: AppwriteClient.collectionIdVideos,
        documentId: videoId,
        data: {'view_count': current + 1},
      );
      // Refresh video details silently
      ref.invalidate(videoDetailsProvider(videoId));
    } catch (_) {}
  }
}

// --- 2. OPTIMISTIC LIKE NOTIFIER ---
final isLikedProvider = StateNotifierProvider.family<LikeNotifier, AsyncValue<bool>, String>((ref, videoId) {
  return LikeNotifier(ref, videoId);
});

class LikeNotifier extends StateNotifier<AsyncValue<bool>> {
  final Ref ref;
  final String videoId;
  final Databases _db = AppwriteClient.databases;

  LikeNotifier(this.ref, this.videoId) : super(const AsyncLoading()) {
    _init();
  }

  Future<void> _init() async {
    final user = ref.read(authProvider).user;
    if (user == null) {
      state = const AsyncData(false);
      return;
    }
    try {
      final res = await _db.listDocuments(
        databaseId: AppwriteClient.databaseId,
        collectionId: AppwriteClient.collectionIdLikes,
        queries: [Query.equal('userId', user.$id), Query.equal('videoId', videoId), Query.limit(1)]
      );
      state = AsyncData(res.total > 0);
    } catch (e) {
      state = const AsyncData(false);
    }
  }

  Future<void> toggle() async {
    final user = ref.read(authProvider).user;
    if (user == null) return;

    // 1. OPTIMISTIC UPDATE (React 1st)
    final bool currentStatus = state.value ?? false;
    state = AsyncData(!currentStatus); 

    // 2. SERVER WORK (Work Next)
    try {
      final check = await _db.listDocuments(
        databaseId: AppwriteClient.databaseId,
        collectionId: AppwriteClient.collectionIdLikes,
        queries: [Query.equal('userId', user.$id), Query.equal('videoId', videoId), Query.limit(1)],
      );

      if (check.total > 0) {
        // Unlike on Server
        await _db.deleteDocument(
          databaseId: AppwriteClient.databaseId,
          collectionId: AppwriteClient.collectionIdLikes,
          documentId: check.documents.first.$id,
        );
        _updateVideoStat(videoId, -1);
      } else {
        // Like on Server
        await _db.createDocument(
          databaseId: AppwriteClient.databaseId,
          collectionId: AppwriteClient.collectionIdLikes,
          documentId: ID.unique(),
          data: {'userId': user.$id, 'videoId': videoId, 'type': 'video'},
        );
        _updateVideoStat(videoId, 1);
      }
    } catch (e) {
      // 3. REVERT IF ERROR
      print("Like failed: $e");
      state = AsyncData(currentStatus); 
    }
  }

  Future<void> _updateVideoStat(String videoId, int change) async {
    try {
      final doc = await _db.getDocument(databaseId: AppwriteClient.databaseId, collectionId: AppwriteClient.collectionIdVideos, documentId: videoId);
      final current = doc.data['likeCount'] ?? 0;
      int newCount = current + change;
      if (newCount < 0) newCount = 0;
      await _db.updateDocument(databaseId: AppwriteClient.databaseId, collectionId: AppwriteClient.collectionIdVideos, documentId: videoId, data: {'likeCount': newCount});
      ref.invalidate(videoDetailsProvider(videoId)); // Refresh count
    } catch (_) {}
  }
}

// --- 3. OPTIMISTIC SAVE NOTIFIER ---
final isSavedProvider = StateNotifierProvider.family<SaveNotifier, AsyncValue<bool>, String>((ref, videoId) {
  return SaveNotifier(ref, videoId);
});

class SaveNotifier extends StateNotifier<AsyncValue<bool>> {
  final Ref ref;
  final String videoId;
  final Databases _db = AppwriteClient.databases;

  SaveNotifier(this.ref, this.videoId) : super(const AsyncLoading()) {
    _init();
  }

  Future<void> _init() async {
    final user = ref.read(authProvider).user;
    if (user == null) { state = const AsyncData(false); return; }
    try {
      final res = await _db.listDocuments(
        databaseId: AppwriteClient.databaseId,
        collectionId: AppwriteClient.collectionIdWatchLater,
        queries: [Query.equal('userId', user.$id), Query.equal('videoId', videoId), Query.limit(1)]
      );
      state = AsyncData(res.total > 0);
    } catch (e) { state = const AsyncData(false); }
  }

  Future<void> toggle() async {
    final user = ref.read(authProvider).user;
    if (user == null) return;

    // 1. OPTIMISTIC UPDATE
    final currentStatus = state.value ?? false;
    state = AsyncData(!currentStatus);

    // 2. SERVER WORK
    try {
      final check = await _db.listDocuments(
        databaseId: AppwriteClient.databaseId,
        collectionId: AppwriteClient.collectionIdWatchLater,
        queries: [Query.equal('userId', user.$id), Query.equal('videoId', videoId), Query.limit(1)],
      );

      if (check.total > 0) {
        await _db.deleteDocument(
          databaseId: AppwriteClient.databaseId,
          collectionId: AppwriteClient.collectionIdWatchLater,
          documentId: check.documents.first.$id,
        );
      } else {
        await _db.createDocument(
          databaseId: AppwriteClient.databaseId,
          collectionId: AppwriteClient.collectionIdWatchLater,
          documentId: ID.unique(),
          data: {'userId': user.$id, 'videoId': videoId},
        );
      }
      ref.invalidate(paginatedWatchLaterProvider);
    } catch (e) {
      state = AsyncData(currentStatus); // Revert
    }
  }
}