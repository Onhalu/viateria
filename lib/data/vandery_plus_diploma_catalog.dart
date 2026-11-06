import 'package:supabase_flutter/supabase_flutter.dart';

/// Columns granted to `authenticated` on `vandery_plus_diplomas`.
/// The rule column is omitted. Selecting every column is 42501.
const vanderyPlusDiplomaColumns =
    'id, slug, title_i18n, is_hidden, asset_ref, created_at';

const vanderyPlusUserDiplomaColumns = 'user_id, diploma_id, unlocked_at';

class VanderyPlusDiplomaRow {
  const VanderyPlusDiplomaRow({
    required this.id,
    required this.slug,
    required this.titleI18n,
    required this.isHidden,
    this.assetRef,
  });

  final String id;
  final String slug;
  final Map<String, dynamic> titleI18n;
  final bool isHidden;
  final String? assetRef;

  factory VanderyPlusDiplomaRow.fromJson(Map<String, dynamic> row) {
    final title = row['title_i18n'];
    return VanderyPlusDiplomaRow(
      id: row['id'] as String,
      slug: row['slug'] as String,
      titleI18n: title is Map ? Map<String, dynamic>.from(title) : const {},
      isHidden: row['is_hidden'] == true,
      assetRef: row['asset_ref'] as String?,
    );
  }
}

/// Reads the catalog with the granted columns only.
class SupabaseVanderyPlusDiplomaCatalog {
  SupabaseVanderyPlusDiplomaCatalog(this._client);

  final SupabaseClient _client;

  Future<List<VanderyPlusDiplomaRow>> fetchVisible() async {
    final rows = await _client
        .from('vandery_plus_diplomas')
        .select(vanderyPlusDiplomaColumns);
    return [
      for (final row in rows)
        VanderyPlusDiplomaRow.fromJson(Map<String, dynamic>.from(row)),
    ];
  }
}
