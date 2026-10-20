import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/capsule.dart';
import 'capsule_storage.dart';
import 'media_service.dart';

/// Keeps a user's capsules in sync between this device and Supabase.
///  * in cloud, not local          -> download
///  * local, not cloud, not synced -> new on this device -> upload
///  * local, not cloud, synced     -> deleted on another device -> drop locally
class CapsuleSyncService {
  static SupabaseClient get _client => Supabase.instance.client;

  static Future<List<Capsule>> sync(String userId, List<Capsule> local) async {
    final rows = await _client
        .from('capsules')
        .select()
        .eq('user_id', userId);

    final remote = (rows as List)
        .map((r) => Capsule.fromRow(Map<String, dynamic>.from(r as Map)))
        .toList();

    final remoteIds = remote.map((c) => c.id).toSet();
    final synced = await CapsuleStorage.loadSyncedIds(userId);

    final merged = <String, Capsule>{
      for (final c in remote) c.id: c,
    };

    final toUpload = <Capsule>[];

    for (final c in local) {
      if (remoteIds.contains(c.id)) continue;
      if (synced.contains(c.id)) continue; // deleted on another device
      merged[c.id] = c;
      toUpload.add(c);
    }

    if (toUpload.isNotEmpty) {
      await _client
          .from('capsules')
          .upsert(toUpload.map((c) => c.toRow(userId)).toList());
    }

    await CapsuleStorage.saveSyncedIds(
      userId,
      {...remoteIds, ...toUpload.map((c) => c.id)},
    );

    return merged.values.toList()
      ..sort((a, b) => a.openDate.compareTo(b.openDate));
  }

  static Future<void> push(String userId, Capsule capsule) async {
    await _client.from('capsules').upsert(capsule.toRow(userId));

    final synced = await CapsuleStorage.loadSyncedIds(userId);
    synced.add(capsule.id);
    await CapsuleStorage.saveSyncedIds(userId, synced);
  }

  /// Deletes the capsule row and (if it has one) its photo in Storage.
  static Future<void> remove(
    String userId,
    String capsuleId, {
    String? mediaPath,
  }) async {
    await _client
        .from('capsules')
        .delete()
        .eq('id', capsuleId)
        .eq('user_id', userId);

    await MediaService().delete(mediaPath);

    final synced = await CapsuleStorage.loadSyncedIds(userId);
    synced.remove(capsuleId);
    await CapsuleStorage.saveSyncedIds(userId, synced);
  }
}