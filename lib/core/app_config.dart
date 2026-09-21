class AppConfig {
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');

  // Supabase now calls this the publishable key, while older projects and
  // tutorials commonly store the same client-safe value as SUPABASE_ANON_KEY.
  // Supporting both keeps existing config/local.json files working.
  static const _publishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
  );
  static const _anonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
  static const _legacyKey = String.fromEnvironment('SUPABASE_KEY');

  static const supabasePublishableKey = _publishableKey != ''
      ? _publishableKey
      : (_anonKey != '' ? _anonKey : _legacyKey);

  static const supabaseBucket = String.fromEnvironment(
    'SUPABASE_BUCKET',
    defaultValue: 'internship-documents',
  );

  // For a deployed Vercel build this may be omitted so the app uses the
  // same-origin /api/coordinator-approval endpoint. During local Flutter
  // development set it to the local approval helper URL shown in SETUP.md.
  static const _configuredCoordinatorApprovalApi = String.fromEnvironment(
    'COORDINATOR_APPROVAL_API_URL',
  );


  static const _configuredEvaluationApi = String.fromEnvironment(
    'EVALUATION_API_URL',
  );

  static String get evaluationApiUrl {
    final configured = _configuredEvaluationApi.trim();
    if (configured.isNotEmpty) return configured;

    final approval = _configuredCoordinatorApprovalApi.trim();
    if (approval.isNotEmpty) {
      final uri = Uri.tryParse(approval);
      if (uri != null) {
        return uri.resolve('/api/evaluation').toString();
      }
    }
    return Uri.base.resolve('/api/evaluation').toString();
  }

  static String get coordinatorApprovalApiUrl {
    final configured = _configuredCoordinatorApprovalApi.trim();
    if (configured.isNotEmpty) return configured;
    return Uri.base.resolve('/api/coordinator-approval').toString();
  }

  static String get staffClaimsApiUrl {
    final approval = coordinatorApprovalApiUrl.trim();
    final uri = Uri.tryParse(approval);
    if (uri != null) {
      return uri.resolve('/api/staff-claims').toString();
    }
    return Uri.base.resolve('/api/staff-claims').toString();
  }

  static bool get hasSupabaseConfig =>
      supabaseUrl.trim().isNotEmpty && supabasePublishableKey.trim().isNotEmpty;

  static String get missingSupabaseMessage =>
      'Supabase storage is not configured. Start the app with '
      '--dart-define-from-file=config/local.json and make sure the file contains '
      'SUPABASE_URL plus SUPABASE_PUBLISHABLE_KEY (or SUPABASE_ANON_KEY).';
}
