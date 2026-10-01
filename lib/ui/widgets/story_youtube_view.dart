import 'package:flutter/widgets.dart';

import 'story_youtube_view_io.dart'
    if (dart.library.html) 'story_youtube_view_web.dart'
    if (dart.library.js_interop) 'story_youtube_view_web.dart'
    as embed;

/// In-app YouTube player. Widget tests get a cream stand-in so they never
/// construct a platform webview.
class StoryYoutubeEmbed extends StatelessWidget {
  const StoryYoutubeEmbed({super.key, required this.videoId});

  final String videoId;

  static bool get _inWidgetTest {
    final name = WidgetsBinding.instance.runtimeType.toString();
    return name.contains('TestWidgetsFlutterBinding');
  }

  @override
  Widget build(BuildContext context) {
    if (_inWidgetTest) {
      return ColoredBox(
        key: Key('story-youtube-$videoId'),
        color: const Color(0xFFF3EFE5),
        child: Center(child: Text(videoId)),
      );
    }
    return embed.StoryYoutubePlatform(videoId: videoId);
  }
}
