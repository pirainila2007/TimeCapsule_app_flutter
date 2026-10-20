import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/auth_service.dart';
import '../services/profile_service.dart';
import '../utils/app_constants.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final nameController = TextEditingController();
  final profileService = ProfileService();
  final authService = AuthService();

  bool loading = true;
  bool saving = false;
  String? avatarPath;
  String? avatarUrl;
  String? error;

  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    nameController.dispose();
    super.dispose();
  }

  Future<void> load() async {
    try {
      final profile = await profileService.loadProfile();
      final metaName = authService.currentUser?.userMetadata?['full_name'];

      nameController.text =
          (profile?['full_name'] as String?) ?? (metaName as String?) ?? '';
      avatarPath = profile?['avatar_url'] as String?;
      avatarUrl = await _signedUrl(avatarPath);
    } catch (e) {
      error = 'Could not load your profile. Check your internet.';
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<String?> _signedUrl(String? path) async {
    try {
      return await profileService.signedAvatarUrl(path);
    } catch (_) {
      return null;
    }
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> save({String? message}) async {
    setState(() => saving = true);

    try {
      await profileService.saveProfile(
        fullName: nameController.text,
        avatarUrl: avatarPath,
      );
      _toast(message ?? 'Profile saved 💜');
    } catch (e) {
      _toast('Could not save profile: $e');
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> pickAvatar() async {
    try {
      final file = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 70,
        maxWidth: 600,
      );

      if (file == null) return;

      setState(() => saving = true);

      final bytes = await file.readAsBytes();
      final dot = file.name.lastIndexOf('.');
      final extension = dot == -1 ? 'jpg' : file.name.substring(dot + 1);

      final path = await profileService.uploadAvatar(bytes, extension);
      final url = await _signedUrl(path);

      if (!mounted) return;

      setState(() {
        avatarPath = path;
        avatarUrl = url;
      });

      await save(message: 'Photo updated 💜');
    } catch (e) {
      _toast('Could not upload photo: $e');
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> signOut() async {
    await authService.signOut();

    if (!mounted) return;

    // Back to the root; AuthGate shows the login page.
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final email = authService.currentUser?.email ?? '';

    return Scaffold(
      appBar: AppBar(title: const Text('Your profile')),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: ListView(
                  padding: const EdgeInsets.all(24),
                  children: [
                    Center(
                      child: Stack(
                        children: [
                          CircleAvatar(
                            radius: 56,
                            backgroundColor:
                                AppColors.purple.withValues(alpha: 0.2),
                            backgroundImage: avatarUrl == null
                                ? null
                                : NetworkImage(avatarUrl!),
                            child: avatarUrl == null
                                ? const Icon(
                                    Icons.person_rounded,
                                    size: 56,
                                    color: AppColors.purple,
                                  )
                                : null,
                          ),
                          Positioned(
                            right: 0,
                            bottom: 0,
                            child: CircleAvatar(
                              radius: 18,
                              backgroundColor: AppColors.purple,
                              child: IconButton(
                                padding: EdgeInsets.zero,
                                tooltip: 'Change photo',
                                onPressed: saving ? null : pickAvatar,
                                icon: const Icon(
                                  Icons.camera_alt_rounded,
                                  size: 18,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      email,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white60),
                    ),
                    if (error != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        error!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.redAccent),
                      ),
                    ],
                    const SizedBox(height: 28),
                    const Text('Your name'),
                    const SizedBox(height: 8),
                    TextField(
                      controller: nameController,
                      textCapitalization: TextCapitalization.words,
                      maxLength: 60,
                      decoration: const InputDecoration(
                        hintText: 'What should we call you?',
                        prefixIcon: Icon(Icons.person_outline_rounded),
                      ),
                    ),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: saving ? null : save,
                      icon: saving
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                              ),
                            )
                          : const Icon(Icons.check_rounded),
                      label: const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Text('Save profile'),
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.purple,
                        foregroundColor: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 28),
                    OutlinedButton.icon(
                      onPressed: saving ? null : signOut,
                      icon: const Icon(Icons.logout_rounded),
                      label: const Text('Sign out'),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'Your capsules sync to your account, so you can open '
                      'them on any device.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}