// lib/logic/interaction_provider.dart
import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ofgconnects/api/appwrite_client.dart';
import 'package:ofgconnects/logic/auth_provider.dart';

final databasesProvider = Provider<Databases>((ref) => Databases(AppwriteClient.client));

class InteractionLogic {
  final Ref ref;
  InteractionLogic(this.ref);
  Databases get _db => ref.read(databasesProvider);

  Future<void> logVideoView(String videoId) async {
    final user = ref.read(authProvider).user;
    if (user == null) return;
    try {
      final check = await _db.listDocuments(
        databaseId: AppwriteClient.databaseId,
        collectionId: AppwriteClient.collectionIdHistory,
        queries: [Query.equal('userId', user.$id), Query.equal('videoId', videoId), Query.limit(1)],
      );
      if (check.total == 0) {
        await _db.createDocument(
          databaseId: AppwriteClient.databaseId, 
          collectionId: AppwriteClient.collectionIdHistory,
          documentId: ID.unique(), 
          data: {'userId': user.$id, 'videoId': videoId},
        );
        await _incrementViewCount(videoId);
      }
    } catch (e) { debugPrint("View Log Error: $e"); }
  }

  Future<void> _incrementViewCount(String videoId) async {
    try {
      final doc = await _db.getDocument(
        databaseId: AppwriteClient.databaseId, 
        collectionId: AppwriteClient.collectionIdVideos, 
        documentId: videoId
      );
      final current = doc.data['viewCount'] ?? 0; 
      await _db.updateDocument(
        databaseId: AppwriteClient.databaseId, 
        collectionId: AppwriteClient.collectionIdVideos, 
        documentId: videoId, 
        data: {'viewCount': current + 1}
      );
    } catch (e) { debugPrint("View Increment Error: $e"); }
  }
}

final interactionProvider = Provider((ref) => InteractionLogic(ref));

// --- SAVE NOTIFIER (Watch Later) ---
final isSavedProvider = StateNotifierProvider.family<SaveNotifier, AsyncValue<bool>, String>((ref, videoId) {
  return SaveNotifier(ref, videoId);
});

class SaveNotifier extends StateNotifier<AsyncValue<bool>> {
  final Ref ref;
  final String videoId;
  SaveNotifier(this.ref, this.videoId) : super(const AsyncLoading()) { _init(); }
  Databases get _db => ref.read(databasesProvider);

  Future<void> _init() async {
    final user = ref.read(authProvider).user;
    if (user == null) { state = const AsyncData(false); return; }
    try {
      final res = await _db.listDocuments(
        databaseId: AppwriteClient.databaseId, 
        collectionId: AppwriteClient.collectionIdWatchLater,
        queries: [Query.equal('userId', user.$id), Query.equal('videoId', videoId), Query.limit(1)]
      );
      if (mounted) state = AsyncData(res.total > 0);
    } catch (e) { if (mounted) state = const AsyncData(false); }
  }

  Future<void> toggle() async {
    final user = ref.read(authProvider).user;
    if (user == null) return;
    final start = state.value ?? false;
    state = AsyncData(!start);
    try {
      final check = await _db.listDocuments(
        databaseId: AppwriteClient.databaseId, 
        collectionId: AppwriteClient.collectionIdWatchLater,
        queries: [Query.equal('userId', user.$id), Query.equal('videoId', videoId), Query.limit(1)]
      );
      if (check.total > 0) {
        await _db.deleteDocument(
          databaseId: AppwriteClient.databaseId, 
          collectionId: AppwriteClient.collectionIdWatchLater, 
          documentId: check.documents.first.$id
        );
      } else {
        await _db.createDocument(
          databaseId: AppwriteClient.databaseId, 
          collectionId: AppwriteClient.collectionIdWatchLater, 
          documentId: ID.unique(), 
          data: {'userId': user.$id, 'videoId': videoId}
        );
      }
    } catch (e) { if (mounted) state = AsyncData(start); }
  }
}