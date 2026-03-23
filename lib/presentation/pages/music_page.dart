import 'package:appwrite/appwrite.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ofgconnects/api/appwrite_client.dart';
import 'package:ofgconnects/logic/video_provider.dart';
import 'package:ofgconnects/models/video.dart';
import 'package:ofgconnects/presentation/theme/ofg_ui.dart';

final musicVideosProvider = FutureProvider<List<Video>>((ref) async {
  final response = await ref.read(databasesProvider).listDocuments(
    databaseId: AppwriteClient.databaseId,
    collectionId: AppwriteClient.collectionIdVideos,
    queries: [
      Query.equal('adminStatus', 'approved'),
      Query.equal('category', ['music', 'song', 'songs']),
      Query.orderDesc('\$createdAt'),
      Query.limit(40),
    ],
  );
  return response.documents.map(Video.fromAppwrite).toList();
});

class MusicPage extends ConsumerStatefulWidget {
  const MusicPage({super.key});

  @override
  ConsumerState<MusicPage> createState() => _MusicPageState();
}

class _MusicPageState extends ConsumerState<MusicPage> {
  int _activeTab = 0;
  int _activeSong = -1;
  bool _playing = false;

  @override
  Widget build(BuildContext context) {
    final musicAsync = ref.watch(musicVideosProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Music'),
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: OfgUi.appBackground),
        child: musicAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, _) => Center(child: Text('Failed to load music: $err')),
          data: (songs) {
            final shown = _activeTab == 0
                ? songs
                : songs.where((e) => e.tags.any((t) => t.toLowerCase().contains('worship'))).toList();
            return Column(
              children: [
                _buildNowPlayingHero(shown),
                Container(
                  decoration: const BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: OfgUi.border),
                      top: BorderSide(color: OfgUi.border),
                    ),
                  ),
                  child: Row(
                    children: [
                      _tabButton('Tracks', 0),
                      _tabButton('Worship', 1),
                    ],
                  ),
                ),
                Expanded(
                  child: shown.isEmpty
                      ? const Center(
                          child: Text(
                            'No music tracks yet.',
                            style: TextStyle(color: OfgUi.muted2),
                          ),
                        )
                      : ListView.separated(
                          itemCount: shown.length,
                          separatorBuilder: (_, __) =>
                              Divider(color: Colors.white.withOpacity(0.06), height: 1),
                          itemBuilder: (context, index) {
                            final song = shown[index];
                            final playing = _playing && _activeSong == index;
                            return InkWell(
                              onTap: () {
                                setState(() {
                                  _activeSong = index;
                                  _playing = true;
                                });
                              },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                child: Row(
                                  children: [
                                    SizedBox(
                                      width: 22,
                                      child: Text(
                                        '${index + 1}',
                                        style: const TextStyle(
                                          color: OfgUi.muted,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      width: 42,
                                      height: 42,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(8),
                                        gradient: const LinearGradient(
                                          colors: [Color(0xFF0D2040), Color(0xFF2040A0)],
                                        ),
                                      ),
                                      child: const Icon(
                                        Icons.music_note_rounded,
                                        color: Colors.white,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            song.title,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              color: playing ? OfgUi.accent : Colors.white,
                                              fontWeight: FontWeight.w700,
                                              fontSize: 13,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            song.creatorName,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              color: OfgUi.muted2,
                                              fontSize: 11,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    if (playing)
                                      const Icon(Icons.equalizer_rounded, color: OfgUi.accent)
                                    else
                                      const Icon(Icons.favorite_border_rounded, color: OfgUi.muted),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildNowPlayingHero(List<Video> songs) {
    final hasSong = songs.isNotEmpty;
    final current = hasSong ? songs[_activeSong >= 0 ? _activeSong : 0] : null;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 22, 16, 18),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.06))),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF060E1C), OfgUi.bg],
        ),
      ),
      child: Column(
        children: [
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [Color(0xFF0D2040), Color(0xFF2040A0)],
              ),
              border: Border.all(color: const Color(0x663A6FC0), width: 3),
            ),
            child: const Icon(Icons.album_rounded, color: Colors.white, size: 30),
          ),
          const SizedBox(height: 12),
          const Text(
            'NOW PLAYING',
            style: TextStyle(
              color: OfgUi.accent,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            current?.title ?? 'No track selected',
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontFamily: 'Cinzel',
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            current?.creatorName ?? 'OFG Music',
            style: const TextStyle(color: OfgUi.muted2, fontSize: 12),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _musicControlButton(Icons.skip_previous_rounded),
              const SizedBox(width: 12),
              _musicControlButton(
                _playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                active: true,
                onTap: () => setState(() => _playing = !_playing),
              ),
              const SizedBox(width: 12),
              _musicControlButton(Icons.skip_next_rounded),
            ],
          ),
        ],
      ),
    );
  }

  Widget _musicControlButton(IconData icon, {bool active = false, VoidCallback? onTap}) {
    return InkWell(
      borderRadius: BorderRadius.circular(32),
      onTap: onTap ?? () {},
      child: Ink(
        width: active ? 52 : 40,
        height: active ? 52 : 40,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: active ? OfgUi.accent : OfgUi.surface2,
        ),
        child: Icon(icon, color: Colors.white),
      ),
    );
  }

  Widget _tabButton(String title, int tabIndex) {
    final active = _activeTab == tabIndex;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _activeTab = tabIndex),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 13),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: active ? OfgUi.accent : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: active ? OfgUi.accent : OfgUi.muted2,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }
}

