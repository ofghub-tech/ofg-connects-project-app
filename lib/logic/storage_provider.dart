import 'dart:typed_data';
import 'package:flutter/services.dart'; // Needed for NetworkAssetBundle to fetch images from URLs
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ofgconnects_mobile/api/appwrite_client.dart';

// This provider is simple and just gives us the Appwrite Storage instance
final storageProvider = Provider((ref) => AppwriteClient.storage);

// 1. Thumbnail provider
// Since your database has a full URL, we fetch the image bytes directly from that URL.
final thumbnailProvider = FutureProvider.family<Uint8List, String>((ref, url) async {
  if (url.isEmpty) {
    return Uint8List(0);
  }

  try {
    // Use Flutter's built-in helper to load data from a network URL
    final ByteData data = await NetworkAssetBundle(Uri.parse(url)).load("");
    return data.buffer.asUint8List();
  } catch (e) {
    print('Error getting thumbnail from URL $url: $e');
    return Uint8List(0); // Return empty bytes on error so UI shows placeholder
  }
});

// 2. Provider for Video STREAMING
// Since your database has the full URL, we just return it to the player.
final videoStreamUrlProvider = FutureProvider.family<String, String>((ref, url) async {
  if (url.isEmpty) {
    throw Exception('Video URL is empty');
  }

  // The 'url' passed here is the full link from your Appwrite database.
  // We just return it directly so the VideoPlayer can stream it.
  return url; 
});