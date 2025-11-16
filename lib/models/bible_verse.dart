// lib/models/bible_verse.dart
import 'package:appwrite/models.dart';

class BibleVerse {
  final String bookEn;
  final String bookTe;
  final int chapter;
  final int verse;
  final String textEn;
  final String textTe;

  BibleVerse({
    required this.bookEn,
    required this.bookTe,
    required this.chapter,
    required this.verse,
    required this.textEn,
    required this.textTe,
  });

  factory BibleVerse.fromAppwrite(Document doc) {
    return BibleVerse(
      bookEn: doc.data['book_en'] ?? '',
      bookTe: doc.data['book_te'] ?? '',
      chapter: doc.data['chapter'] ?? 0,
      verse: doc.data['verse'] ?? 0,
      textEn: doc.data['text_en'] ?? '',
      textTe: doc.data['text_te'] ?? '',
    );
  }
}