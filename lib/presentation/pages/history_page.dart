import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ofgconnects/logic/history_provider.dart';
import 'package:ofgconnects/presentation/widgets/video_card.dart';
import 'package:ofgconnects/presentation/widgets/shorts_card.dart';
import 'package:ofgconnects/presentation/widgets/animate_in_effect.dart';

class HistoryPage extends ConsumerStatefulWidget {
  const HistoryPage({super.key});

  @override
  ConsumerState<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends ConsumerState<HistoryPage> {
  @override
  void initState() {
    super.initState();
    // Fetch history when page mounts
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(historyProvider.notifier).fetchHistory();
    });
  }

  @override
  Widget build(BuildContext context) {
    final historyState = ref.watch(historyProvider);
    final groupedData = historyState.groupedHistory;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Watch History'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      extendBodyBehindAppBar: true,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Theme.of(context).scaffoldBackgroundColor, Colors.black],
          ),
        ),
        child: historyState.isLoading
            ? const Center(child: CircularProgressIndicator())
            : groupedData.isEmpty
                ? const Center(child: Text("Your watch history is empty.", style: TextStyle(color: Colors.grey)))
                : ListView.builder(
                    padding: const EdgeInsets.only(top: 100, bottom: 20),
                    itemCount: groupedData.keys.length,
                    itemBuilder: (context, index) {
                      final dateKey = groupedData.keys.elementAt(index);
                      final videos = groupedData[dateKey]!;

                      // Separate Shorts and Normal Videos like your React code
                      final shorts = videos.where((v) => v.category == 'shorts').toList();
                      final normalVideos = videos.where((v) => v.category != 'shorts').toList();

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Date Header
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                            child: Text(
                              dateKey,
                              style: const TextStyle(
                                fontSize: 20, 
                                fontWeight: FontWeight.bold, 
                                color: Colors.white
                              ),
                            ),
                          ),

                          // Shorts Section (Horizontal Scroll)
                          if (shorts.isNotEmpty) ...[
                            Padding(
                              padding: const EdgeInsets.only(left: 16, bottom: 8),
                              child: Row(
                                children: const [
                                  Icon(Icons.bolt, color: Colors.blueAccent, size: 18),
                                  SizedBox(width: 4),
                                  Text("Shorts", style: TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                            SizedBox(
                              height: 240,
                              child: ListView.builder(
                                scrollDirection: Axis.horizontal,
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                itemCount: shorts.length,
                                itemBuilder: (ctx, i) {
                                  return Padding(
                                    padding: const EdgeInsets.only(right: 8.0),
                                    child: SizedBox(
                                      width: 140,
                                      child: ShortsCard(video: shorts[i]),
                                    ),
                                  );
                                },
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],

                          // Normal Videos (Vertical List)
                          if (normalVideos.isNotEmpty)
                            ...normalVideos.map((video) => 
                              AnimateInEffect(
                                index: index, // Simple animation trigger
                                child: VideoCard(video: video)
                              )
                            ).toList(),
                            
                          const Divider(color: Colors.white10, height: 30),
                        ],
                      );
                    },
                  ),
      ),
    );
  }
}