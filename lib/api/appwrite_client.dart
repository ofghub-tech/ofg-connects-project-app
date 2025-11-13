// lib/api/appwrite_client.dart
import 'package:appwrite/appwrite.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppwriteClient {
  // --- Read variables safely ---
  static final String? _endpoint = dotenv.env['APPWRITE_ENDPOINT'];
  static final String? _projectId = dotenv.env['APPWRITE_PROJECT_ID'];

  // --- THIS IS THE FIX ---
  // We will also read all other IDs here to check them in _initClient
  static final String? _databaseId = dotenv.env['APPWRITE_DATABASE_ID'];
  static final String? _collectionIdVideos = dotenv.env['APPWRITE_COLLECTION_ID_VIDEOS'];
  static final String? _bucketIdVideos = dotenv.env['APPWRITE_BUCKET_ID_VIDEOS'];
  static final String? _bucketIdThumbnails = dotenv.env['APPWRITE_BUCKET_ID_THUMBNAILS'];
  static final String? _collectionIdComments = dotenv.env['APPWRITE_COLLECTION_ID_COMMENTS'];
  static final String? _collectionIdSubscriptions = dotenv.env['APPWRITE_COLLECTION_ID_SUBSCRIPTIONS'];
  static final String? _collectionIdLikes = dotenv.env['APPWRITE_COLLECTION_ID_LIKES'];
  static final String? _collectionIdBible = dotenv.env['APPWRITE_COLLECTION_ID_BIBLE'];
  static final String? _collectionIdHistory = dotenv.env['APPWRITE_COLLECTION_ID_HISTORY'];
  static final String? _collectionIdNotifications = dotenv.env['APPWRITE_COLLECTION_ID_NOTIFICATIONS'];
  static final String? _collectionIdWatchLater = dotenv.env['APPWRITE_COLLECTION_ID_WATCH_LATER'];
  // --- END FIX ---


  // --- Initialize Client, Account, etc. ---
  static final Client client = _initClient();

  // --- Private init function with checks ---
  static Client _initClient() {
    // --- THIS IS THE FIX ---
    // A complete check for all required environment variables

    // 1. Create a map of all variables to check
    final envVars = {
      'APPWRITE_ENDPOINT': _endpoint,
      'APPWRITE_PROJECT_ID': _projectId,
      'APPWRITE_DATABASE_ID': _databaseId,
      'APPWRITE_COLLECTION_ID_VIDEOS': _collectionIdVideos,
      'APPWRITE_BUCKET_ID_VIDEOS': _bucketIdVideos,
      'APPWRITE_BUCKET_ID_THUMBNAILS': _bucketIdThumbnails,
      'APPWRITE_COLLECTION_ID_COMMENTS': _collectionIdComments,
      'APPWRITE_COLLECTION_ID_SUBSCRIPTIONS': _collectionIdSubscriptions,
      'APPWRITE_COLLECTION_ID_LIKES': _collectionIdLikes,
      'APPWRITE_COLLECTION_ID_BIBLE': _collectionIdBible,
      'APPWRITE_COLLECTION_ID_HISTORY': _collectionIdHistory,
      'APPWRITE_COLLECTION_ID_NOTIFICATIONS': _collectionIdNotifications,
      'APPWRITE_COLLECTION_ID_WATCH_LATER': _collectionIdWatchLater,
    };

    // 2. Find any variables that are null or empty
    final missingVars = envVars.entries
        .where((entry) => entry.value == null || entry.value!.isEmpty)
        .map((entry) => entry.key)
        .toList();

    // 3. If any are missing, throw a single, helpful error
    if (missingVars.isNotEmpty) {
      throw Exception(
          'Failed to load environment variables. '
          'Make sure your .env file is in the root folder, '
          'added to pubspec.yaml assets, and contains '
          'the following missing keys: ${missingVars.join(', ')}'
      );
    }
    // --- END FIX ---
    
    // If checks pass, create the client
    return Client()
      ..setEndpoint(_endpoint!)
      ..setProject(_projectId!);
  }

  static final Account account = Account(client);
  static final Databases databases = Databases(client);
  static final Storage storage = Storage(client);
  static final Functions functions = Functions(client);

  // --- Export IDs from .env ---
  // Now we can safely use the '!' operator because _initClient checked them
  static final String databaseId = _databaseId!;
  static final String collectionIdVideos = _collectionIdVideos!;
  static final String bucketIdVideos = _bucketIdVideos!;
  static final String bucketIdThumbnails = _bucketIdThumbnails!;
  static final String collectionIdComments = _collectionIdComments!;
  static final String collectionIdSubscriptions = _collectionIdSubscriptions!;
  static final String collectionIdLikes = _collectionIdLikes!;
  static final String collectionIdBible = _collectionIdBible!;
  static final String collectionIdHistory = _collectionIdHistory!;
  static final String collectionIdNotifications = _collectionIdNotifications!;
  static final String collectionIdWatchLater = _collectionIdWatchLater!;
}