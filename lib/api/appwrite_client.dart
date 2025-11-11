// lib/api/appwrite_client.dart
import 'package:appwrite/appwrite.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppwriteClient {
  // --- Read variables safely ---
  static final String? _endpoint = dotenv.env['APPWRITE_ENDPOINT'];
  static final String? _projectId = dotenv.env['APPWRITE_PROJECT_ID'];

  // --- Initialize Client, Account, etc. ---
  static final Client client = _initClient();

  // --- Private init function with checks ---
  static Client _initClient() {
    // Check if the variables were loaded
    if (_endpoint == null || _projectId == null || _endpoint!.isEmpty || _projectId!.isEmpty) {
      // Throw a helpful error instead of crashing with a null check
      throw Exception(
          'Failed to load environment variables. '
          'Make sure your .env file is in the root folder, '
          'added to pubspec.yaml assets, and contains '
          'APPWRITE_ENDPOINT and APPWRITE_PROJECT_ID.'
      );
    }
    
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
  // These are safer because they'll crash later, but the check above
  // should ensure the .env file was loaded.
  static final String databaseId = dotenv.env['APPWRITE_DATABASE_ID']!;
  static final String collectionIdVideos = dotenv.env['APPWRITE_COLLECTION_ID_VIDEOS']!;
  static final String bucketIdVideos = dotenv.env['APPWRITE_BUCKET_ID_VIDEOS']!;
  static final String bucketIdThumbnails = dotenv.env['APPWRITE_BUCKET_ID_THUMBNAILS']!;
  static final String collectionIdComments = dotenv.env['APPWRITE_COLLECTION_ID_COMMENTS']!;
  static final String collectionIdSubscriptions = dotenv.env['APPWRITE_COLLECTION_ID_SUBSCRIPTIONS']!;
  static final String collectionIdLikes = dotenv.env['APPWRITE_COLLECTION_ID_LIKES']!;
  static final String collectionIdBible = dotenv.env['APPWRITE_COLLECTION_ID_BIBLE']!;
  static final String collectionIdHistory = dotenv.env['APPWRITE_COLLECTION_ID_HISTORY']!;
  static final String collectionIdNotifications = dotenv.env['APPWRITE_COLLECTION_ID_NOTIFICATIONS']!;
  static final String collectionIdWatchLater = dotenv.env['APPWRITE_COLLECTION_ID_WATCH_LATER']!;
}