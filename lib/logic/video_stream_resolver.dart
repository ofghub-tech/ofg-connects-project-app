import 'package:ofgconnects/api/appwrite_client.dart';
import 'package:ofgconnects/logic/data_saver.dart';
import 'package:ofgconnects/models/video.dart';

/// Ordered from low data usage to high quality for faster startup.
List<String> resolvePlayableVideoUrls(Video video) {
  final rawCandidates =
      kDataSaverEnabled
          ? <String?>[
            video.url144p,
            video.url240p,
            video.url360p,
            video.url480p,
            video.videoUrl,
          ]
          : <String?>[
            video.url360p,
            video.url480p,
            video.url720p,
            video.url1080p,
            video.videoUrl,
          ];

  final urls = <String>[];
  final seen = <String>{};

  for (final raw in rawCandidates) {
    final value = raw?.trim() ?? '';
    if (value.isEmpty) continue;

    final resolved =
        value.startsWith('http://') || value.startsWith('https://')
            ? value
            : AppwriteClient.storage
                .getFileView(
                  bucketId: AppwriteClient.bucketIdVideos,
                  fileId: value,
                )
                .toString();

    if (seen.add(resolved)) {
      urls.add(resolved);
    }
  }

  return urls;
}
