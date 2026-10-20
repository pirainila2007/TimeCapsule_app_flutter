import 'dart:async';

import 'package:flutter/material.dart';

import '../models/capsule.dart';
import '../services/capsule_storage.dart';
import '../services/capsule_sync_service.dart';
import '../services/notification_service.dart';
import '../utils/app_constants.dart';
import '../utils/app_state.dart';
import '../widgets/capsule_card.dart';
import 'add_capsule_page.dart';
import 'capsule_details_page.dart';
import 'login_page.dart';
import 'profile_page.dart';

class HomePage extends StatefulWidget {
  /// Signed-in user id, or null for local-only (guest) mode.
  final String? userId;

  const HomePage({super.key, this.userId});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<Capsule> capsules = [];
  bool loading = true;
  String search = '';
  String filter = 'All';
  Timer? clock;
  bool syncing = false;

  String? get userId => widget.userId;

  @override
  void initState() {
    super.initState();
    loadCapsules();

    clock = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    clock?.cancel();
    super.dispose();
  }

  Future<void> loadCapsules() async {
    final result = await CapsuleStorage.load(userId: userId);

    if (!mounted) return;

    setState(() {
      capsules = result;
      loading = false;
    });

    await syncWithCloud();
  }

  Future<void> syncWithCloud() async {
    final uid = userId;

    if (uid == null || !supabaseReady || syncing) return;

    setState(() => syncing = true);

    try {
      final beforeIds = capsules.map((c) => c.id).toSet();
      final merged = await CapsuleSyncService.sync(uid, capsules);
      final mergedIds = merged.map((c) => c.id).toSet();

      await CapsuleStorage.save(merged, userId: uid);

      for (final c in merged) {
        if (!beforeIds.contains(c.id)) {
          try {
            await NotificationService.schedule(c);
          } catch (e) {
            debugPrint('Notification scheduling failed: $e');
          }
        }
      }

      for (final c in capsules) {
        if (!mergedIds.contains(c.id)) {
          try {
            await NotificationService.cancel(c);
          } catch (e) {
            debugPrint('Notification cancellation failed: $e');
          }
        }
      }

      if (!mounted) return;

      setState(() => capsules = merged);
    } catch (e) {
      debugPrint('Cloud sync failed: $e');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Could not sync with the cloud. Showing saved capsules.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => syncing = false);
    }
  }

  Future<void> openProfile() async {
    if (userId != null) {
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const ProfilePage()),
      );
    } else if (supabaseReady) {
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const LoginPage()),
      );
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cloud sign-in is not available right now.'),
        ),
      );
    }
  }

  Future<void> addCapsule() async {
    final result = await Navigator.push<Capsule>(
      context,
      MaterialPageRoute(builder: (_) => const AddCapsulePage()),
    );

    if (result == null) return;

    final updated = [...capsules, result]
      ..sort((a, b) => a.openDate.compareTo(b.openDate));

    await CapsuleStorage.save(updated, userId: userId);

    try {
      await NotificationService.schedule(result);
    } catch (e) {
      debugPrint('Notification scheduling failed: $e');
    }

    final uid = userId;

    if (uid != null && supabaseReady) {
      try {
        await CapsuleSyncService.push(uid, result);
      } catch (e) {
        // Not marked as synced, so the next sync uploads it.
        debugPrint('Cloud upload failed: $e');
      }
    }

    if (!mounted) return;

    setState(() => capsules = updated);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result.isUnlocked
              ? 'Your capsule is ready to open! 💜'
              : 'Your capsule is sealed. Your countdown begins! 🔐',
        ),
      ),
    );
  }

  Future<bool> deleteCapsule(Capsule capsule) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete capsule?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return false;

    final updated = capsules.where((c) => c.id != capsule.id).toList();

    await CapsuleStorage.save(updated, userId: userId);

    try {
      await NotificationService.cancel(capsule);
    } catch (e) {
      debugPrint('Notification cancellation failed: $e');
    }

    final uid = userId;

    if (uid != null && supabaseReady) {
      try {
        await CapsuleSyncService.remove(uid, capsule.id);
      } catch (e) {
        debugPrint('Cloud delete failed: $e');
      }
    }

    if (mounted) {
      setState(() => capsules = updated);
    }

    return true;
  }

  @override
  Widget build(BuildContext context) {
    final opened = capsules.where((c) => c.isUnlocked).length;
    final locked = capsules.length - opened;

    final visible = capsules.where((c) {
      final query = search.toLowerCase();

      final matchesSearch = c.title.toLowerCase().contains(query) ||
          c.category.toLowerCase().contains(query);

      final matchesFilter = filter == 'All' ||
          (filter == 'Locked' && !c.isUnlocked) ||
          (filter == 'Opened' && c.isUnlocked);

      return matchesSearch && matchesFilter;
    }).toList();

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: addCapsule,
        backgroundColor: AppColors.purple,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Create capsule'),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: loading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: loadCapsules,
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(20, 18, 20, 110),
                      children: [
                        if (syncing)
                          const Padding(
                            padding: EdgeInsets.only(bottom: 12),
                            child: LinearProgressIndicator(minHeight: 2),
                          ),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppColors.purple.withValues(alpha: 0.16),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: const Icon(
                                Icons.hourglass_top_rounded,
                                color: AppColors.purple,
                                size: 30,
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'TimeCapsule',
                                    style: TextStyle(
                                      fontSize: 25,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    'Today becomes a memory tomorrow.',
                                    style: TextStyle(
                                      color: Colors.white60,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              tooltip: userId == null ? 'Sign in' : 'Profile',
                              onPressed: openProfile,
                              icon: Icon(
                                userId == null
                                    ? Icons.login_rounded
                                    : Icons.account_circle_rounded,
                                color: AppColors.purple,
                                size: 30,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 28),
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(28),
                            gradient: const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Color(0xFF422565),
                                Color(0xFF211631),
                                Color(0xFF15111E),
                              ],
                            ),
                            border: Border.all(
                              color: AppColors.purple.withValues(alpha: 0.4),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(
                                Icons.auto_awesome,
                                color: Color(0xFFE0CEFF),
                                size: 32,
                              ),
                              const SizedBox(height: 14),
                              const Text(
                                'Dear future me, ...',
                                style: TextStyle(
                                  fontSize: 27,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Save a piece of today. Open it when '
                                'tomorrow becomes your present.',
                                style: TextStyle(
                                  color: Colors.white70,
                                  height: 1.5,
                                ),
                              ),
                              const SizedBox(height: 22),
                              Wrap(
                                spacing: 24,
                                runSpacing: 14,
                                children: [
                                  stat('TOTAL', capsules.length),
                                  stat('LOCKED', locked),
                                  stat('OPENED', opened),
                                ],
                              ),
                              const SizedBox(height: 22),
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerLeft,
                                child: FilledButton.icon(
                                  onPressed: addCapsule,
                                  icon: const Icon(Icons.edit_note_rounded),
                                  label: const Text('Create a memory'),
                                  style: FilledButton.styleFrom(
                                    backgroundColor: AppColors.purple,
                                    foregroundColor: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 28),
                        const Text(
                          'Your collection',
                          style: TextStyle(
                            fontSize: 21,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 14),
                        TextField(
                          onChanged: (v) => setState(() => search = v),
                          decoration: const InputDecoration(
                            hintText: 'Search your capsules...',
                            prefixIcon: Icon(Icons.search_rounded),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          children: ['All', 'Locked', 'Opened'].map((item) {
                            return ChoiceChip(
                              label: Text(item),
                              selected: filter == item,
                              selectedColor:
                                  AppColors.purple.withValues(alpha: 0.3),
                              onSelected: (_) => setState(() => filter = item),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 14),
                        if (visible.isEmpty)
                          Container(
                            padding: const EdgeInsets.all(30),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(24),
                            ),
                            child: const Column(
                              children: [
                                Icon(
                                  Icons.inventory_2_outlined,
                                  size: 44,
                                  color: AppColors.purple,
                                ),
                                SizedBox(height: 12),
                                Text(
                                  'Your story starts here',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 17,
                                  ),
                                ),
                                SizedBox(height: 6),
                                Text(
                                  'Create a capsule for your future self.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: Colors.white60),
                                ),
                              ],
                            ),
                          )
                        else
                          ...visible.map(
                            (capsule) => CapsuleCard(
                              capsule: capsule,
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => CapsuleDetailsPage(
                                      capsule: capsule,
                                      onDelete: () => deleteCapsule(capsule),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                      ],
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

Widget stat(String label, int value) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        '$value',
        style: const TextStyle(fontSize: 23, fontWeight: FontWeight.bold),
      ),
      Text(
        label,
        style: const TextStyle(
          fontSize: 10,
          letterSpacing: 1.1,
          color: Colors.white60,
        ),
      ),
    ],
  );
}