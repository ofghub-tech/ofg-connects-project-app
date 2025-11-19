// lib/logic/storage_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ofgconnects_mobile/api/appwrite_client.dart';

// This provider is simple and just gives us the Appwrite Storage instance.
// It is kept for future use (e.g., if you need to delete files or upload directly).
final storageProvider = Provider((ref) => AppwriteClient.storage);

// NOTE:
// The 'thumbnailProvider' and 'videoStreamUrlProvider' have been removed.
//
// We now use the direct URLs provided by the Video model (video.thumbnailUrl, video.videoUrl)
// directly in the UI widgets (Image.network, VideoPlayer.network).
// This leverages Flutter's built-in caching engine for much faster loading and scrolling.