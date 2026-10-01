import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../domain/youtube_url.dart';
import '../../theme/brand_colors.dart';

/// Mobile YouTube embed via [WebViewWidget]. Not used on Flutter web.
class StoryYoutubePlatform extends StatefulWidget {
  const StoryYoutubePlatform({super.key, required this.videoId});

  final String videoId;

  @override
  State<StoryYoutubePlatform> createState() => _StoryYoutubePlatformState();
}

class _StoryYoutubePlatformState extends State<StoryYoutubePlatform> {
  late final WebViewController _controller;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(BrandColors.cream)
      ..loadRequest(youtubeEmbedUri(widget.videoId));
  }

  @override
  Widget build(BuildContext context) {
    return WebViewWidget(
      key: Key('story-youtube-${widget.videoId}'),
      controller: _controller,
    );
  }
}
