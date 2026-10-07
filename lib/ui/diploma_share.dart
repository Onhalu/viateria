import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:share_plus/share_plus.dart';

/// Tests replace this with [MemoryImage].
ImageProvider<Object> Function(String url) diplomaImageProvider =
    NetworkImage.new;

typedef DiplomaSharer = Future<void> Function(Uint8List bytes, String filename);
typedef DiplomaBytesLoader = Future<Uint8List> Function(String url);

DiplomaSharer diplomaSharer = shareDiplomaFile;
DiplomaBytesLoader diplomaBytesLoader = _download;

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
      files: [
        XFile.fromData(bytes, mimeType: 'image/png', name: filename),
      ],
    ),
  );
}

Future<void> downloadOrShareDiploma({
  required String url,
  required String filename,
}) async {
  final bytes = await diplomaBytesLoader(url);
  await diplomaSharer(bytes, filename);
}
