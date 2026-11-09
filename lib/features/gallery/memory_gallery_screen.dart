import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:video_player/video_player.dart';

class MemoryGalleryScreen extends StatefulWidget {
  const MemoryGalleryScreen({super.key});

  @override
  State<MemoryGalleryScreen> createState() =>
      _MemoryGalleryScreenState();
}

class _MemoryGalleryScreenState extends State<MemoryGalleryScreen> {
  SupabaseClient get supabase => Supabase.instance.client;

  static const purple = Color(0xFFAB82FF);
  static const background = Color(0xFF0A0812);
  static const bucket = 'timecapsule-media';

  List<Map<String, dynamic>> memories = [];
  bool loading = true;
  bool uploading = false;

  @override
  void initState() {
    super.initState();
    loadMemories();
  }

  Future<void> loadMemories() async {
    try {
      final user = supabase.auth.currentUser;

      if (user == null) {
        throw Exception('Please login first.');
      }

      final response = await supabase
          .from('memory_media')
          .select()
          .eq('user_id', user.id)
          .order('created_at', ascending: false);

      final List<Map<String, dynamic>> result = await Future.wait(
        response.map((item) async {
          String? url;

          try {
            url = await supabase.storage
                .from(bucket)
                .createSignedUrl(item['file_path'] as String, 3600);
          } catch (_) {
            url = null;
          }

          return <String, dynamic>{
            ...Map<String, dynamic>.from(item),
            'signed_url': url,
          };
        }),
      );

      if (!mounted) return;

      setState(() {
        memories = result;
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => loading = false);
      showMessage('Could not load memories: $e');
    }
  }

  void showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFF292139),
      ),
    );
  }

  Future<void> chooseMedia(bool isVideo) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: isVideo ? FileType.video : FileType.image,
        allowMultiple: false,
        withData: true,
      );

      if (result == null || result.files.isEmpty) return;

      final file = result.files.first;
      final bytes = file.bytes;

      if (bytes == null || bytes.isEmpty) {
        showMessage('Unable to read selected file.');
        return;
      }

      if (file.size > 50 * 1024 * 1024) {
        showMessage('File size must be below 50 MB.');
        return;
      }

      final extension = file.extension?.toLowerCase() ?? '';

      const imageExtensions = ['jpg', 'jpeg', 'png', 'webp'];
      const videoExtensions = ['mp4', 'webm'];

      if (isVideo && !videoExtensions.contains(extension)) {
        showMessage('Only MP4 and WebM videos are supported.');
        return;
      }

      if (!isVideo && !imageExtensions.contains(extension)) {
        showMessage('Only JPG, PNG and WebP images are supported.');
        return;
      }

      await uploadMedia(
        bytes: bytes,
        fileName: file.name,
        extension: extension,
        isVideo: isVideo,
      );
    } catch (e) {
      showMessage('File selection failed: $e');
    }
  }

  Future<void> uploadMedia({
    required Uint8List bytes,
    required String fileName,
    required String extension,
    required bool isVideo,
  }) async {
    final user = supabase.auth.currentUser;

    if (user == null) {
      showMessage('Please login first.');
      return;
    }

    setState(() => uploading = true);

    final path =
        '${user.id}/${DateTime.now().microsecondsSinceEpoch}.$extension';

    final mimeTypes = {
      'jpg': 'image/jpeg',
      'jpeg': 'image/jpeg',
      'png': 'image/png',
      'webp': 'image/webp',
      'mp4': 'video/mp4',
      'webm': 'video/webm',
    };

    try {
      await supabase.storage.from(bucket).uploadBinary(
        path,
        bytes,
        fileOptions: FileOptions(
          contentType: mimeTypes[extension],
          upsert: false,
        ),
      );

      await supabase.from('memory_media').insert({
        'user_id': user.id,
        'file_path': path,
        'file_name': fileName,
        'media_type': isVideo ? 'video' : 'image',
      });

      showMessage('Memory uploaded successfully! 💜');
      await loadMemories();
    } catch (e) {
      // Clean up uploaded file if database insertion fails.
      try {
        await supabase.storage.from(bucket).remove([path]);
      } catch (_) {}

      showMessage('Upload failed: $e');
    } finally {
      if (mounted) {
        setState(() => uploading = false);
      }
    }
  }

  Future<void> deleteMemory(Map<String, dynamic> memory) async {
    try {
      await supabase
          .from('memory_media')
          .delete()
          .eq('id', memory['id']);

      try {
        await supabase.storage
            .from(bucket)
            .remove([memory['file_path'] as String]);
      } catch (_) {}

      if (!mounted) return;

      // Close the viewer that asked for the delete.
      Navigator.pop(context);
      showMessage('Memory deleted.');
      await loadMemories();
    } catch (e) {
      showMessage('Delete failed: $e');
    }
  }

  void openViewer(int index) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MemoryViewerScreen(
          memories: memories,
          initialIndex: index,
          onDelete: deleteMemory,
        ),
      ),
    );
  }

  void showUploadOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF191426),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(25),
        ),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Add a Memory 💜',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              ListTile(
                leading: const Icon(
                  Icons.image_outlined,
                  color: purple,
                ),
                title: const Text(
                  'Upload Photo',
                  style: TextStyle(color: Colors.white),
                ),
                onTap: () {
                  Navigator.pop(context);
                  chooseMedia(false);
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.video_library_outlined,
                  color: purple,
                ),
                title: const Text(
                  'Upload Video',
                  style: TextStyle(color: Colors.white),
                ),
                onTap: () {
                  Navigator.pop(context);
                  chooseMedia(true);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        backgroundColor: background,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Memory Gallery',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        actions: [
          IconButton(
            onPressed: loadMemories,
            icon: const Icon(Icons.refresh, color: purple),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: uploading ? null : showUploadOptions,
        backgroundColor: purple,
        foregroundColor: background,
        icon: const Icon(Icons.add_photo_alternate),
        label: const Text('Add Memory'),
      ),
      body: loading
          ? const Center(
              child: CircularProgressIndicator(color: purple),
            )
          : memories.isEmpty
              ? _emptyGallery()
              : RefreshIndicator(
                  color: purple,
                  onRefresh: loadMemories,
                  child: GridView.builder(
                    padding: const EdgeInsets.fromLTRB(
                      16, 12, 16, 100,
                    ),
                    physics: const AlwaysScrollableScrollPhysics(),
                    itemCount: memories.length,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 13,
                      mainAxisSpacing: 13,
                      childAspectRatio: 0.83,
                    ),
                    itemBuilder: (context, index) {
                      final memory = memories[index];
                      final isVideo = memory['media_type'] == 'video';

                      return GestureDetector(
                        onTap: () => openViewer(index),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(18),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              Container(
                                color: const Color(0xFF211A30),
                                child: isVideo
                                    ? const Icon(
                                        Icons.video_library_rounded,
                                        color: purple,
                                        size: 65,
                                      )
                                    : memory['signed_url'] == null
                                        ? const Icon(
                                            Icons.broken_image,
                                            color: purple,
                                            size: 40,
                                          )
                                        : Image.network(
                                            memory['signed_url'] as String,
                                            fit: BoxFit.cover,
                                            errorBuilder: (_, _, _) =>
                                                const Icon(
                                              Icons.broken_image,
                                              color: purple,
                                              size: 40,
                                            ),
                                          ),
                              ),
                              if (isVideo)
                                const Center(
                                  child: CircleAvatar(
                                    backgroundColor: Color(0xAA000000),
                                    radius: 27,
                                    child: Icon(
                                      Icons.play_arrow,
                                      color: Colors.white,
                                      size: 35,
                                    ),
                                  ),
                                ),
                              Positioned(
                                left: 0,
                                right: 0,
                                bottom: 0,
                                child: Container(
                                  padding: const EdgeInsets.all(10),
                                  color: Colors.black54,
                                  child: Text(
                                    memory['file_name'] ?? 'Memory',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
      bottomSheet: uploading
          ? Container(
              color: const Color(0xFF191426),
              padding: const EdgeInsets.all(15),
              child: const Row(
                children: [
                  SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      color: purple,
                      strokeWidth: 2,
                    ),
                  ),
                  SizedBox(width: 15),
                  Text(
                    'Uploading your memory...',
                    style: TextStyle(color: Colors.white),
                  ),
                ],
              ),
            )
          : null,
    );
  }

  Widget _emptyGallery() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.photo_library_outlined,
              color: purple,
              size: 85,
            ),
            const SizedBox(height: 20),
            const Text(
              'No Memories Yet',
              style: TextStyle(
                color: Colors.white,
                fontSize: 23,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Your beautiful moments deserve a place.\n'
              'Start saving your memories today!',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white60,
                height: 1.6,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: showUploadOptions,
              icon: const Icon(Icons.add),
              label: const Text('Add Your First Memory'),
              style: ElevatedButton.styleFrom(
                backgroundColor: purple,
                foregroundColor: background,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class MemoryViewerScreen extends StatefulWidget {
  final List<Map<String, dynamic>> memories;
  final int initialIndex;
  final Future<void> Function(Map<String, dynamic>) onDelete;

  const MemoryViewerScreen({
    super.key,
    required this.memories,
    required this.initialIndex,
    required this.onDelete,
  });

  @override
  State<MemoryViewerScreen> createState() =>
      _MemoryViewerScreenState();
}

class _MemoryViewerScreenState extends State<MemoryViewerScreen> {
  late final PageController pageController;
  late int currentIndex;

  @override
  void initState() {
    super.initState();
    currentIndex = widget.initialIndex;
    pageController = PageController(initialPage: currentIndex);
  }

  Future<void> confirmDelete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF191426),
        title: const Text(
          'Delete Memory?',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'This memory will be permanently deleted.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Delete',
              style: TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      await widget.onDelete(widget.memories[currentIndex]);
    }
  }

  @override
  void dispose() {
    pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0812),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0812),
        foregroundColor: Colors.white,
        title: Text(
          '${currentIndex + 1} / ${widget.memories.length}',
          style: const TextStyle(fontSize: 16),
        ),
        actions: [
          IconButton(
            onPressed: confirmDelete,
            icon: const Icon(
              Icons.delete_outline,
              color: Colors.redAccent,
            ),
          ),
        ],
      ),
      body: PageView.builder(
        controller: pageController,
        itemCount: widget.memories.length,
        onPageChanged: (index) {
          setState(() => currentIndex = index);
        },
        itemBuilder: (context, index) {
          return _MemoryMediaPage(
            memory: widget.memories[index],
          );
        },
      ),
    );
  }
}

class _MemoryMediaPage extends StatefulWidget {
  final Map<String, dynamic> memory;

  const _MemoryMediaPage({required this.memory});

  @override
  State<_MemoryMediaPage> createState() =>
      _MemoryMediaPageState();
}

class _MemoryMediaPageState extends State<_MemoryMediaPage> {
  VideoPlayerController? controller;
  bool videoError = false;

  @override
  void initState() {
    super.initState();

    if (widget.memory['media_type'] == 'video') {
      initializeVideo();
    }
  }

  Future<void> initializeVideo() async {
    try {
      final url = widget.memory['signed_url'] as String?;

      if (url == null) throw Exception('No video link');

      final video = VideoPlayerController.networkUrl(Uri.parse(url));

      controller = video;
      await video.initialize();
      video.addListener(() {
        if (mounted) setState(() {});
      });

      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) {
        setState(() => videoError = true);
      }
    }
  }

  @override
  void dispose() {
    controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isVideo = widget.memory['media_type'] == 'video';

    if (!isVideo) {
      final imageUrl = widget.memory['signed_url'] as String?;

      if (imageUrl == null) {
        return const Center(
          child: Icon(Icons.broken_image, color: Colors.white, size: 60),
        );
      }

      return InteractiveViewer(
        minScale: 0.8,
        maxScale: 4,
        child: Center(
          child: Image.network(
            imageUrl,
            fit: BoxFit.contain,
            errorBuilder: (_, _, _) => const Icon(
              Icons.broken_image,
              color: Colors.white,
              size: 60,
            ),
          ),
        ),
      );
    }

    if (videoError) {
      return const Center(
        child: Text(
          'Unable to play this video.',
          style: TextStyle(color: Colors.white),
        ),
      );
    }

    final video = controller;

    if (video == null || !video.value.isInitialized) {
      return const Center(
        child: CircularProgressIndicator(
          color: Color(0xFFAB82FF),
        ),
      );
    }

    return Center(
      child: AspectRatio(
        aspectRatio: video.value.aspectRatio,
        child: Stack(
          alignment: Alignment.center,
          children: [
            VideoPlayer(video),
            IconButton(
              iconSize: 65,
              color: Colors.white,
              onPressed: () {
                video.value.isPlaying ? video.pause() : video.play();
              },
              icon: Icon(
                video.value.isPlaying
                    ? Icons.pause_circle_filled
                    : Icons.play_circle_fill,
              ),
            ),
          ],
        ),
      ),
    );
  }
}