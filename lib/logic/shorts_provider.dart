import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ofgconnects_mobile/api/appwrite_client.dart';
import 'package:ofgconnects_mobile/logic/video_provider.dart'; 
import 'package:ofgconnects_mobile/models/video.dart';

// 1. TRACKS WHICH VIDEO IS CURRENTLY PLAYING
final activeShortsIndexProvider = StateProvider<int>((ref) => 0);

// 2. PROVIDER FOR THE LIST OF SHORTS
final shortsListProvider = StateNotifierProvider<ShortsListNotifier, PaginationState<Video>>((ref) {
  return ShortsListNotifier(ref);
});

// 3. THE NOTIFIER CLASS
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

  // EXTRA: Handle Deep Linking
  Future<void> init(String? startWithVideoId) async {
    // 1. Safety Check
    if (state.items.isNotEmpty && startWithVideoId == null) return;

    // 2. [FIXED] Use 'isLoadingMore' instead of 'isLoading'
    // This triggers the spinner because your UI checks: if items.isEmpty && isLoadingMore -> Show Spinner
    state = PaginationState(
      items: [], 
      isLoadingMore: true, // <--- CHANGED THIS
      hasMore: true
    );

    if (startWithVideoId != null) {
      try {
        // A. Fetch the specific deep-linked video first
        final doc = await ref.read(databasesProvider).getDocument(
          databaseId: AppwriteClient.databaseId,
          collectionId: AppwriteClient.collectionIdVideos,
          documentId: startWithVideoId,
        );
        
        final startVideo = Video.fromAppwrite(doc);

        // B. Set state with ONLY this video initially
        state = PaginationState(
          items: [startVideo],
          isLoadingMore: true, // <--- CHANGED THIS (Keep true while fetching batch)
          hasMore: true,
        );
        
        // C. Manually fetch the standard feed 
        final List<Document> nextDocs = await fetchPage([]); 
        final List<Video> nextVideos = nextDocs.map((d) => fromDocument(d)).toList();

        // D. Remove duplicates
        nextVideos.removeWhere((v) => v.id == startWithVideoId);

        // E. Append and update state
        state = state.copyWith(
          items: [startVideo, ...nextVideos],
          isLoadingMore: false, // <--- Stop loading
        );

      } catch (e) {
        print("Error fetching deep linked short: $e");
        await fetchFirstBatch();
      }
    } else {
      await fetchFirstBatch();
    }
  }
}