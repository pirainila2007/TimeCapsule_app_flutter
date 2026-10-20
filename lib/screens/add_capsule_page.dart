import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/capsule.dart';
import '../services/media_service.dart';
import '../utils/app_constants.dart';
import '../utils/app_state.dart';

class AddCapsulePage extends StatefulWidget {
  const AddCapsulePage({super.key});

  @override
  State<AddCapsulePage> createState() => _AddCapsulePageState();
}

class _AddCapsulePageState extends State<AddCapsulePage> {
  final formKey = GlobalKey<FormState>();
  final titleController = TextEditingController();
  final messageController = TextEditingController();

  final categories = [
    'Letter to myself',
    'Dream',
    'Memory',
    'Achievement',
    'Promise',
  ];

  String category = 'Letter to myself';
  DateTime openDate = DateTime.now().add(const Duration(days: 30));

  // One attachment per capsule: a photo OR a video.
  Uint8List? mediaBytes;
  String mediaExt = 'jpg';
  String mediaName = '';
  bool mediaIsVideo = false;
  bool saving = false;

  /// Signed-in users upload to Supabase Storage;
  /// guests keep a small photo inside the capsule on this device.
  bool get useCloud => supabaseReady && currentUserId != null;

  @override
  void dispose() {
    titleController.dispose();
    messageController.dispose();
    super.dispose();
  }

  void showMessage(String text) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  String extensionOf(String name, String fallback) {
    final dot = name.lastIndexOf('.');

    if (dot == -1 || dot == name.length - 1) return fallback;

    return name.substring(dot + 1).toLowerCase();
  }

  Future<void> chooseDate() async {
    final now = DateTime.now();

    final picked = await showDatePicker(
      context: context,
      initialDate: openDate.isBefore(now) ? now : openDate,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year + 30),
      helpText: 'Choose your capsule opening date',
    );

    if (picked != null) {
      setState(() {
        openDate = DateTime(picked.year, picked.month, picked.day, 9);
      });
    }
  }

  Future<void> choosePhoto() async {
    try {
      final file = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: useCloud ? 75 : 45,
        maxWidth: useCloud ? 1600 : 900,
      );

      if (file == null) return;

      final bytes = await file.readAsBytes();
      final limit = useCloud ? MediaService.maxImageBytes : 800000;

      if (bytes.length > limit) {
        showMessage(
          useCloud
              ? 'Choose a smaller photo (under 5 MB).'
              : 'Choose a smaller photo (under 800 KB). '
                  'Sign in to attach bigger photos.',
        );
        return;
      }

      setState(() {
        mediaBytes = bytes;
        mediaName = file.name;
        mediaExt = extensionOf(file.name, 'jpg');
        mediaIsVideo = false;
      });
    } catch (e) {
      showMessage('Could not select photo: $e');
    }
  }

  Future<void> chooseVideo() async {
    if (!useCloud) {
      showMessage('Sign in to attach a video.');
      return;
    }

    try {
      final file = await ImagePicker().pickVideo(
        source: ImageSource.gallery,
        maxDuration: const Duration(minutes: 2),
      );

      if (file == null) return;

      final bytes = await file.readAsBytes();

      if (bytes.length > MediaService.maxVideoBytes) {
        showMessage('Choose a shorter video (under 50 MB).');
        return;
      }

      setState(() {
        mediaBytes = bytes;
        mediaName = file.name;
        mediaExt = extensionOf(file.name, 'mp4');
        mediaIsVideo = true;
      });
    } catch (e) {
      showMessage('Could not select video: $e');
    }
  }

  void removeMedia() {
    setState(() {
      mediaBytes = null;
      mediaName = '';
      mediaIsVideo = false;
    });
  }

  Future<void> saveCapsule() async {
    if (saving || !formKey.currentState!.validate()) return;

    setState(() => saving = true);

    String? inlineImage;
    String? mediaPath;
    String? mediaType;

    try {
      final bytes = mediaBytes;

      if (bytes != null) {
        if (!useCloud) {
          inlineImage = base64Encode(bytes);
        } else if (mediaIsVideo) {
          mediaPath = await MediaService().uploadVideoBytes(bytes, mediaExt);
          mediaType = 'video';
        } else {
          mediaPath = await MediaService().uploadImageBytes(bytes, mediaExt);
          mediaType = 'image';
        }
      }
    } catch (e) {
      if (!mounted) return;

      setState(() => saving = false);
      showMessage('Could not upload: $e');
      return;
    }

    if (!mounted) return;

    final capsule = Capsule(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      title: titleController.text.trim(),
      message: messageController.text.trim(),
      category: category,
      openDate: openDate,
      createdAt: DateTime.now(),
      imageBase64: inlineImage,
      mediaPath: mediaPath,
      mediaType: mediaType,
    );

    Navigator.pop(context, capsule);
  }

  Widget mediaPreview() {
    final bytes = mediaBytes!;

    if (!mediaIsVideo) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Image.memory(bytes, height: 180, fit: BoxFit.cover),
      );
    }

    final mb = (bytes.length / (1024 * 1024)).toStringAsFixed(1);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Icon(Icons.videocam_rounded, color: AppColors.purple, size: 34),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  mediaName.isEmpty ? 'Video' : mediaName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '$mb MB',
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasMedia = mediaBytes != null;

    return Scaffold(
      appBar: AppBar(title: const Text('Create a capsule')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 650),
          child: Form(
            key: formKey,
            child: ListView(
              padding: const EdgeInsets.all(22),
              children: [
                const Icon(
                  Icons.hourglass_bottom_rounded,
                  color: AppColors.purple,
                  size: 56,
                ),
                const SizedBox(height: 12),
                const Text(
                  'Write something worth remembering.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 23, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 26),
                const Text('Capsule title'),
                const SizedBox(height: 8),
                TextFormField(
                  controller: titleController,
                  maxLength: 60,
                  decoration: const InputDecoration(
                    hintText: 'e.g. A letter to my future self',
                  ),
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'Enter a title' : null,
                ),
                const SizedBox(height: 14),
                const Text('Category'),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: category,
                  isExpanded: true,
                  decoration: const InputDecoration(),
                  items: categories
                      .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                      .toList(),
                  onChanged: (value) {
                    if (value != null) setState(() => category = value);
                  },
                ),
                const SizedBox(height: 18),
                const Text('Your message'),
                const SizedBox(height: 8),
                TextFormField(
                  controller: messageController,
                  minLines: 6,
                  maxLines: 12,
                  maxLength: 5000,
                  decoration: const InputDecoration(
                    hintText: 'What do you want your future self to remember?',
                    alignLabelWithHint: true,
                  ),
                  validator: (v) => v == null || v.trim().isEmpty
                      ? 'Write a message first'
                      : null,
                ),
                const SizedBox(height: 12),
                Material(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(18),
                  clipBehavior: Clip.antiAlias,
                  child: ListTile(
                    leading: const Icon(
                      Icons.calendar_month_rounded,
                      color: AppColors.purple,
                    ),
                    title: const Text('Opening date'),
                    subtitle: Text(formatDate(openDate)),
                    trailing: const Icon(Icons.edit_calendar_rounded),
                    onTap: chooseDate,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: saving ? null : choosePhoto,
                        icon: Icon(
                          hasMedia && !mediaIsVideo
                              ? Icons.check_circle_outline
                              : Icons.add_photo_alternate_outlined,
                        ),
                        label: Text(
                          hasMedia && !mediaIsVideo ? 'Photo added' : 'Photo',
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: saving ? null : chooseVideo,
                        icon: Icon(
                          hasMedia && mediaIsVideo
                              ? Icons.check_circle_outline
                              : Icons.videocam_outlined,
                        ),
                        label: Text(
                          hasMedia && mediaIsVideo ? 'Video added' : 'Video',
                        ),
                      ),
                    ),
                  ],
                ),
                if (hasMedia) ...[
                  const SizedBox(height: 10),
                  mediaPreview(),
                  TextButton(
                    onPressed: saving ? null : removeMedia,
                    child: Text(
                      mediaIsVideo ? 'Remove video' : 'Remove photo',
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: saving ? null : saveCapsule,
                  icon: saving
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.lock_outline_rounded),
                  label: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    child: Text(saving ? 'Sealing...' : 'Seal my capsule'),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.purple,
                    foregroundColor: Colors.white,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  useCloud
                      ? 'Saved on this device and synced to your account.'
                      : 'Saved on this device only. Sign in to sync '
                          'between devices and attach videos.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}