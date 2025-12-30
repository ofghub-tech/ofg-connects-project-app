// lib/logic/bible_provider.dart
import 'package:appwrite/appwrite.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ofgconnects/api/appwrite_client.dart';
import 'package:ofgconnects/models/bible_verse.dart';

// 1. State to hold current selection
class BibleState {
  final String selectedBook;
  final int selectedChapter;

  BibleState({required this.selectedBook, required this.selectedChapter});
}

// 2. Notifier to manage selection (Book/Chapter)
class BibleStateNotifier extends StateNotifier<BibleState> {
  BibleStateNotifier() : super(BibleState(selectedBook: 'Genesis', selectedChapter: 1));

  void setBook(String book) {
    // Reset to chapter 1 when book changes
    state = BibleState(selectedBook: book, selectedChapter: 1);
  }

  void setChapter(int chapter) {
    state = BibleState(selectedBook: state.selectedBook, selectedChapter: chapter);
  }

  void nextChapter() {
    state = BibleState(selectedBook: state.selectedBook, selectedChapter: state.selectedChapter + 1);
  }

  void previousChapter() {
    if (state.selectedChapter > 1) {
      state = BibleState(selectedBook: state.selectedBook, selectedChapter: state.selectedChapter - 1);
    }
  }
}

final bibleStateProvider = StateNotifierProvider<BibleStateNotifier, BibleState>((ref) {
  return BibleStateNotifier();
});

// 3. Provider to fetch verses based on the selection
final bibleVersesProvider = FutureProvider<List<BibleVerse>>((ref) async {
  final currentState = ref.watch(bibleStateProvider);
  final databases = AppwriteClient.databases;

  try {
    final response = await databases.listDocuments(
      databaseId: AppwriteClient.databaseId,
      collectionId: AppwriteClient.collectionIdBible,
      queries: [
        Query.equal('book_en', currentState.selectedBook),
        Query.equal('chapter', currentState.selectedChapter),
        Query.orderAsc('verse'),
        Query.limit(200), // Fetch enough verses for a long chapter
      ],
    );

    return response.documents.map((doc) => BibleVerse.fromAppwrite(doc)).toList();
  } catch (e) {
    print('Error fetching bible verses: $e');
    return [];
  }
});

// 4. Hardcoded list of Books for the Dropdown
final List<String> bibleBooksList = [
  "Genesis", "Exodus", "Leviticus", "Numbers", "Deuteronomy", "Joshua", "Judges", "Ruth", 
  "1 Samuel", "2 Samuel", "1 Kings", "2 Kings", "1 Chronicles", "2 Chronicles", "Ezra", 
  "Nehemiah", "Esther", "Job", "Psalms", "Proverbs", "Ecclesiastes", "Song of Solomon", 
  "Isaiah", "Jeremiah", "Lamentations", "Ezekiel", "Daniel", "Hosea", "Joel", "Amos", 
  "Obadiah", "Jonah", "Micah", "Nahum", "Habakkuk", "Zephaniah", "Haggai", "Zechariah", 
  "Malachi", "Matthew", "Mark", "Luke", "John", "Acts", "Romans", "1 Corinthians", 
  "2 Corinthians", "Galatians", "Ephesians", "Philippians", "Colossians", 
  "1 Thessalonians", "2 Thessalonians", "1 Timothy", "2 Timothy", "Titus", "Philemon", 
  "Hebrews", "James", "1 Peter", "2 Peter", "1 John", "2 John", "3 John", "Jude", "Revelation"
];