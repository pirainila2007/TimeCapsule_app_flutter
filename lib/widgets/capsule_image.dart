import 'dart:convert';

import 'package:flutter/material.dart';

import '../models/capsule.dart';
import '../services/media_service.dart';
import '../utils/app_constants.dart';

/// Shows a capsule's photo: from Supabase Storage (signed link) when the
/// capsule has a `mediaPath`, otherwise from the old inline base64 photo.
class CapsuleImage extends StatefulWidget {
  final Capsule capsule;

  const CapsuleImage({super.key, required this.capsule});

  @override
  State<CapsuleImage> createState() => _CapsuleImageState();
}

class _CapsuleImageState extends State<CapsuleImage> {
  Future<String?>? urlFuture;

  @override
  void initState() {
    super.initState();

    final path = widget.capsule.mediaPath;

    if (path != null) {
      urlFuture = MediaService().signedUrl(path);
    }
  }

  Widget _box(Widget child) {
    return Container(
      height: 180,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: child,
    );
  }

  Widget _unavailable() {
    return _box(
      const Text(
        'Photo unavailable (check your internet).',
        style: TextStyle(color: Colors.white54),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final capsule = widget.capsule;

    if (capsule.mediaPath == null) {
      final inline = capsule.imageBase64;

      if (inline == null) return const SizedBox.shrink();

      return ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Image.memory(base64Decode(inline), fit: BoxFit.cover),
      );
    }

    return FutureBuilder<String?>(
      future: urlFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return _box(const CircularProgressIndicator());
        }

        final url = snapshot.data;

        if (snapshot.hasError || url == null) return _unavailable();

        return ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Image.network(
            url,
            fit: BoxFit.cover,
            loadingBuilder: (context, child, progress) {
              if (progress == null) return child;
              return _box(const CircularProgressIndicator());
            },
            errorBuilder: (context, error, stackTrace) => _unavailable(),
          ),
        );
      },
    );
  }
}