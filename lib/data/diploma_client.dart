import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/diploma_phase.dart';

class DiplomaAccess {
  const DiplomaAccess({
    required this.state,
    this.completionLabel,
    this.diplomaId,
    this.recipientNameDisplay,
    this.nameEditable = false,
    this.nameSource = 'profile',
  });

  /// `locked` | `buy` | `need_name` | `render` | `ready` | `revoked` | `unavailable`.
  final String state;
  final String? completionLabel;
  final String? diplomaId;

  /// Name exactly as printed. Profile diplomas are already declined.
  final String? recipientNameDisplay;

  /// True until the owner uses the one-time edit.
  final bool nameEditable;

  /// `profile` while the name follows `profiles.display_name`, else `edited`.
  final String nameSource;
}

class DiplomaImageResult {
  const DiplomaImageResult({this.url, this.error, this.cached = false});

  final String? url;
  final String? error;
  final bool cached;

  bool get ok => url != null && url!.isNotEmpty;
}

abstract class DiplomaClient {
  Future<DiplomaAccess> access(String challengeId);
  Future<DiplomaImageResult> fetchImage(String challengeId);
  Future<DiplomaAccess> editName(String diplomaId, String name);
}

class MemoryDiplomaClient implements DiplomaClient {
  MemoryDiplomaClient({
    this.accessState = 'unavailable',
    this.completionLabel,
    this.imageUrl,
    this.imageError,
    this.diplomaId,
    this.recipientNameDisplay,
    this.nameEditable = false,
    this.nameSource = 'profile',
  });

  String accessState;
  String? completionLabel;
  String? imageUrl;
  String? imageError;
  String? diplomaId;
  String? recipientNameDisplay;
  bool nameEditable;
  String nameSource;
  final List<String> imageRequests = [];
  final List<String> nameEdits = [];

  DiplomaAccess get _access => DiplomaAccess(
    state: accessState,
    completionLabel: completionLabel,
    diplomaId: diplomaId,
    recipientNameDisplay: recipientNameDisplay,
    nameEditable: nameEditable,
    nameSource: nameSource,
  );

  @override
  Future<DiplomaAccess> access(String challengeId) async => _access;

  @override
  Future<DiplomaAccess> editName(String diplomaId, String name) async {
    final printed = normalizeDiplomaEditedName(name);
    if (printed == null || this.diplomaId != diplomaId || !nameEditable) {
      throw StateError('diploma name');
    }
    nameEdits.add(printed);
    recipientNameDisplay = printed;
    nameEditable = false;
    nameSource = 'edited';
    return _access;
  }

  @override
  Future<DiplomaImageResult> fetchImage(String challengeId) async {
    imageRequests.add(challengeId);
    return DiplomaImageResult(url: imageUrl, error: imageError);
  }
}

class SupabaseDiplomaClient implements DiplomaClient {
  SupabaseDiplomaClient(this._client);

  final SupabaseClient _client;

  @override
  Future<DiplomaAccess> access(String challengeId) async {
    try {
      final raw = await _client.rpc(
        'diploma_status',
        params: {'p_challenge_id': challengeId},
      );
      return _accessFrom(raw);
    } on PostgrestException catch (error) {
      final message = error.message.toLowerCase();
      if (error.code == 'PGRST202' ||
          error.code == '42883' ||
          message.contains('does not exist') ||
          message.contains('schema cache')) {
        return const DiplomaAccess(state: 'unavailable');
      }
      rethrow;
    }
  }

  @override
  Future<DiplomaAccess> editName(String diplomaId, String name) async {
    final raw = await _client.rpc(
      'edit_diploma_name',
      params: {'p_diploma_id': diplomaId, 'p_name': name},
    );
    return _accessFrom(raw);
  }

  @override
  Future<DiplomaImageResult> fetchImage(String challengeId) async {
    try {
      final response = await _client.functions.invoke(
        'diploma',
        body: {'challenge_id': challengeId},
      );
      final data = response.data;
      if (data is Map &&
          data['url'] is String &&
          (data['url'] as String).isNotEmpty) {
        return DiplomaImageResult(
          url: data['url'] as String,
          cached: data['cached'] == true,
        );
      }
      return const DiplomaImageResult(error: 'error');
    } on FunctionException catch (error) {
      return DiplomaImageResult(error: _functionError(error));
    }
  }
}

DiplomaAccess _accessFrom(Object? raw) {
  if (raw is! Map) return const DiplomaAccess(state: 'unavailable');
  final map = Map<String, dynamic>.from(raw);
  return DiplomaAccess(
    state: map['state'] as String? ?? 'unavailable',
    completionLabel: map['completion_day_label'] as String?,
    diplomaId: map['diploma_id'] as String?,
    recipientNameDisplay: map['recipient_name_display'] as String?,
    nameEditable: map['name_editable'] == true,
    nameSource: map['name_source'] as String? ?? 'profile',
  );
}

String _functionError(FunctionException error) {
  final details = error.details;
  if (details is Map && details['error'] is String) {
    return details['error'] as String;
  }
  if (error.status == 402) return 'not_entitled';
  if (error.status == 409) return 'need_name';
  if (error.status == 403) return 'revoked';
  if (error.status == 404) return 'not_found';
  return 'error';
}
