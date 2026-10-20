import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/capsule.dart';
import '../utils/app_constants.dart';
import '../widgets/capsule_image.dart';
import '../widgets/capsule_video.dart';
import '../widgets/countdown_text.dart';

class CapsuleDetailsPage extends StatefulWidget {
  final Capsule capsule;
  final Future<bool> Function() onDelete;

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

  Future<void> deleteCapsule() async {
    final deleted = await widget.onDelete();

    if (deleted && mounted) {
      Navigator.pop(context);
    }
  }

  void celebrate() {
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
            onPressed: deleteCapsule,
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
                        color: AppColors.purple
                            .withValues(alpha: 0.25 + glow * 0.6),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color:
                              AppColors.purple.withValues(alpha: glow * 0.35),
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
                                    ? 1 +
                                        math.sin(animation.value * math.pi) *
                                            0.2
                                    : 1,
                                child: Icon(
                                  unlocked
                                      ? Icons.mark_email_read_rounded
                                      : Icons.lock_clock_rounded,
                                  size: 68,
                                  color: AppColors.purple,
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
                '${capsule.category} • '
                'Created ${formatDate(capsule.createdAt)}',
                style: const TextStyle(color: Colors.white54),
              ),
              const SizedBox(height: 20),
              if (unlocked) ...[
                if (capsule.hasImage) ...[
                  CapsuleImage(capsule: capsule),
                  const SizedBox(height: 20),
                ],
                if (capsule.hasVideo) ...[
                  CapsuleVideo(capsule: capsule),
                  const SizedBox(height: 20),
                ],
                AnimatedBuilder(
                  animation: animation,
                  builder: (context, child) {
                    return Opacity(
                      opacity: animation.value,
                      child: Transform.translate(
                        offset: Offset(0, 20 * (1 - animation.value)),
                        child: child,
                      ),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: AppColors.purple.withValues(alpha: 0.18),
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
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Column(
                    children: [
                      Icon(Icons.lock_rounded,
                          color: AppColors.purple, size: 42),
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
                  onPressed: celebrate,
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