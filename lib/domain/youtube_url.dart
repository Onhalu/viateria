/// YouTube watch / share / embed / shorts → 11-character video id.
///
/// Returns null when [raw] is not a YouTube URL the in-app embed can play.
String? youtubeVideoId(String? raw) {
  final trimmed = raw?.trim();
  if (trimmed == null || trimmed.isEmpty) return null;
  final uri = Uri.tryParse(trimmed);
  if (uri == null || !uri.hasScheme) return null;
  final host = uri.host.toLowerCase();
  if (host == 'youtu.be' || host.endsWith('.youtu.be')) {
    if (uri.pathSegments.isEmpty) return null;
    return _idOrNull(uri.pathSegments.first);
  }
  if (host != 'youtube.com' &&
      host != 'm.youtube.com' &&
      host != 'www.youtube.com' &&
      host != 'music.youtube.com' &&
      host != 'youtube-nocookie.com' &&
      host != 'www.youtube-nocookie.com') {
    return null;
  }
  final segments = uri.pathSegments;
  if (segments.length >= 2 &&
      (segments.first == 'embed' ||
          segments.first == 'shorts' ||
          segments.first == 'live')) {
    return _idOrNull(segments[1]);
  }
  return _idOrNull(uri.queryParameters['v']);
}

/// Privacy-enhanced embed. Empty playlist and no related videos at the end.
Uri youtubeEmbedUri(String videoId) {
  return Uri.https('www.youtube-nocookie.com', '/embed/$videoId', {
    'rel': '0',
    'modestbranding': '1',
    'playsinline': '1',
  });
}

final _videoId = RegExp(r'^[A-Za-z0-9_-]{11}$');

String? _idOrNull(String? value) {
  final id = value?.trim();
  if (id == null || !_videoId.hasMatch(id)) return null;
  return id;
}
