
import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const TimeCapsuleApp());
}

const purple = Color(0xFFAB82FF);
const background = Color(0xFF0A0812);
const surface = Color(0xFF171321);

class TimeCapsuleApp extends StatelessWidget {
  const TimeCapsuleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'TimeCapsule',
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: background,
        colorScheme: ColorScheme.fromSeed(
          seedColor: purple,
          brightness: Brightness.dark,
          surface: surface,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: surface,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: purple),
          ),
        ),
      ),
      home: const HomePage(),
    );
  }
}

// ------------------------------------------------------------
// NOTIFICATIONS: scheduled notifications on Android.
// Web uses the live countdown and an in-app alert.
// ------------------------------------------------------------

class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static bool _initialized = false;

  static Future<void> initialize() async {
    if (kIsWeb || _initialized) return;

    tzdata.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Colombo'));

    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    );

    await _plugin.initialize(settings: settings);

    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    await android?.requestNotificationsPermission();

    _initialized = true;
  }

  static Future<void> schedule(Capsule capsule) async {
    if (kIsWeb) return;

    await initialize();

    // Notify at 9:00 AM on the opening date.
    final target = DateTime(
      capsule.openDate.year,
      capsule.openDate.month,
      capsule.openDate.day,
      9,
    );

    if (!target.isAfter(DateTime.now())) return;

    await _plugin.zonedSchedule(
      id: capsule.id.hashCode & 0x7fffffff,
      title: 'Your TimeCapsule is ready! 💜',
      body: '"${capsule.title}" is waiting for you.',
      scheduledDate: tz.TZDateTime.from(target, tz.local),
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'time_capsule_openings',
          'TimeCapsule openings',
          channelDescription: 'Reminders when your capsules are ready',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
  }

  static Future<void> cancel(Capsule capsule) async {
    if (kIsWeb) return;
    await _plugin.cancel(id: capsule.id.hashCode & 0x7fffffff);
  }
}

// ------------------------------------------------------------
// DATA MODEL
// ------------------------------------------------------------

class Capsule {
  final String id;
  final String title;
  final String message;
  final String category;
  final DateTime openDate;
  final DateTime createdAt;
  final String? imageBase64;

  Capsule({
    required this.id,
    required this.title,
    required this.message,
    required this.category,
    required this.openDate,
    required this.createdAt,
    this.imageBase64,
  });

  bool get isUnlocked => !DateTime.now().isBefore(openDate);

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'message': message,
        'category': category,
        'openDate': openDate.toIso8601String(),
        'createdAt': createdAt.toIso8601String(),
        'imageBase64': imageBase64,
      };

  factory Capsule.fromJson(Map<String, dynamic> json) => Capsule(
        id: json['id'],
        title: json['title'],
        message: json['message'],
        category: json['category'],
        openDate: DateTime.parse(json['openDate']),
        createdAt: DateTime.parse(json['createdAt']),
        imageBase64: json['imageBase64'],
      );
}

class CapsuleStorage {
  static const storageKey = 'time_capsule_items_v1';

  static Future<List<Capsule>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(storageKey);
    if (raw == null) return [];

    try {
      final List<dynamic> data = jsonDecode(raw);
      return data
          .map((item) => Capsule.fromJson(
                Map<String, dynamic>.from(item),
              ))
          .toList()
        ..sort((a, b) => a.openDate.compareTo(b.openDate));
    } catch (_) {
      return [];
    }
  }

  static Future<void> save(List<Capsule> capsules) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      storageKey,
      jsonEncode(capsules.map((c) => c.toJson()).toList()),
    );
  }
}

// ------------------------------------------------------------
// HOME DASHBOARD
// ------------------------------------------------------------

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<Capsule> capsules = [];
  bool loading = true;
  String search = '';
  String filter = 'All';
  Timer? clock;

  @override
  void initState() {
    super.initState();
    loadCapsules();

    // Refresh countdowns and check for newly unlocked capsules.
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
    final result = await CapsuleStorage.load();
    if (!mounted) return;

    setState(() {
      capsules = result;
      loading = false;
    });
  }

  Future<void> addCapsule() async {
    final result = await Navigator.push<Capsule>(
      context,
      MaterialPageRoute(builder: (_) => const AddCapsulePage()),
    );

    if (result == null) return;

    final updated = [...capsules, result]
      ..sort((a, b) => a.openDate.compareTo(b.openDate));

    await CapsuleStorage.save(updated);

    try {
      await NotificationService.schedule(result);
    } catch (e) {
      debugPrint('Notification scheduling failed: $e');
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

  Future<void> deleteCapsule(Capsule capsule) async {
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

    if (confirm != true) return;

    final updated = capsules.where((c) => c.id != capsule.id).toList();
    await CapsuleStorage.save(updated);

    try {
      await NotificationService.cancel(capsule);
    } catch (e) {
      debugPrint('Notification cancellation failed: $e');
    }

    if (mounted) setState(() => capsules = updated);
  }

  @override
  Widget build(BuildContext context) {
    final opened = capsules.where((c) => c.isUnlocked).length;
    final locked = capsules.length - opened;

    final visible = capsules.where((c) {
      final matchesSearch =
          c.title.toLowerCase().contains(search.toLowerCase()) ||
              c.category.toLowerCase().contains(search.toLowerCase());

      final matchesFilter = filter == 'All' ||
          (filter == 'Locked' && !c.isUnlocked) ||
          (filter == 'Opened' && c.isUnlocked);

      return matchesSearch && matchesFilter;
    }).toList();

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: addCapsule,
        backgroundColor: purple,
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
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: purple.withValues(alpha: 0.16),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: const Icon(
                                Icons.hourglass_top_rounded,
                                color: purple,
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
                              color: purple.withValues(alpha: 0.4),
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
                              Row(
                                children: [
                                  stat('TOTAL', capsules.length),
                                  const SizedBox(width: 28),
                                  stat('LOCKED', locked),
                                  const SizedBox(width: 28),
                                  stat('OPENED', opened),
                                ],
                              ),
                              const SizedBox(height: 22),
                              FilledButton.icon(
                                onPressed: addCapsule,
                                icon: const Icon(Icons.edit_note_rounded),
                                label: const Text('Create a memory'),
                                style: FilledButton.styleFrom(
                                  backgroundColor: purple,
                                  foregroundColor: Colors.white,
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
                              selectedColor: purple.withValues(alpha: 0.3),
                              onSelected: (_) => setState(() => filter = item),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 14),
                        if (visible.isEmpty)
                          Container(
                            padding: const EdgeInsets.all(30),
                            decoration: BoxDecoration(
                              color: surface,
                              borderRadius: BorderRadius.circular(24),
                            ),
                            child: const Column(
                              children: [
                                Icon(
                                  Icons.inventory_2_outlined,
                                  size: 44,
                                  color: purple,
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
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => CapsuleDetailsPage(
                                    capsule: capsule,
                                    onDelete: () => deleteCapsule(capsule),
                                  ),
                                ),
                              ),
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
        style: const TextStyle(
          fontSize: 23,
          fontWeight: FontWeight.bold,
        ),
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

// ------------------------------------------------------------
// CAPSULE CARD WITH LIVE COUNTDOWN
// ------------------------------------------------------------

class CapsuleCard extends StatelessWidget {
  final Capsule capsule;
  final VoidCallback onTap;

  const CapsuleCard({
    super.key,
    required this.capsule,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final unlocked = capsule.isUnlocked;

    return Card(
      color: surface,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: BorderSide(color: purple.withValues(alpha: 0.12)),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                height: 56,
                width: 56,
                decoration: BoxDecoration(
                  color: purple.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(17),
                ),
                child: Icon(
                  unlocked
                      ? Icons.mark_email_read_rounded
                      : Icons.lock_clock_rounded,
                  color: purple,
                  size: 27,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      capsule.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '${capsule.category} • ${formatDate(capsule.openDate)}',
                      style: const TextStyle(
                        color: Colors.white60,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (unlocked)
                      const Text(
                        '✨ Ready to open',
                        style: TextStyle(color: Colors.greenAccent),
                      )
                    else
                      CountdownText(
                        target: capsule.openDate,
                        compact: true,
                      ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: Colors.white54),
            ],
          ),
        ),
      ),
    );
  }
}

// ------------------------------------------------------------
// LIVE COUNTDOWN
// ------------------------------------------------------------

class CountdownText extends StatefulWidget {
  final DateTime target;
  final bool compact;

  const CountdownText({
    super.key,
    required this.target,
    this.compact = false,
  });

  @override
  State<CountdownText> createState() => _CountdownTextState();
}

class _CountdownTextState extends State<CountdownText> {
  Timer? timer;

  @override
  void initState() {
    super.initState();
    timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final remaining = widget.target.difference(DateTime.now());

    if (remaining <= Duration.zero) {
      return Text(
        '✨ Your moment has arrived!',
        style: TextStyle(
          color: Colors.greenAccent,
          fontSize: widget.compact ? 12 : 15,
          fontWeight: FontWeight.bold,
        ),
      );
    }

    final days = remaining.inDays;
    final hours = remaining.inHours % 24;
    final minutes = remaining.inMinutes % 60;
    final seconds = remaining.inSeconds % 60;

    if (widget.compact) {
      return Text(
        '${days}d ${hours}h ${minutes}m ${seconds}s remaining',
        style: const TextStyle(color: purple, fontSize: 12),
      );
    }

    return Row(
      children: [
        timeUnit(days, 'DAYS'),
        timeUnit(hours, 'HRS'),
        timeUnit(minutes, 'MIN'),
        timeUnit(seconds, 'SEC'),
      ],
    );
  }

  Widget timeUnit(int value, String label) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.only(right: 7),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
        decoration: BoxDecoration(
          color: purple.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: purple.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            Text(
              value.toString().padLeft(2, '0'),
              style: const TextStyle(
                fontSize: 23,
                fontWeight: FontWeight.bold,
                color: purple,
              ),
            ),
            Text(
              label,
              style: const TextStyle(
                fontSize: 9,
                color: Colors.white60,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ------------------------------------------------------------
// CREATE CAPSULE
// ------------------------------------------------------------

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
  String? imageBase64;

  @override
  void dispose() {
    titleController.dispose();
    messageController.dispose();
    super.dispose();
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
      // Capsules open at 9 AM on the selected date.
      setState(() {
        openDate = DateTime(picked.year, picked.month, picked.day, 9);
      });
    }
  }

  Future<void> choosePhoto() async {
    try {
      final file = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 45,
        maxWidth: 900,
      );

      if (file == null) return;

      final bytes = await file.readAsBytes();

      if (bytes.length > 800000) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Choose a smaller photo (under 800 KB).'),
          ),
        );
        return;
      }

      setState(() => imageBase64 = base64Encode(bytes));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not select photo: $e')),
      );
    }
  }

  void saveCapsule() {
    if (!formKey.currentState!.validate()) return;

    final capsule = Capsule(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      title: titleController.text.trim(),
      message: messageController.text.trim(),
      category: category,
      openDate: openDate,
      createdAt: DateTime.now(),
      imageBase64: imageBase64,
    );

    Navigator.pop(context, capsule);
  }

  @override
  Widget build(BuildContext context) {
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
                  color: purple,
                  size: 56,
                ),
                const SizedBox(height: 12),
                const Text(
                  'Write something worth remembering.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 23,
                    fontWeight: FontWeight.bold,
                  ),
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
                    hintText:
                        'What do you want your future self to remember?',
                    alignLabelWithHint: true,
                  ),
                  validator: (v) => v == null || v.trim().isEmpty
                      ? 'Write a message first'
                      : null,
                ),
                const SizedBox(height: 12),
                Container(
                  decoration: BoxDecoration(
                    color: surface,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: ListTile(
                    leading: const Icon(
                      Icons.calendar_month_rounded,
                      color: purple,
                    ),
                    title: const Text('Opening date'),
                    subtitle: Text(formatDate(openDate)),
                    trailing: const Icon(Icons.edit_calendar_rounded),
                    onTap: chooseDate,
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: choosePhoto,
                  icon: Icon(
                    imageBase64 == null
                        ? Icons.add_photo_alternate_outlined
                        : Icons.check_circle_outline,
                  ),
                  label: Text(
                    imageBase64 == null ? 'Attach a photo' : 'Photo attached',
                  ),
                ),
                if (imageBase64 != null) ...[
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.memory(
                      base64Decode(imageBase64!),
                      height: 180,
                      fit: BoxFit.cover,
                    ),
                  ),
                  TextButton(
                    onPressed: () => setState(() => imageBase64 = null),
                    child: const Text('Remove photo'),
                  ),
                ],
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: saveCapsule,
                  icon: const Icon(Icons.lock_outline_rounded),
                  label: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 14),
                    child: Text('Seal my capsule'),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: purple,
                    foregroundColor: Colors.white,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Saved on this device. This version does not sync '
                  'between devices.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white54, fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ------------------------------------------------------------
// CAPSULE DETAILS AND MAGICAL OPENING ANIMATION
// ------------------------------------------------------------

class CapsuleDetailsPage extends StatefulWidget {
  final Capsule capsule;
  final Future<void> Function() onDelete;

  const CapsuleDetailsPage({
    super.key,
    required this.capsule,
    required this.onDelete,
  });

  @override
  State<CapsuleDetailsPage> createState() => _CapsuleDetailsPageState();
}

class _CapsuleDetailsPageState extends State<CapsuleDetailsPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController animation;
  Timer? clock;
  bool wasUnlocked = false;

  @override
  void initState() {
    super.initState();

    wasUnlocked = widget.capsule.isUnlocked;

    animation = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );

    if (wasUnlocked) {
      animation.value = 1;
    }

    clock = Timer.periodic(const Duration(seconds: 1), (_) {
      final nowUnlocked = widget.capsule.isUnlocked;

      if (nowUnlocked && !wasUnlocked) {
        wasUnlocked = true;
        animation.forward(from: 0);
      }

      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    clock?.cancel();
    animation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final capsule = widget.capsule;
    final unlocked = capsule.isUnlocked;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Your capsule'),
        actions: [
          IconButton(
            tooltip: 'Delete capsule',
            onPressed: () async {
              await widget.onDelete();
              if (context.mounted) Navigator.pop(context);
            },
            icon: const Icon(Icons.delete_outline_rounded),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700),
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              AnimatedBuilder(
                animation: animation,
                builder: (context, child) {
                  final glow = unlocked ? animation.value : 0.15;

                  return Container(
                    padding: const EdgeInsets.all(26),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(28),
                      gradient: const LinearGradient(
                        colors: [
                          Color(0xFF422565),
                          Color(0xFF211631),
                          Color(0xFF100D19),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      border: Border.all(
                        color: purple.withValues(alpha: 0.25 + glow * 0.6),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: purple.withValues(alpha: glow * 0.35),
                          blurRadius: 35 * glow,
                          spreadRadius: 2 * glow,
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        SizedBox(
                          height: 130,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              if (unlocked)
                                ...List.generate(12, (i) {
                                  final angle = i * math.pi / 6;
                                  final distance = 28 + animation.value * 42;

                                  return Transform.translate(
                                    offset: Offset(
                                      math.cos(angle) * distance,
                                      math.sin(angle) * distance,
                                    ),
                                    child: Opacity(
                                      opacity: (1 - animation.value * 0.45)
                                          .clamp(0.0, 1.0),
                                      child: const Icon(
                                        Icons.auto_awesome,
                                        color: Color(0xFFE3D2FF),
                                        size: 15,
                                      ),
                                    ),
                                  );
                                }),
                              Transform.scale(
                                scale: unlocked
                                    ? 1 + math.sin(animation.value * math.pi) * 0.2
                                    : 1,
                                child: Icon(
                                  unlocked
                                      ? Icons.mark_email_read_rounded
                                      : Icons.lock_clock_rounded,
                                  size: 68,
                                  color: purple,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          unlocked
                              ? 'Your moment has arrived!'
                              : 'A message for later',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (!unlocked) ...[
                          const Text(
                            'Your letter is waiting for its moment.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.white70),
                          ),
                          const SizedBox(height: 22),
                          CountdownText(target: capsule.openDate),
                        ] else ...[
                          const SizedBox(height: 8),
                          const Text(
                            'Take a breath. Meet your past self again.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.white70),
                          ),
                        ],
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 26),
              Text(
                capsule.title,
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${capsule.category} • Created ${formatDate(capsule.createdAt)}',
                style: const TextStyle(color: Colors.white54),
              ),
              const SizedBox(height: 20),
              if (unlocked) ...[
                if (capsule.imageBase64 != null) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Image.memory(
                      base64Decode(capsule.imageBase64!),
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
                AnimatedBuilder(
                  animation: animation,
                  builder: (context, child) => Opacity(
                    opacity: animation.value,
                    child: Transform.translate(
                      offset: Offset(0, 20 * (1 - animation.value)),
                      child: child,
                    ),
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      color: surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: purple.withValues(alpha: 0.18),
                      ),
                    ),
                    child: SelectableText(
                      capsule.message,
                      style: const TextStyle(height: 1.8, fontSize: 16),
                    ),
                  ),
                ),
              ] else
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: surface,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Column(
                    children: [
                      Icon(
                        Icons.lock_rounded,
                        color: purple,
                        size: 42,
                      ),
                      SizedBox(height: 12),
                      Text(
                        'The words are still a secret.',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Return when the countdown reaches zero.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white60),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 25),
              if (unlocked)
                OutlinedButton.icon(
                  onPressed: () {
                    showDialog<void>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('A message from the past 💜'),
                        content: const Text(
                          'Take a moment to notice how far you have come. '
                          'Your past self believed you would make it here.',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Thank you, past me'),
                          ),
                        ],
                      ),
                    );
                  },
                  icon: const Icon(Icons.favorite_outline_rounded),
                  label: const Text('Celebrate this moment'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ------------------------------------------------------------
// DATE FORMAT
// ------------------------------------------------------------

String formatDate(DateTime date) {
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  return '${date.day} ${months[date.month - 1]} ${date.year}';
}