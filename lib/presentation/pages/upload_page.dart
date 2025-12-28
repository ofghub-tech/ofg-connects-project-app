import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:ofgconnects/logic/upload_provider.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'package:path_provider/path_provider.dart';

class UploadPage extends ConsumerStatefulWidget {
  const UploadPage({super.key});

  @override
  ConsumerState<UploadPage> createState() => _UploadPageState();
}

class _UploadPageState extends ConsumerState<UploadPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _tagsController = TextEditingController(); 
  
  final Map<String, String> _categoryMap = {
    'General Video': 'general',
    'Short Video': 'shorts',
    'Song': 'songs',
    'Kids Video': 'kids',
  };
  
  late String _selectedCategoryLabel; 
  File? _videoFile;
  File? _thumbnailFile;
  final ImagePicker _picker = ImagePicker();

  VideoPlayerController? _videoController;
  ChewieController? _chewieController;
  bool _isGeneratingThumbnail = false;

  String _fileSizeString = "";

  @override
  void initState() {
    super.initState();
    _selectedCategoryLabel = _categoryMap.keys.first;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _tagsController.dispose();
    _videoController?.dispose();
    _chewieController?.dispose();
    super.dispose();
  }

  String _formatBytes(int bytes, int decimals) {
    if (bytes <= 0) return "0 B";
    const suffixes = ["B", "KB", "MB", "GB", "TB"];
    var i = (bytes.toString().length - 1) / 3; 
    int index = i.floor();
    if (index >= suffixes.length) index = suffixes.length - 1;
    double size = bytes / (1 << (10 * index)).toDouble(); 
    if (bytes < 1024) return "$bytes B";
    
    int suffixIndex = 0;
    double value = bytes.toDouble();
    while (value >= 1024 && suffixIndex < suffixes.length - 1) {
      value /= 1024;
      suffixIndex++;
    }
    return "${value.toStringAsFixed(decimals)} ${suffixes[suffixIndex]}";
  }

  Future<void> _initializePlayer(File file) async {
    _videoController?.dispose();
    _chewieController?.dispose();
    _videoController = null;
    _chewieController = null;

    try {
      _videoController = VideoPlayerController.file(file);
      await _videoController!.initialize();
      
      _chewieController = ChewieController(
        videoPlayerController: _videoController!,
        autoPlay: false,
        looping: false,
        aspectRatio: _videoController!.value.aspectRatio,
        allowFullScreen: true,
        allowMuting: true,
        showControls: true,
        materialProgressColors: ChewieProgressColors(
          playedColor: Colors.blueAccent,
          handleColor: Colors.blueAccent,
          backgroundColor: Colors.grey,
          bufferedColor: Colors.white24,
        ),
        placeholder: const Center(child: CircularProgressIndicator()),
        errorBuilder: (context, errorMessage) {
          return Center(child: Text(errorMessage, style: const TextStyle(color: Colors.white)));
        },
      );
      
      setState(() {}); 
    } catch (e) {
      print("Error initializing video player: $e");
    }
  }

  Future<void> _generateThumbnail(File video) async {
    setState(() => _isGeneratingThumbnail = true);
    
    try {
      final tempDir = await getTemporaryDirectory();
      final path = await VideoThumbnail.thumbnailFile(
        video: video.path,
        thumbnailPath: tempDir.path,
        imageFormat: ImageFormat.JPEG,
        maxHeight: 1280, // Increased quality for shorts
        quality: 80,
      );

      if (path != null) {
        setState(() {
          _thumbnailFile = File(path);
        });
      }
    } catch (e) {
      print("Error generating thumbnail: $e");
    } finally {
      setState(() => _isGeneratingThumbnail = false);
    }
  }

  Future<void> _pickVideo() async {
    final XFile? video = await _picker.pickVideo(source: ImageSource.gallery);
    if (video != null) {
      final String extension = video.path.split('.').last.toLowerCase();
      
      if (extension != 'mp4' && extension != 'mov') {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Format not supported. Please choose an MP4 or MOV video.')),
          );
        }
        return;
      }

      final file = File(video.path);
      final size = await file.length();
      
      setState(() {
        _videoFile = file;
        _fileSizeString = _formatBytes(size, 2);
        _thumbnailFile = null; 
      });

      await _initializePlayer(file);
      
      // Auto-detect if short based on aspect ratio
      if (_videoController != null && _videoController!.value.aspectRatio < 1.0) {
        setState(() {
          _selectedCategoryLabel = 'Short Video'; // Auto-select category
        });
      }

      await _generateThumbnail(file);
    }
  }

  Future<void> _pickThumbnail() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        _thumbnailFile = File(image.path);
      });
    }
  }

  Future<void> _handleUpload() async {
    if (!_formKey.currentState!.validate()) return;
    
    if (_videoFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a video file'), backgroundColor: Colors.redAccent),
      );
      return;
    }

    _videoController?.pause();

    await ref.read(uploadProvider.notifier).uploadVideo(
      videoFile: _videoFile!,
      thumbnailFile: _thumbnailFile,
      title: _titleController.text.trim(),
      description: _descriptionController.text.trim(),
      category: _categoryMap[_selectedCategoryLabel]!,
      tags: _tagsController.text.trim(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final uploadState = ref.watch(uploadProvider);

    // Determine if we should show a vertical (Shorts) layout
    bool isVerticalVideo = false;
    if (_videoController != null && _videoController!.value.isInitialized) {
      isVerticalVideo = _videoController!.value.aspectRatio < 1.0;
    }

    ref.listen<UploadState>(uploadProvider, (previous, next) {
      if (next.error != null && !next.isLoading) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.error!), 
            backgroundColor: next.error!.contains("Cancelled") ? Colors.orange : Colors.red
          ),
        );
      }
      if (next.successMessage != null && !next.isLoading && next.error == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Upload Successful!"), backgroundColor: Colors.green),
        );
        context.go('/home');
      }
    });

    return Stack(
      children: [
        Scaffold(
          backgroundColor: const Color(0xFF121212),
          appBar: AppBar(
            backgroundColor: const Color(0xFF1E1E1E),
            title: const Text('Upload Video', style: TextStyle(color: Colors.white)),
            iconTheme: const IconThemeData(color: Colors.white),
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(20.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  
                  // --- DYNAMIC VIDEO PREVIEW ---
                  GestureDetector(
                    onTap: (_videoFile == null && !uploadState.isLoading) ? _pickVideo : null,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      // Taller for vertical videos
                      height: isVerticalVideo ? 400 : 240, 
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E1E1E),
                        border: Border.all(color: Colors.white12),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      clipBehavior: Clip.hardEdge,
                      child: _videoFile == null
                          ? const Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.cloud_upload_outlined, size: 60, color: Colors.blueAccent),
                                SizedBox(height: 16),
                                Text('Tap to Select Video', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                                SizedBox(height: 8),
                                Text('MP4, MOV (Max 5GB)', style: TextStyle(color: Colors.grey, fontSize: 12)),
                              ],
                            )
                          : Stack(
                              children: [
                                if (_chewieController != null && _chewieController!.videoPlayerController.value.isInitialized)
                                  Chewie(controller: _chewieController!)
                                else
                                  const Center(child: CircularProgressIndicator()),
                                
                                Positioned(
                                  top: 10, right: 10,
                                  child: GestureDetector(
                                    onTap: uploadState.isLoading ? null : _pickVideo,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                      decoration: BoxDecoration(
                                        color: Colors.black.withOpacity(0.7),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: const Row(
                                        children: [
                                          Icon(Icons.edit, size: 14, color: Colors.white),
                                          SizedBox(width: 6),
                                          Text("Change", style: TextStyle(color: Colors.white, fontSize: 12)),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                  
                  if (_videoFile != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0, left: 4),
                      child: Text("File Size: $_fileSizeString", style: const TextStyle(color: Colors.grey, fontSize: 12)),
                    ),

                  const SizedBox(height: 24),
                  
                  // Inputs
                  _buildLabel('Title'),
                  TextFormField(
                    controller: _titleController,
                    style: const TextStyle(color: Colors.white),
                    validator: (v) => v!.isEmpty ? 'Required' : null,
                    decoration: _inputDecor('Video Title'),
                    enabled: !uploadState.isLoading,
                  ),
                  
                  const SizedBox(height: 16),
                  
                  _buildLabel('Description'),
                  TextFormField(
                    controller: _descriptionController,
                    style: const TextStyle(color: Colors.white),
                    maxLines: 4,
                    decoration: _inputDecor('Tell viewers about your video'),
                    enabled: !uploadState.isLoading,
                  ),
                  
                  const SizedBox(height: 16),
                  
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildLabel('Category'),
                            DropdownButtonFormField<String>(
                              value: _selectedCategoryLabel,
                              dropdownColor: const Color(0xFF2C2C2C),
                              style: const TextStyle(color: Colors.white),
                              decoration: _inputDecor('Select'),
                              items: _categoryMap.keys.map((label) {
                                return DropdownMenuItem(value: label, child: Text(label));
                              }).toList(),
                              onChanged: uploadState.isLoading ? null : (val) => setState(() => _selectedCategoryLabel = val!),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildLabel('Tags'),
                            TextFormField(
                              controller: _tagsController,
                              style: const TextStyle(color: Colors.white),
                              decoration: _inputDecor('e.g. #worship'),
                              validator: (v) => v!.isEmpty ? 'Required' : null,
                              enabled: !uploadState.isLoading,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),
                  
                  // --- DYNAMIC THUMBNAIL PREVIEW ---
                  _buildLabel('Thumbnail'),
                  GestureDetector(
                    onTap: uploadState.isLoading ? null : _pickThumbnail,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      // Dynamic Height: Taller for Shorts (9:16), Shorter for Normal (16:9)
                      height: isVerticalVideo ? 260 : 160,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E1E1E),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white12),
                        // Note: Using a child Image instead of DecorationImage to control fit better
                      ),
                      clipBehavior: Clip.hardEdge, // Ensure image doesn't bleed
                      child: _thumbnailFile == null
                          ? Center(
                              child: _isGeneratingThumbnail 
                                ? const Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      CircularProgressIndicator(strokeWidth: 2),
                                      SizedBox(height: 8),
                                      Text("Generating...", style: TextStyle(color: Colors.grey, fontSize: 12))
                                    ],
                                  )
                                : const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.image, color: Colors.grey),
                                      SizedBox(width: 8),
                                      Text('Tap to Upload Cover', style: TextStyle(color: Colors.grey)),
                                    ],
                                  ),
                            )
                          : Stack(
                              fit: StackFit.expand,
                              children: [
                                // Use BoxFit.contain to show FULL image (no cropping)
                                // Use BoxFit.cover if you want to fill the box (but might crop)
                                // For Shorts, BoxFit.contain with a black bg is safest.
                                Image.file(
                                  _thumbnailFile!, 
                                  fit: isVerticalVideo ? BoxFit.contain : BoxFit.cover,
                                ),
                                
                                Positioned(
                                  top: 8, right: 8,
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                                    child: const Icon(Icons.edit, color: Colors.white, size: 16),
                                  ),
                                ),
                                if (_isGeneratingThumbnail == false && _thumbnailFile != null)
                                  Positioned(
                                    bottom: 8, left: 8,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(4)),
                                      child: const Text("Cover Image", style: TextStyle(color: Colors.white70, fontSize: 10)),
                                    ),
                                  )
                              ],
                            ),
                    ),
                  ),
                  
                  const SizedBox(height: 40),
                  
                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton(
                      onPressed: uploadState.isLoading ? null : _handleUpload,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueAccent,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        disabledBackgroundColor: Colors.blueAccent.withOpacity(0.3),
                      ),
                      child: const Text('Publish Video', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                    ),
                  ),
                  const SizedBox(height: 50),
                ],
              ),
            ),
          ),
        ),

        if (uploadState.isLoading)
          Container(
            color: Colors.black.withOpacity(0.8),
            child: Center(
              child: Container(
                width: MediaQuery.of(context).size.width * 0.85,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E1E),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white12),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 20, spreadRadius: 5),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(
                      height: 50, width: 50,
                      child: CircularProgressIndicator(strokeWidth: 3, color: Colors.blueAccent),
                    ),
                    const SizedBox(height: 24),
                    
                    Text(
                      uploadState.successMessage ?? 'Processing...',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Please keep the app open.',
                      style: TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                    const SizedBox(height: 20),
                    
                    LinearProgressIndicator(
                      value: uploadState.progress / 100,
                      minHeight: 8,
                      borderRadius: BorderRadius.circular(4),
                      backgroundColor: Colors.grey[800],
                      color: Colors.blueAccent,
                    ),
                    const SizedBox(height: 8),
                    
                    Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        '${uploadState.progress.toInt()}%',
                        style: const TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold),
                      ),
                    ),
                    
                    const SizedBox(height: 20),
                    const Divider(color: Colors.white10),
                    
                    TextButton.icon(
                      onPressed: uploadState.isCancelling 
                        ? null 
                        : () {
                           ref.read(uploadProvider.notifier).cancelUpload();
                        },
                      icon: uploadState.isCancelling 
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.red))
                        : const Icon(Icons.close, color: Colors.redAccent),
                      label: Text(
                        uploadState.isCancelling ? "Cancelling..." : "Cancel Upload",
                        style: const TextStyle(color: Colors.redAccent),
                      ),
                    )
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0, left: 4.0),
      child: Text(text, style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w500)),
    );
  }

  InputDecoration _inputDecor(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
      filled: true,
      fillColor: const Color(0xFF1E1E1E),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.white12),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.blueAccent),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.redAccent),
      ),
      contentPadding: const EdgeInsets.all(16),
    );
  }
}