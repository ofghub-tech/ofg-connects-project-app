// lib/logic/search_provider.dart
import 'package:appwrite/appwrite.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ofgconnects/api/appwrite_client.dart';
import 'package:ofgconnects/models/video.dart';

// 1. This provider holds the current search term (like React state)
final searchQueryProvider = StateProvider<String>((ref) => '');

// 2. This provider automatically re-fetches when the query changes
final searchResultsProvider = FutureProvider<List<Video>>((ref) async {
  final query = ref.watch(searchQueryProvider);

  // Don't search if the query is empty
  if (query.isEmpty) {
    return [];
  }

  final databases = AppwriteClient.databases;

  // This logic is identical to your SearchPage.js useEffect
  // It searches title, tags, and username.
  final response = await databases.listDocuments(
    databaseId: AppwriteClient.databaseId,
    collectionId: AppwriteClient.collectionIdVideos,
    queries: [
      Query.search('title', query),
      Query.search('tags', query),
      Query.search('username', query),
      Query.equal('adminStatus', 'approved'), // --- ADDED: Filter Approved ---
      Query.limit(50), 
    ],
  );

  return response.documents.map((doc) => Video.fromAppwrite(doc)).toList();
});