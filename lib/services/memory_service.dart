import 'package:supabase_flutter/supabase_flutter.dart';

class MemoryService {
  final _supabase = Supabase.instance.client;

  Future<void> saveMemory({
    required String title,
    required String description,
    DateTime? memoryDate,
    String? mediaPath,
    String? mediaType,
  }) async {
    final user = _supabase.auth.currentUser;

    if (user == null) {
      throw Exception('Please login first');
    }

    await _supabase.from('memories').insert({
      'user_id': user.id,
      'title': title.trim(),
      'description': description.trim(),
      'memory_date': memoryDate == null
          ? null
          : '${memoryDate.year.toString().padLeft(4, '0')}-'
              '${memoryDate.month.toString().padLeft(2, '0')}-'
              '${memoryDate.day.toString().padLeft(2, '0')}',
      'media_path': mediaPath,
      'media_type': mediaType,
    });
  }

  Future<List<Map<String, dynamic>>> loadMemories() async {
    final user = _supabase.auth.currentUser;

    if (user == null) {
      throw Exception('Please login first');
    }

    final result = await _supabase
        .from('memories')
        .select()
        .eq('user_id', user.id)
        .order('created_at', ascending: false);

    return List<Map<String, dynamic>>.from(result);
  }
}