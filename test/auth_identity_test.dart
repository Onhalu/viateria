import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:viateria/config/auth_redirect.dart';
import 'package:viateria/data/auth_identity.dart';

void main() {
  test('display name prefers app metadata, then OAuth name fields', () {
    expect(
      displayNameFromMetadata({'display_name': ' Ada ', 'full_name': 'Other'}),
      'Ada',
    );
    expect(
      displayNameFromMetadata({'full_name': 'Grace Hopper'}),
      'Grace Hopper',
    );
    expect(displayNameFromMetadata({'name': 'Ada'}), 'Ada');
    expect(displayNameFromMetadata({'full_name': '  '}), isNull);
    expect(displayNameFromMetadata(null), isNull);
  });

  test('locale stays on cs, en, or de', () {
    expect(localeFromMetadata({'locale': 'de'}), 'de');
    expect(localeFromMetadata({'locale': 'fr'}), 'cs');
    expect(localeFromMetadata(null), 'cs');
  });

  test('provider-disabled errors are recognized by code and message', () {
    expect(
      authProviderDisabled(code: 'provider_disabled', message: 'nope'),
      isTrue,
    );
    expect(
      authProviderDisabled(
        code: 'oauth_provider_not_supported',
        message: 'Google',
      ),
      isTrue,
    );
    expect(
      authProviderDisabled(
        code: 'unexpected_failure',
        message: 'Provider is not enabled',
      ),
      isTrue,
    );
    expect(
      authProviderDisabled(
        code: 'invalid_credentials',
        message: 'Invalid login credentials',
      ),
      isFalse,
    );
  });

  test('mobile redirect is the custom scheme, not the Supabase callback', () {
    expect(AuthRedirect.mobile, 'com.viateria.viateria://login-callback');
    expect(AuthRedirect.forCurrentPlatform(), AuthRedirect.mobile);
    expect(
      AuthRedirect.supabaseProviderCallback,
      'https://yzmbxxgesnbsqygzgdky.supabase.co/auth/v1/callback',
    );
    expect(
      AuthRedirect.webRedirectFrom(
        Uri.parse('https://viateria.limitlessdreams.cz/#/auth?code=secret'),
      ),
      'https://viateria.limitlessdreams.cz/',
    );
    expect(
      AuthRedirect.webRedirectFrom(Uri.parse('http://localhost:54321/auth')),
      'http://localhost:54321/auth/',
    );
  });

  test('oauth profile migration copies names and does not touch RLS', () {
    final sql = File('supabase/migrations/0010_oauth_profile_name.sql')
        .readAsStringSync();
    expect(sql, contains("raw_user_meta_data ->> 'full_name'"));
    expect(sql, contains("raw_user_meta_data ->> 'display_name'"));
    expect(sql, contains("raw_user_meta_data ->> 'name'"));
    expect(sql, contains('handle_new_user'));
    expect(sql, isNot(contains('service_role')));
    expect(sql, isNot(contains('create policy')));
    expect(sql, isNot(contains('auth.uid()')));
  });
}
