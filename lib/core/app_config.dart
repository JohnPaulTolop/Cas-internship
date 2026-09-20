class AppConfig {
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabasePublishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
  );
  static const supabaseBucket = String.fromEnvironment(
    'SUPABASE_BUCKET',
    defaultValue: 'internship-documents',
  );

  static bool get hasSupabaseConfig =>
      supabaseUrl.isNotEmpty && supabasePublishableKey.isNotEmpty;
}
