import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MediaService {
  static const bucket = 'timecapsule-media';
  static const maxImageBytes = 5 * 1024 * 1024; // 5 MB for capsule photos

  SupabaseClient get _supabase => Supabase.instance.client;

  /// Uploads a capsule photo, returns its storage path.
  Future<String> uploadImageBytes(Uint8List bytes, String extension) async {
    final user = _supabase.auth.currentUser;

    if (user == null) {
      throw Exception('Please login first');
    }

    if (bytes.isEmpty) {
      throw Exception('Could not read selected photo');
    }

    if (bytes.length > maxImageBytes) {
      throw Exception('Photo must be 5 MB or less');
    }

    final ext = extension.toLowerCase();
    final safeExt = const {'jpg', 'jpeg', 'png', 'webp'}.contains(ext)
        ? ext
        : 'jpg';

    final contentType = safeExt == 'png'
        ? 'image/png'
        : safeExt == 'webp'
            ? 'image/webp'
            : 'image/jpeg';

    final path = '${user.id}/${DateTime.now().microsecondsSinceEpoch}.$safeExt';

    await _supabase.storage.from(bucket).uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(contentType: contentType, upsert: false),
        );

    return path;
  }

  /// Temporary link (1 hour) to show a private file.
  Future<String?> signedUrl(String? path) async {
    if (path == null || path.isEmpty) return null;

    return _supabase.storage.from(bucket).createSignedUrl(path, 3600);
  }

  /// Deletes a file from storage. Never throws.
  Future<void> delete(String? path) async {
    if (path == null || path.isEmpty) return;

    try {
      await _supabase.storage.from(bucket).remove([path]);
    } catch (_) {}
  }

  /// Picks an image or video and uploads it. (Not used by the UI yet.)
  Future<String?> pickAndUploadMedia() async {
    final user = _supabase.auth.currentUser;

    if (user == null) {
      throw Exception('Please login first');
    }

    final result = await FilePicker.platform.pickFiles(
      type: FileType.media,
      withData: true,
      allowMultiple: false,
    );

    if (result == null || result.files.isEmpty) return null;

    final file = result.files.single;
    final bytes = file.bytes;

    if (bytes == null || bytes.isEmpty) {
      throw Exception('Could not read selected file');
    }

    if (bytes.length > 50 * 1024 * 1024) {
      throw Exception('File size must be 50 MB or less');
    }

    final extension = file.extension?.toLowerCase() ?? '';

    const imageExtensions = {'jpg', 'jpeg', 'png', 'webp'};
    const videoExtensions = {'mp4', 'webm'};

    final String contentType;

    if (imageExtensions.contains(extension)) {
      contentType = extension == 'jpg' || extension == 'jpeg'
          ? 'image/jpeg'
          : 'image/$extension';
    } else if (videoExtensions.contains(extension)) {
      contentType = 'video/$extension';
    } else {
      throw Exception('Unsupported file type');
    }

    final fileName = '${DateTime.now().microsecondsSinceEpoch}.$extension';
    final path = '${user.id}/$fileName';

    await _supabase.storage.from(bucket).uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(contentType: contentType, upsert: false),
        );

    return path;
  }
}