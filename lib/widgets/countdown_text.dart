import 'dart:async';

import 'package:flutter/material.dart';

import '../utils/app_constants.dart';

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
        style: const TextStyle(color: AppColors.purple, fontSize: 12),
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
          color: AppColors.purple.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.purple.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            Text(
              value.toString().padLeft(2, '0'),
              style: const TextStyle(
                fontSize: 23,
                fontWeight: FontWeight.bold,
                color: AppColors.purple,
              ),
            ),
            Text(
              label,
              style: const TextStyle(fontSize: 9, color: Colors.white60),
            ),
          ],
        ),
      ),
    );
  }
}