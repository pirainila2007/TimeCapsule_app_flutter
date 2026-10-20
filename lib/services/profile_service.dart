import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

class ProfileService {
  static const bucket = 'timecapsule-media';

  final _supabase = Supabase.instance.client;

  Future<void> saveProfile({
    required String fullName,
    String? avatarUrl,
  }) async {
    final user = _supabase.auth.currentUser;

    if (user == null) {
      throw Exception('Please login first');
    }

    await _supabase.from('profiles').upsert({
      'id': user.id,
      'full_name': fullName.trim(),
      'avatar_url': avatarUrl,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  Future<Map<String, dynamic>?> loadProfile() async {
    final user = _supabase.auth.currentUser;

    if (user == null) {
      throw Exception('Please login first');
    }

    return await _supabase
        .from('profiles')
        .select()
        .eq('id', user.id)
        .maybeSingle();
  }

  /// Uploads an avatar and returns its storage path (saved in avatar_url).
  Future<String> uploadAvatar(Uint8List bytes, String extension) async {
    final user = _supabase.auth.currentUser;

    if (user == null) {
      throw Exception('Please login first');
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

    final path =
        '${user.id}/avatar_${DateTime.now().millisecondsSinceEpoch}.$safeExt';

    await _supabase.storage.from(bucket).uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(contentType: contentType, upsert: true),
        );

    return path;
  }

  /// Temporary link (1 hour) to show a private avatar.
  Future<String?> signedAvatarUrl(String? path) async {
    if (path == null || path.isEmpty) return null;

    return _supabase.storage.from(bucket).createSignedUrl(path, 3600);
  }
}