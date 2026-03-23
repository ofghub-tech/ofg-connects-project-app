import 'package:appwrite/appwrite.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ofgconnects/api/appwrite_client.dart';
import 'package:ofgconnects/logic/video_provider.dart';
import 'package:ofgconnects/models/video.dart';
import 'package:ofgconnects/presentation/theme/ofg_ui.dart';

final kidsVideosProvider = FutureProvider<List<Video>>((ref) async {
  final response = await ref.read(databasesProvider).listDocuments(
    databaseId: AppwriteClient.databaseId,
    collectionId: AppwriteClient.collectionIdVideos,
    queries: [
      Query.equal('adminStatus', 'approved'),
      Query.equal('category', 'kids'),
      Query.orderDesc('\$createdAt'),
      Query.limit(40),
    ],
  );
  return response.documents.map(Video.fromAppwrite).toList();
});

class KidsPage extends ConsumerStatefulWidget {
  const KidsPage({super.key});

  @override
  ConsumerState<KidsPage> createState() => _KidsPageState();
}

class _KidsPageState extends ConsumerState<KidsPage> {
  final _searchController = TextEditingController();
  int _ageIndex = 0;
  static const _ageFilters = ['All Ages', '3-6', '7-10', '11-14'];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final kidsAsync = ref.watch(kidsVideosProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Kids')),
      body: Container(
        decoration: const BoxDecoration(gradient: OfgUi.appBackground),
        child: kidsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, _) => Center(child: Text('Failed to load kids videos: $err')),
          data: (list) {
            final q = _searchController.text.trim().toLowerCase();
            final shown = q.isEmpty
                ? list
                : list.where((v) {
                    return v.title.toLowerCase().contains(q) ||
                        v.creatorName.toLowerCase().contains(q);
                  }).toList();

            return Column(
              children: [
                _buildHeader(),
                _buildAgeFilters(),
                Expanded(
                  child: shown.isEmpty
                      ? const Center(
                          child: Text(
                            'No kids videos found.',
                            style: TextStyle(color: OfgUi.muted2),
                          ),
                        )
                      : GridView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            mainAxisSpacing: 10,
                            crossAxisSpacing: 10,
                            childAspectRatio: 9 / 16,
                          ),
                          itemCount: shown.length,
                          itemBuilder: (context, index) {
                            final video = shown[index];
                            return InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: () => context.push('/watch/${video.id}'),
                              child: Ink(
                                decoration: OfgUi.cardDecoration(radius: BorderRadius.circular(12)),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Stack(
                                    fit: StackFit.expand,
                                    children: [
                                      if (video.thumbnailUrl.isNotEmpty)
                                        Image.network(video.thumbnailUrl, fit: BoxFit.cover),
                                      Container(
                                        decoration: const BoxDecoration(
                                          gradient: LinearGradient(
                                            begin: Alignment.topCenter,
                                            end: Alignment.bottomCenter,
                                            colors: [Colors.transparent, Color(0xD9000000)],
                                          ),
                                        ),
                                      ),
                                      Positioned(
                                        top: 8,
                                        left: 8,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: const Color(0x552D5AA0),
                                            borderRadius: BorderRadius.circular(20),
                                            border: Border.all(
                                              color: const Color(0x663A6FC0),
                                            ),
                                          ),
                                          child: const Text(
                                            'KIDS',
                                            style: TextStyle(
                                              color: Color(0xFF7AABF0),
                                              fontSize: 9,
                                              fontWeight: FontWeight.w700,
                                              letterSpacing: 0.8,
                                            ),
                                          ),
                                        ),
                                      ),
                                      const Positioned(
                                        top: 8,
                                        right: 8,
                                        child: Icon(
                                          Icons.play_circle_fill_rounded,
                                          color: Colors.white,
                                        ),
                                      ),
                                      Positioned(
                                        left: 10,
                                        right: 10,
                                        bottom: 10,
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              video.title,
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 12,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                            const SizedBox(height: 3),
                                            Text(
                                              video.creatorName,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                color: Color(0xCCFFFFFF),
                                                fontSize: 10,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
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

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 14),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.06))),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF050F12), Color(0xFF081A08)],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Kids Corner',
            style: TextStyle(
              fontFamily: 'Cinzel',
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Bible stories, songs, and fun faith videos.',
            style: TextStyle(color: OfgUi.muted2, fontSize: 12),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _searchController,
            onChanged: (_) => setState(() {}),
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Search Bible stories, songs...',
              hintStyle: const TextStyle(color: OfgUi.muted),
              prefixIcon: const Icon(Icons.search_rounded, color: OfgUi.muted2),
              filled: true,
              fillColor: OfgUi.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(24),
                borderSide: const BorderSide(color: OfgUi.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(24),
                borderSide: const BorderSide(color: OfgUi.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(24),
                borderSide: const BorderSide(color: OfgUi.accent),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAgeFilters() {
    return SizedBox(
      height: 48,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        scrollDirection: Axis.horizontal,
        itemBuilder: (_, index) {
          final active = _ageIndex == index;
          return InkWell(
            onTap: () => setState(() => _ageIndex = index),
            borderRadius: BorderRadius.circular(20),
            child: Ink(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: active ? OfgUi.accent : OfgUi.surface2,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: active ? OfgUi.accentHover : OfgUi.border,
                ),
              ),
              child: Text(
                _ageFilters[index],
                style: TextStyle(
                  color: active ? Colors.white : OfgUi.muted2,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ),
          );
        },
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemCount: _ageFilters.length,
      ),
    );
  }
}

