import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:go_router/go_router.dart';
import 'package:ofgconnects/logic/status_provider.dart';

class CreateStatusPage extends ConsumerStatefulWidget {
  const CreateStatusPage({super.key});

  @override
  ConsumerState<CreateStatusPage> createState() => _CreateStatusPageState();
}

class _CreateStatusPageState extends ConsumerState<CreateStatusPage> {
  File? _selectedFile;
  final _captionController = TextEditingController();
  bool _isUploading = false;

  Future<void> _pickImage() async {
    final file = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (file != null) {
      setState(() => _selectedFile = File(file.path));
    }
  }

  Future<void> _upload() async {
    if (_selectedFile == null) return;
    setState(() => _isUploading = true);
    try {
      await ref.read(statusProvider.notifier).uploadStatus(
        file: _selectedFile!,
        caption: _captionController.text.trim(),
      );
      if (mounted) context.pop(); 
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      // Ensures keyboard doesn't cover the input
      resizeToAvoidBottomInset: true, 
      
      appBar: AppBar(
        title: const Text("Create Status"),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      
      body: Stack(
        children: [
          // 1. Image Preview (Centered)
          if (_selectedFile != null)
            Positioned.fill(
              child: Image.file(
                _selectedFile!,
                fit: BoxFit.contain,
              ),
            )
          else
            Center(
              child: GestureDetector(
                onTap: _pickImage,
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.grey[900],
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white24),
                  ),
                  child: const Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.add_a_photo_rounded, size: 40, color: Colors.white70),
                      SizedBox(height: 8),
                      Text("Tap to select", style: TextStyle(color: Colors.white54)),
                    ],
                  ),
                ),
              ),
            ),

          // 2. Caption Field (Bottom overlay)
          if (_selectedFile != null)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 16, 90, 16), // Right padding leaves space for FAB
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [Colors.black.withOpacity(0.8), Colors.transparent],
                  ),
                ),
                child: TextField(
                  controller: _captionController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: "Add a caption...",
                    hintStyle: const TextStyle(color: Colors.white70),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.1),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  ),
                ),
              ),
            ),
        ],
      ),

      // 3. SUBMIT BUTTON (Floating at Bottom Right)
      floatingActionButton: _selectedFile != null
          ? FloatingActionButton(
              onPressed: _isUploading ? null : _upload,
              backgroundColor: Colors.blueAccent,
              child: _isUploading 
                  ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.send, color: Colors.white),
            )
          : null,
    );
  }
}