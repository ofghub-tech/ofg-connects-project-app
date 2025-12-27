import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ofgconnects_mobile/api/appwrite_client.dart';
import 'package:ofgconnects_mobile/logic/video_provider.dart'; // Imports PaginatedListNotifier & databasesProvider
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

  // IMPLEMENTATION 1: Convert Appwrite Document to Video Model
  @override
  Video fromDocument(Document doc) => Video.fromAppwrite(doc);

  // IMPLEMENTATION 2: Fetch Logic
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

  // EXTRA: Handle Deep Linking (Start with a specific video)
  Future<void> init(String? startWithVideoId) async {
    // If we already have items and aren't forcing a specific start, do nothing
    if (state.items.isNotEmpty && startWithVideoId == null) return;

    if (startWithVideoId != null) {
      try {
        // Fetch the specific video first
        final doc = await ref.read(databasesProvider).getDocument(
          databaseId: AppwriteClient.databaseId,
          collectionId: AppwriteClient.collectionIdVideos,
          documentId: startWithVideoId,
        );
        
        // Reset state with this single video
        state = PaginationState(
          items: [Video.fromAppwrite(doc)],
          isLoadingMore: true, // Mark loading so we can fetch the rest next
          hasMore: true,
        );
        
        // Fetch the rest of the batch normally
        await fetchFirstBatch(); 
      } catch (e) {
        print("Error fetching deep linked short: $e");
        fetchFirstBatch();
      }
    } else {
      fetchFirstBatch();
    }
  }
}