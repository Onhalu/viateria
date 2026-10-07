import 'package:supabase_flutter/supabase_flutter.dart';

class DiplomaAccess {
  const DiplomaAccess({required this.state, this.completionLabel});

  /// `locked` | `buy` | `need_name` | `render` | `ready` | `revoked` | `unavailable`.
  final String state;
  final String? completionLabel;
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
}

class MemoryDiplomaClient implements DiplomaClient {
  MemoryDiplomaClient({
    this.accessState = 'unavailable',
    this.completionLabel,
    this.imageUrl,
    this.imageError,
  });

  String accessState;
  String? completionLabel;
  String? imageUrl;
  String? imageError;
  final List<String> imageRequests = [];

  @override
  Future<DiplomaAccess> access(String challengeId) async {
    return DiplomaAccess(state: accessState, completionLabel: completionLabel);
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
      if (raw is! Map) return const DiplomaAccess(state: 'unavailable');
      final map = Map<String, dynamic>.from(raw);
      final state = map['state'] as String? ?? 'unavailable';
      return DiplomaAccess(
        state: state,
        completionLabel: map['completion_day_label'] as String?,
      );
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
