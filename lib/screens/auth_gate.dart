import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../utils/app_state.dart';
import 'home_page.dart';
import 'login_page.dart';

/// Shows the login page, or the home page once signed in.
/// If Supabase is unavailable (or the user taps "Continue without account")
/// the app runs in local-only mode.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool guest = false;

  @override
  Widget build(BuildContext context) {
    final client = cloud;

    if (client == null) {
      return const HomePage(key: ValueKey('guest'));
    }

    return StreamBuilder<AuthState>(
      stream: client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        final session = snapshot.data?.session ?? client.auth.currentSession;

        if (session != null) {
          return HomePage(
            key: ValueKey(session.user.id),
            userId: session.user.id,
          );
        }

        if (guest) {
          return const HomePage(key: ValueKey('guest'));
        }

        return LoginPage(
          onGuest: () => setState(() => guest = true),
        );
      },
    );
  }
}