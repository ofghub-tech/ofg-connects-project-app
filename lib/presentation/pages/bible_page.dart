// lib/presentation/pages/bible_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ofgconnects_mobile/logic/bible_provider.dart';

class BiblePage extends ConsumerWidget {
  const BiblePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bibleState = ref.watch(bibleStateProvider);
    final versesAsync = ref.watch(bibleVersesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Holy Bible'),
        actions: [
          // Chapter Selection Dropdown
          DropdownButton<int>(
            value: bibleState.selectedChapter,
            dropdownColor: Colors.grey[900],
            underline: Container(),
            icon: const Icon(Icons.arrow_drop_down, color: Colors.white),
            style: const TextStyle(color: Colors.white, fontSize: 16),
            items: List.generate(150, (index) => index + 1).map((i) {
              return DropdownMenuItem(value: i, child: Text('Ch $i'));
            }).toList(),
            onChanged: (val) {
              if (val != null) {
                ref.read(bibleStateProvider.notifier).setChapter(val);
              }
            },
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: Column(
        children: [
          // --- Top Bar: Book Selection ---
          Container(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                const Text("Book: ", style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButton<String>(
                    isExpanded: true,
                    value: bibleBooksList.contains(bibleState.selectedBook) 
                        ? bibleState.selectedBook 
                        : bibleBooksList.first,
                    items: bibleBooksList.map((book) {
                      return DropdownMenuItem(value: book, child: Text(book));
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        ref.read(bibleStateProvider.notifier).setBook(val);
                      }
                    },
                  ),
                ),
              ],
            ),
          ),

          // --- Verses List ---
          Expanded(
            child: versesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, s) => Center(child: Text('Error: $e')),
              data: (verses) {
                if (verses.isEmpty) {
                  return const Center(child: Text('No verses found for this chapter.'));
                }
                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: verses.length + 1, // +1 for navigation buttons at bottom
                  itemBuilder: (context, index) {
                    if (index == verses.length) {
                      // Bottom Navigation Buttons
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            if (bibleState.selectedChapter > 1)
                              OutlinedButton.icon(
                                onPressed: () => ref.read(bibleStateProvider.notifier).previousChapter(),
                                icon: const Icon(Icons.chevron_left),
                                label: const Text("Prev Ch"),
                              )
                            else
                              const SizedBox(),
                            
                            OutlinedButton.icon(
                              onPressed: () => ref.read(bibleStateProvider.notifier).nextChapter(),
                              icon: const Icon(Icons.chevron_right),
                              label: const Text("Next Ch"),
                              iconAlignment: IconAlignment.end,
                            ),
                          ],
                        ),
                      );
                    }

                    final verse = verses[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Verse Number & English Text
                          RichText(
                            text: TextSpan(
                              style: DefaultTextStyle.of(context).style.copyWith(fontSize: 16, height: 1.5),
                              children: [
                                TextSpan(
                                  text: '${verse.verse}. ',
                                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue),
                                ),
                                TextSpan(text: verse.textEn),
                              ],
                            ),
                          ),
                          const SizedBox(height: 4),
                          // Telugu Text
                          if (verse.textTe.isNotEmpty)
                            Text(
                              verse.textTe,
                              style: const TextStyle(fontSize: 16, color: Colors.grey, height: 1.5),
                            ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}