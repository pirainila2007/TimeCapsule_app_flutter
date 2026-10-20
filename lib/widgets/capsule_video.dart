import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../models/capsule.dart';
import '../services/media_service.dart';
import '../utils/app_constants.dart';

/// Streams a capsule's video from Supabase Storage with play / pause / seek.
class CapsuleVideo extends StatefulWidget {
  final Capsule capsule;

  const CapsuleVideo({super.key, required this.capsule});

  @override
  State<CapsuleVideo> createState() => _CapsuleVideoState();
}

class _CapsuleVideoState extends State<CapsuleVideo> {
  VideoPlayerController? controller;
  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final url = await MediaService().signedUrl(widget.capsule.mediaPath);

      if (url == null) throw Exception('No video link');

      final c = VideoPlayerController.networkUrl(Uri.parse(url));
      await c.initialize();

      if (!mounted) {
        await c.dispose();
        return;
      }

      c.addListener(() {
        if (mounted) setState(() {});
      });

      setState(() {
        controller = c;
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        error = 'Video unavailable (check your internet).';
        loading = false;
      });
    }
  }

  @override
  void dispose() {
    controller?.dispose();
    super.dispose();
  }

  String _format(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  Widget _box(Widget child) {
    return Container(
      height: 200,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return _box(const CircularProgressIndicator());

    final c = controller;

    if (error != null || c == null) {
      return _box(
        Text(
          error ?? 'Video unavailable.',
          style: const TextStyle(color: Colors.white54),
        ),
      );
    }

    final value = c.value;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          GestureDetector(
            onTap: () => value.isPlaying ? c.pause() : c.play(),
            child: AspectRatio(
              aspectRatio: value.aspectRatio == 0 ? 16 / 9 : value.aspectRatio,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  VideoPlayer(c),
                  if (!value.isPlaying)
                    Container(
                      decoration: const BoxDecoration(
                        color: Colors.black45,
                        shape: BoxShape.circle,
                      ),
                      padding: const EdgeInsets.all(10),
                      child: const Icon(
                        Icons.play_arrow_rounded,
                        size: 44,
                        color: Colors.white,
                      ),
                    ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 14, 8),
            child: Row(
              children: [
                IconButton(
                  onPressed: () => value.isPlaying ? c.pause() : c.play(),
                  icon: Icon(
                    value.isPlaying
                        ? Icons.pause_rounded
                        : Icons.play_arrow_rounded,
                    color: AppColors.purple,
                  ),
                ),
                Expanded(
                  child: VideoProgressIndicator(
                    c,
                    allowScrubbing: true,
                    colors: const VideoProgressColors(
                      playedColor: AppColors.purple,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  '${_format(value.position)} / ${_format(value.duration)}',
                  style: const TextStyle(color: Colors.white60, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}