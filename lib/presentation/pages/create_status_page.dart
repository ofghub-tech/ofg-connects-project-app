import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:go_router/go_router.dart';
import 'package:ofgconnects_mobile/logic/status_provider.dart';

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
      if (mounted) context.pop(); // Go back on success
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
      appBar: AppBar(title: const Text("Create Status")),
      body: Column(
        children: [
          Expanded(
            child: _selectedFile == null
              ? Center(
                  child: IconButton(
                    icon: const Icon(Icons.add_a_photo, size: 50, color: Colors.white),
                    onPressed: _pickImage,
                  ),
                )
              : Image.file(_selectedFile!),
          ),
          if (_selectedFile != null)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: TextField(
                controller: _captionController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  hintText: "Add a caption...",
                  hintStyle: TextStyle(color: Colors.grey),
                  border: InputBorder.none,
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: _selectedFile != null
        ? FloatingActionButton(
            onPressed: _isUploading ? null : _upload,
            backgroundColor: Colors.blueAccent,
            child: _isUploading 
              ? const CircularProgressIndicator(color: Colors.white) 
              : const Icon(Icons.send, color: Colors.white),
          )
        : null,
    );
  }
}