import 'package:flutter/material.dart';

import '../models/capsule.dart';
import '../utils/app_constants.dart';
import 'countdown_text.dart';

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
      color: AppColors.surface,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: BorderSide(color: AppColors.purple.withValues(alpha: 0.12)),
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
                  color: AppColors.purple.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(17),
                ),
                child: Icon(
                  unlocked
                      ? Icons.mark_email_read_rounded
                      : Icons.lock_clock_rounded,
                  color: AppColors.purple,
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
                      CountdownText(target: capsule.openDate, compact: true),
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