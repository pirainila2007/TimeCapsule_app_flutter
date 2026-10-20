import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'screens/onboarding_screen.dart';
import 'utils/app_constants.dart';
import 'utils/app_state.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // App works locally even if Supabase is unreachable.
  try {
    await Supabase.initialize(
      url: 'https://fplsmmxhgukharifosql.supabase.co',
      publishableKey: 'sb_publishable_Rd_Xzg6XZgpz91zz7MyDVg_4v3GGTFh',
    );
    supabaseReady = true;
  } catch (e) {
    debugPrint('Supabase init failed: $e');
  }

  runApp(const TimeCapsuleApp());
}

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
        scaffoldBackgroundColor: AppColors.background,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.purple,
          brightness: Brightness.dark,
          surface: AppColors.surface,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: AppColors.surface,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: AppColors.purple),
          ),
        ),
      ),
      home: const OnboardingScreen(),
    );
  }
}