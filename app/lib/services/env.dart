import 'package:flutter_riverpod/flutter_riverpod.dart';

class EnvConfig {
  final String supabaseUrl;
  final String supabaseAnonKey;

  const EnvConfig({
    required this.supabaseUrl,
    required this.supabaseAnonKey,
  });
}

// For MVP, we'll use hardcoded values that point to your cloud Supabase instance
// In production, these would come from environment variables or build config
final envProvider = Provider<EnvConfig>((ref) {
  return const EnvConfig(
    // ✅ Correct Supabase project URL (fixed spelling)
    supabaseUrl: 'https://kpyjhnnwijhtxizziuex.supabase.co/functions/v1',
    // ✅ Anon key looks correct (starts with correct format)
    supabaseAnonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImtweWpobm53aWpodHhpenppdWV4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTgwODIyOTQsImV4cCI6MjA3MzY1ODI5NH0.gu2MK_rzO3SI4m0k2ItVRPe3I3iUMKkNZaexaP0Oq74',
  );
});
