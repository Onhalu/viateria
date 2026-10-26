import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:share_plus/share_plus.dart';

import '../data/app_services.dart';
import 'diploma_file_share_io.dart'
    if (dart.library.js_interop) 'diploma_file_share_web.dart';
import 'diploma_story_frame.dart';

/// Tests replace this with [MemoryImage].
ImageProvider<Object> Function(String url) diplomaImageProvider =
    NetworkImage.new;

typedef DiplomaSharer = Future<void> Function(Uint8List bytes, String filename);
typedef DiplomaBytesLoader = Future<Uint8List> Function(String url);

DiplomaSharer diplomaSharer = shareDiplomaFile;
DiplomaBytesLoader diplomaBytesLoader = _download;

/// Optional Meta app id (`--dart-define=FACEBOOK_APP_ID=...`).
/// Empty means Instagram and Facebook Stories are skipped and the share
/// sheet is used. Ondřej supplies the real id later.
const diplomaFacebookAppId = String.fromEnvironment('FACEBOOK_APP_ID');

const diplomaShareChannel = MethodChannel('viateria/diploma_share');

enum DiplomaShareTarget { generic, instagram, facebook }

enum DiplomaShareRoute { stories, sheet, download }

class DiplomaShareOutcome {
  const DiplomaShareOutcome({required this.route, this.showUploadHint = false});

  final DiplomaShareRoute route;

  /// Desktop web: the PNG was downloaded and the user must upload it.
  final bool showUploadHint;
}

class DiplomaShareEffects {
  DiplomaShareEffects({
    required this.canShareFiles,
    required this.facebookAppId,
    required this.storiesSupported,
    required this.storyFrame,
    required this.stories,
    required this.sheet,
    required this.download,
    required this.openUrl,
  });

  factory DiplomaShareEffects.live() {
    return DiplomaShareEffects(
      canShareFiles: platformCanShareDiplomaFiles,
      facebookAppId: () => diplomaFacebookAppId,
      storiesSupported: defaultStoriesSupported,
      storyFrame: renderDiplomaStoryFrame,
      stories: shareDiplomaToStory,
      sheet: shareDiplomaSheet,
      download: shareDiplomaFile,
      openUrl: launchExternalUrl,
    );
  }

  final Future<bool> Function() canShareFiles;
  final String Function() facebookAppId;
  final bool Function() storiesSupported;
  final Future<Uint8List> Function(Uint8List bytes) storyFrame;
  final Future<bool> Function(
    Uint8List bytes,
    String appId,
    DiplomaShareTarget target,
  )
  stories;
  final Future<void> Function(Uint8List bytes, String filename, String caption)
  sheet;
  final Future<void> Function(Uint8List bytes, String filename) download;
  final Future<void> Function(Uri url) openUrl;
}

DiplomaShareEffects diplomaShareEffects = DiplomaShareEffects.live();

bool defaultStoriesSupported() {
  if (kIsWeb) return false;
  return defaultTargetPlatform == TargetPlatform.iOS ||
      defaultTargetPlatform == TargetPlatform.android;
}

Uri diplomaSocialPage(DiplomaShareTarget target) {
  return switch (target) {
    DiplomaShareTarget.instagram => Uri.parse('https://www.instagram.com/'),
    DiplomaShareTarget.facebook => Uri.parse('https://www.facebook.com/'),
    DiplomaShareTarget.generic => Uri.parse('https://www.instagram.com/'),
  };
}

Future<Uint8List> _download(String url) async {
  final response = await http.get(Uri.parse(url));
  if (response.statusCode != 200) {
    throw StateError('diploma download failed');
  }
  return response.bodyBytes;
}

Future<void> shareDiplomaFile(Uint8List bytes, String filename) async {
  await SharePlus.instance.share(
    ShareParams(
      files: [_pngFile(bytes, filename)],
      fileNameOverrides: [filename],
      downloadFallbackEnabled: true,
      mailToFallbackEnabled: false,
    ),
  );
}

Future<void> shareDiplomaSheet(
  Uint8List bytes,
  String filename,
  String caption,
) async {
  final text = caption.trim();
  try {
    await _sharePng(bytes, filename, text: text.isEmpty ? null : text);
  } catch (_) {
    await _sharePng(bytes, filename);
  }
}

Future<void> _sharePng(Uint8List bytes, String filename, {String? text}) async {
  await SharePlus.instance.share(
    ShareParams(
      text: text,
      title: text == null ? null : 'VANDERY',
      files: [_pngFile(bytes, filename)],
      fileNameOverrides: [filename],
      downloadFallbackEnabled: false,
      mailToFallbackEnabled: false,
    ),
  );
}

XFile _pngFile(Uint8List bytes, String filename) {
  return XFile.fromData(bytes, mimeType: 'image/png', name: filename);
}

/// Instagram or Facebook Stories. The PNG is the 9:16 frame. Returns false
/// when the app id is missing, the platform has no bridge, or the app is
/// not installed. Callers then use the share sheet.
Future<bool> shareDiplomaToStory(
  Uint8List bytes,
  String appId,
  DiplomaShareTarget target,
) async {
  final id = appId.trim();
  final method = switch (target) {
    DiplomaShareTarget.instagram => 'shareInstagramStory',
    DiplomaShareTarget.facebook => 'shareFacebookStory',
    DiplomaShareTarget.generic => '',
  };
  if (id.isEmpty || method.isEmpty || !defaultStoriesSupported()) return false;
  try {
    final shared = await diplomaShareChannel.invokeMethod<bool>(method, {
      'bytes': bytes,
      'appId': id,
    });
    return shared == true;
  } catch (_) {
    return false;
  }
}

/// Shares the diploma PNG.
///
/// Instagram and Facebook Stories run only when [facebookAppId] is set and
/// the native bridge is available. The image they receive is the 9:16 frame.
/// A missing id, a missing app, or a failed story intent falls back to the
/// system share sheet. Desktop web, where file sharing is unavailable,
/// downloads the original PNG and, for Instagram or Facebook, opens that site.
Future<DiplomaShareOutcome> runDiplomaShare({
  required DiplomaShareTarget target,
  required Uint8List bytes,
  required String filename,
  required String caption,
}) async {
  final effects = diplomaShareEffects;
  final canShare = await effects.canShareFiles();
  final appId = effects.facebookAppId().trim();
  final storiesTarget =
      target == DiplomaShareTarget.instagram ||
      target == DiplomaShareTarget.facebook;
  final tryStories =
      storiesTarget && appId.isNotEmpty && effects.storiesSupported();

  if (tryStories) {
    Uint8List framed = bytes;
    try {
      framed = await effects.storyFrame(bytes);
    } catch (_) {
      framed = bytes;
    }
    final shared = await effects.stories(framed, appId, target);
    if (shared) {
      return const DiplomaShareOutcome(route: DiplomaShareRoute.stories);
    }
    if (canShare) {
      try {
        await effects.sheet(framed, filename, caption);
        return const DiplomaShareOutcome(route: DiplomaShareRoute.sheet);
      } catch (_) {
        // The sheet refused the story frame. Download the original below.
      }
    }
  }

  if (canShare) {
    try {
      await effects.sheet(bytes, filename, caption);
      return const DiplomaShareOutcome(route: DiplomaShareRoute.sheet);
    } catch (_) {
      // The sheet refused the file. Download below.
    }
  }

  await effects.download(bytes, filename);
  final social =
      target == DiplomaShareTarget.instagram ||
      target == DiplomaShareTarget.facebook;
  if (!social) {
    return const DiplomaShareOutcome(route: DiplomaShareRoute.download);
  }
  try {
    await effects.openUrl(diplomaSocialPage(target));
  } catch (_) {
    // The file is already downloaded. The hint still tells the user to upload it.
  }
  return const DiplomaShareOutcome(
    route: DiplomaShareRoute.download,
    showUploadHint: true,
  );
}

Future<void> downloadOrShareDiploma({
  required String url,
  required String filename,
}) async {
  final bytes = await diplomaBytesLoader(url);
  await diplomaSharer(bytes, filename);
}
