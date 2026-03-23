import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ofgconnects/logic/history_provider.dart';
import 'package:ofgconnects/models/video.dart';
import 'package:ofgconnects/presentation/theme/ofg_ui.dart';

class HistoryPage extends ConsumerStatefulWidget {
  const HistoryPage({super.key});

  @override
  ConsumerState<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends ConsumerState<HistoryPage> {
  int _activeTab = 0;
  static const _tabs = ['All', 'Videos', 'Shorts'];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(historyProvider.notifier).fetchHistory();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(historyProvider);
    final grouped = state.groupedHistory;
    final allVideos = grouped.values.expand((v) => v).toList();
    final videosOnly = allVideos.where((v) => v.category != 'shorts').length;
    final shortsOnly = allVideos.where((v) => v.category == 'shorts').length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('History'),
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: OfgUi.appBackground),
        child: state.isLoading
            ? const Center(child: CircularProgressIndicator())
            : grouped.isEmpty
                ? const Center(
                    child: Text(
                      'Your watch history is empty.',
                      style: TextStyle(color: OfgUi.muted2),
                    ),
                  )
                : Column(
                    children: [
                      _buildHeader(),
                      _buildTabs(),
                      _buildStats(
                        total: allVideos.length,
                        videos: videosOnly,
                        shorts: shortsOnly,
                      ),
                      Expanded(
                        child: ListView(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                          children: grouped.entries.map((entry) {
                            final filtered = _filterForTab(entry.value);
                            if (filtered.isEmpty) return const SizedBox.shrink();
                            return _buildDayGroup(entry.key, filtered);
                          }).toList(),
                        ),
                      ),
                    ],
                  ),
      ),
    );
  }

  List<Video> _filterForTab(List<Video> list) {
    if (_activeTab == 1) return list.where((v) => v.category != 'shorts').toList();
    if (_activeTab == 2) return list.where((v) => v.category == 'shorts').toList();
    return list;
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 10),
      child: Row(
        children: [
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Watch History',
                  style: TextStyle(
                    fontFamily: 'Cinzel',
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 2),
                Text('Resume where you left off', style: TextStyle(color: OfgUi.muted2)),
              ],
            ),
          ),
          OutlinedButton(
            onPressed: () => ref.read(historyProvider.notifier).fetchHistory(),
            style: OutlinedButton.styleFrom(
              foregroundColor: OfgUi.muted2,
              side: const BorderSide(color: OfgUi.border),
              backgroundColor: OfgUi.surface2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Refresh'),
          ),
        ],
      ),
    );
  }

  Widget _buildTabs() {
    return SizedBox(
      height: 46,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemBuilder: (_, idx) {
          final active = _activeTab == idx;
          return InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () => setState(() => _activeTab = idx),
            child: Ink(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                color: active ? OfgUi.accent : OfgUi.surface2,
                border: Border.all(color: active ? OfgUi.accentHover : OfgUi.border),
              ),
              child: Text(
                _tabs[idx],
                style: TextStyle(
                  color: active ? Colors.white : OfgUi.muted2,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          );
        },
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemCount: _tabs.length,
      ),
    );
  }

  Widget _buildStats({required int total, required int videos, required int shorts}) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(child: _StatCard(label: 'Total', value: '$total')),
          const SizedBox(width: 8),
          Expanded(child: _StatCard(label: 'Videos', value: '$videos')),
          const SizedBox(width: 8),
          Expanded(child: _StatCard(label: 'Shorts', value: '$shorts')),
        ],
      ),
    );
  }

  Widget _buildDayGroup(String dateLabel, List<Video> items) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 2, bottom: 10),
            child: Text(
              dateLabel.toUpperCase(),
              style: const TextStyle(
                color: OfgUi.muted,
                fontSize: 10,
                letterSpacing: 1.2,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          ...items.map((video) => _HistoryRow(video: video)),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  const _StatCard({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: OfgUi.cardDecoration(),
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              fontFamily: 'Cinzel',
              color: OfgUi.accent,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              color: OfgUi.muted,
              fontSize: 10,
              letterSpacing: 1,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoryRow extends StatelessWidget {
  final Video video;
  const _HistoryRow({required this.video});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        if (video.category == 'shorts') {
          context.push('/shorts?id=${video.id}');
        } else {
          context.push('/watch/${video.id}');
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(8),
        decoration: OfgUi.cardDecoration(),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 92,
                height: 56,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (video.thumbnailUrl.isNotEmpty)
                      Image.network(video.thumbnailUrl, fit: BoxFit.cover)
                    else
                      Container(color: OfgUi.surface2),
                    Positioned(
                      bottom: 4,
                      right: 5,
                      child: Container(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                        color: const Color(0xCC000000),
                        child: Text(
                          video.category == 'shorts' ? 'SHORT' : 'VIDEO',
                          style: const TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    video.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    video.creatorName,
                    style: const TextStyle(color: OfgUi.muted2, fontSize: 11),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

