import 'package:supabase_flutter/supabase_flutter.dart';

/// Set to true in main() once Supabase.initialize succeeded.
bool supabaseReady = false;

SupabaseClient? get cloud => supabaseReady ? Supabase.instance.client : null;

String? get currentUserId => cloud?.auth.currentUser?.id;