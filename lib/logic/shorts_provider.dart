// lib/logic/shorts_provider.dart
import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ofgconnects/api/appwrite_client.dart';
import 'package:ofgconnects/logic/video_provider.dart'; 
import 'package:ofgconnects/models/video.dart';

// 1. TRACKS ACTIVE VIDEO INDEX
final activeShortsIndexProvider = StateProvider<int>((ref) => 0);

// 2. [MOVED HERE] TRACK PLAY/PAUSE STATE
// This fixes the circular import error
final shortsPlayPauseProvider = StateProvider.family<bool, String>((ref, id) => true);

// 3. SHORTS LIST PROVIDER
final shortsListProvider = StateNotifierProvider<ShortsListNotifier, PaginationState<Video>>((ref) {
  return ShortsListNotifier(ref);
});

class ShortsListNotifier extends PaginatedListNotifier<Video> {
  ShortsListNotifier(super.ref);

  @override
  Video fromDocument(Document doc) => Video.fromAppwrite(doc);

  @override
  Future<List<Document>> fetchPage(List<String> queries) async {
    final response = await ref.read(databasesProvider).listDocuments(
      databaseId: AppwriteClient.databaseId,
      collectionId: AppwriteClient.collectionIdVideos,
      queries: [
        Query.equal('category', 'shorts'),
        Query.equal('adminStatus', 'approved'),
        Query.orderDesc('\$createdAt'),
        ...queries,
      ],
    );
    return response.documents;
  }

  Future<void> init(String? startWithVideoId) async {
    if (state.items.isNotEmpty && startWithVideoId == null) return;

    state = PaginationState(items: [], isLoadingMore: true, hasMore: true);

    if (startWithVideoId != null) {
      try {
        final doc = await ref.read(databasesProvider).getDocument(
          databaseId: AppwriteClient.databaseId,
          collectionId: AppwriteClient.collectionIdVideos,
          documentId: startWithVideoId,
        );
        
        final startVideo = Video.fromAppwrite(doc);

        state = PaginationState(
          items: [startVideo],
          isLoadingMore: true,
          hasMore: true,
        );
        
        final List<Document> nextDocs = await fetchPage([]); 
        final List<Video> nextVideos = nextDocs.map((d) => fromDocument(d)).toList();
        nextVideos.removeWhere((v) => v.id == startWithVideoId);

        state = state.copyWith(
          items: [startVideo, ...nextVideos],
          isLoadingMore: false,
        );

      } catch (e) {
        await fetchFirstBatch();
      }
    } else {
      await fetchFirstBatch();
    }
  }
}