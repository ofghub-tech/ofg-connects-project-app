// lib/logic/history_provider.dart
import 'package:appwrite/appwrite.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ofgconnects_mobile/api/appwrite_client.dart';
import 'package:ofgconnects_mobile/logic/auth_provider.dart';
import 'package:ofgconnects_mobile/models/video.dart';

String _getRelativeDate(DateTime date) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final yesterday = today.subtract(const Duration(days: 1));
  final checkDate = DateTime(date.year, date.month, date.day);

  if (checkDate == today) return 'Today';
  if (checkDate == yesterday) return 'Yesterday';
  
  const months = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
  return '${months[date.month - 1]} ${date.day}, ${date.year}';
}

class HistoryState {
  final Map<String, List<Video>> groupedHistory;
  final bool isLoading;

  HistoryState({this.groupedHistory = const {}, this.isLoading = false});
}

class HistoryNotifier extends StateNotifier<HistoryState> {
  HistoryNotifier(this.ref) : super(HistoryState());
  final Ref ref;

  Future<void> fetchHistory() async {
    print("--- FETCHING HISTORY ---");
    final user = ref.read(authProvider).user;
    if (user == null) {
      print("User not logged in. History skipped.");
      state = HistoryState(isLoading: false, groupedHistory: {});
      return;
    }

    state = HistoryState(isLoading: true, groupedHistory: state.groupedHistory);

    try {
      final databases = AppwriteClient.databases;
      
      // 1. Fetch History Logs
      // We use $createdAt (system attribute) which is always available and indexed by default
      final historyResponse = await databases.listDocuments(
        databaseId: AppwriteClient.databaseId,
        collectionId: AppwriteClient.collectionIdHistory,
        queries: [
          Query.equal('userId', user.$id),
          Query.orderDesc('\$createdAt'), 
          Query.limit(100), 
        ],
      );

      print("Found ${historyResponse.documents.length} history records.");

      if (historyResponse.documents.isEmpty) {
        state = HistoryState(isLoading: false, groupedHistory: {});
        return;
      }

      // 2. Extract Unique Video IDs
      final historyDocs = historyResponse.documents;
      final videoIds = historyDocs
          .map((doc) => doc.data['videoId'] as String)
          .toSet()
          .toList();

      print("Unique Video IDs to fetch: $videoIds");

      if (videoIds.isEmpty) {
        state = HistoryState(isLoading: false, groupedHistory: {});
        return;
      }

      // 3. Fetch Video Details
      final videosResponse = await databases.listDocuments(
        databaseId: AppwriteClient.databaseId,
        collectionId: AppwriteClient.collectionIdVideos,
        queries: [
          Query.equal('\$id', videoIds),
          Query.limit(100),
        ],
      );

      print("Fetched ${videosResponse.documents.length} video details.");

      final videoMap = {
        for (var v in videosResponse.documents) v.$id: Video.fromAppwrite(v)
      };

      // 4. Group by Date
      final Map<String, List<Video>> grouped = {};

      for (var historyDoc in historyDocs) {
        final videoId = historyDoc.data['videoId'];
        // Use system creation time
        final viewedAt = DateTime.parse(historyDoc.$createdAt);
        
        if (videoMap.containsKey(videoId)) {
          final video = videoMap[videoId]!;
          final groupKey = _getRelativeDate(viewedAt);

          if (!grouped.containsKey(groupKey)) {
            grouped[groupKey] = [];
          }
          
          // Prevent duplicates in the same day group
          if (!grouped[groupKey]!.any((v) => v.id == video.id)) {
             grouped[groupKey]!.add(video);
          }
        }
      }

      state = HistoryState(isLoading: false, groupedHistory: grouped);
      print("History loaded successfully.");

    } catch (e) {
      print("❌ Error fetching history: $e");
      state = HistoryState(isLoading: false, groupedHistory: {});
    }
  }
}

final historyProvider = StateNotifierProvider<HistoryNotifier, HistoryState>((ref) {
  return HistoryNotifier(ref);
});