/// Display fields copied from the auth user. Not used for authorization.
///
/// RLS and edge functions keep using `auth.uid()`. `user_metadata` only
/// supplies a name and a locale for the profile row.
String? displayNameFromMetadata(Map<String, dynamic>? metadata) {
  if (metadata == null) return null;
  for (final key in const ['display_name', 'full_name', 'name']) {
    final value = metadata[key];
    if (value is String) {
      final trimmed = value.trim();
      if (trimmed.isNotEmpty) return trimmed;
    }
  }
  return null;
}

/// App locales are `cs`, `en`, and `de`. Anything else stays on Czech.
String localeFromMetadata(Map<String, dynamic>? metadata) {
  final value = metadata?['locale'];
  if (value is String && (value == 'cs' || value == 'en' || value == 'de')) {
    return value;
  }
  return 'cs';
}

/// Supabase returns these when the Google or Apple provider is off.
bool authProviderDisabled({String? code, required String message}) {
  final normalized = code?.toLowerCase() ?? '';
  if (normalized == 'provider_disabled' ||
      normalized == 'oauth_provider_not_supported') {
    return true;
  }
  final text = message.toLowerCase();
  return text.contains('not enabled') ||
      text.contains('provider is disabled') ||
      text.contains('unsupported provider') ||
      text.contains('provider_disabled');
}
