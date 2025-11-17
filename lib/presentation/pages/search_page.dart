// lib/presentation/pages/search_page.dart
import 'dart:async'; // <-- ADDED THIS IMPORT
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ofgconnects_mobile/logic/search_provider.dart';
import 'package:ofgconnects_mobile/presentation/widgets/video_card.dart';

class SearchPage extends ConsumerStatefulWidget {
  const SearchPage({super.key});

  @override
  ConsumerState<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends ConsumerState<SearchPage> {
  final _searchController = TextEditingController();
  Timer? _debounce; // <-- ADDED THIS

  @override
  void initState() {
    super.initState();
    // When the page loads, set the controller's text
    // to match the provider's state (e.g. if returning to the page)
    _searchController.text = ref.read(searchQueryProvider);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel(); // <-- ADDED THIS
    super.dispose();
  }

  // This function is no longer needed
  // void _performSearch() {
  //   ref.read(searchQueryProvider.notifier).state = _searchController.text;
  // }

  @override
  Widget build(BuildContext context) {
    // Watch the results provider
    final resultsAsync = ref.watch(searchResultsProvider);
    final currentQuery = ref.watch(searchQueryProvider);

    return Scaffold(
      appBar: AppBar(
        // The Search Bar
        title: TextField(
          controller: _searchController,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'Search videos, tags, and users...',
            border: InputBorder.none,
            hintStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
          ),
          style: const TextStyle(color: Colors.white),
          // --- UPDATED THIS SECTION ---
          onChanged: (query) {
            _debounce?.cancel();
            _debounce = Timer(const Duration(milliseconds: 500), () {
              ref.read(searchQueryProvider.notifier).state = query;
            });
          },
          onSubmitted: (_) {
            _debounce?.cancel();
            ref.read(searchQueryProvider.notifier).state = _searchController.text;
          },
          // ---------------------------
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            // --- UPDATED THIS ---
            onPressed: () {
              _debounce?.cancel();
              ref.read(searchQueryProvider.notifier).state = _searchController.text;
            },
            // --------------------
          )
        ],
      ),
      body: resultsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
        data: (videos) {
          // Show "no results" only if a search has been performed
          if (videos.isEmpty && currentQuery.isNotEmpty) {
            return Center(
              child: Text(
                'No results found for "$currentQuery"',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            );
          }
          
          // Show a helpful message before any search is run
          if (videos.isEmpty && currentQuery.isEmpty) {
             return Center(
              child: Text(
                'Start searching...',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            );
          }

          // Display results in a ListView, just like SearchPage.js
          return ListView.builder(
            itemCount: videos.length,
            itemBuilder: (context, index) {
              return VideoCard(video: videos[index]);
            },
          );
        },
      ),
    );
  }
}