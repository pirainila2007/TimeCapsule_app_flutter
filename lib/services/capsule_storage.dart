import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/capsule.dart';

class CapsuleStorage {
  static const storageKey = 'time_capsule_items_v1';

  // Guest (not logged in) keeps the original key; each account gets its own.
  static String _key(String? userId) =>
      userId == null ? storageKey : '${storageKey}_$userId';

  static String _syncedKey(String userId) => 'time_capsule_synced_$userId';

  static Future<List<Capsule>> load({String? userId}) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key(userId));

    if (raw == null) return [];

    try {
      final List<dynamic> data = jsonDecode(raw);

      return data
          .map(
            (item) => Capsule.fromJson(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList()
        ..sort((a, b) => a.openDate.compareTo(b.openDate));
    } catch (_) {
      return [];
    }
  }

  static Future<void> save(List<Capsule> capsules, {String? userId}) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString(
      _key(userId),
      jsonEncode(capsules.map((c) => c.toJson()).toList()),
    );
  }

  /// IDs of capsules this device has already uploaded / received.
  static Future<Set<String>> loadSyncedIds(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(_syncedKey(userId)) ?? const <String>[])
        .toSet();
  }

  static Future<void> saveSyncedIds(String userId, Set<String> ids) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_syncedKey(userId), ids.toList());
  }
}