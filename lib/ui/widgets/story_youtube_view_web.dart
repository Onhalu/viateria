import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

import '../../domain/youtube_url.dart';

/// Flutter web YouTube embed. An iframe stays inside the app.
class StoryYoutubePlatform extends StatelessWidget {
  const StoryYoutubePlatform({super.key, required this.videoId});

  final String videoId;

  @override
  Widget build(BuildContext context) {
    return HtmlElementView.fromTagName(
      key: Key('story-youtube-$videoId'),
      tagName: 'iframe',
      onElementCreated: (element) {
        final iframe = element as web.HTMLIFrameElement;
        iframe
          ..src = youtubeEmbedUri(videoId).toString()
          ..title = 'YouTube'
          ..allow = 'accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share'
          ..allowFullscreen = true
          ..style.border = 'none'
          ..style.width = '100%'
          ..style.height = '100%'
          ..style.display = 'block';
      },
    );
  }
}
