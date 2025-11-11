// lib/api/appwrite_client.dart
import 'package:appwrite/appwrite.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppwriteClient {
  // --- Initialize Client, Account, etc. ---
  // This is the same as your JS file
  static final Client client = Client()
    ..setEndpoint(dotenv.env['APPWRITE_ENDPOINT']!)
    ..setProject(dotenv.env['APPWRITE_PROJECT_ID']!);

  static final Account account = Account(client);
  static final Databases databases = Databases(client);
  static final Storage storage = Storage(client);
  static final Functions functions = Functions(client);

  // --- Export IDs from .env ---
  // This mirrors the exports at the bottom of your JS file
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