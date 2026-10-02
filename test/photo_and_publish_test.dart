import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:viateria/domain/photo_verify.dart';
import 'package:viateria/models/models.dart';

void main() {
  const policy = PhotoVerifyPolicy();
  const liveCamera = PhotoCaptureRequest(source: PhotoSource.liveCamera);

  test('live camera photos are required for the photo fallback; gallery is rejected', () {
    expect(
      policy.allows(const PhotoCaptureRequest(source: PhotoSource.liveCamera)),
      isTrue,
    );
    expect(
      policy.allows(const PhotoCaptureRequest(source: PhotoSource.gallery)),
      isFalse,
    );
    expect(
      policy.acceptsUpload(
        request: liveCamera,
        bytes: [1, 2, 3],
        mimeType: liveCameraPhotoMimeType,
      ),
      isTrue,
    );
    expect(
      policy.acceptsUpload(
        request: const PhotoCaptureRequest(source: PhotoSource.gallery),
        bytes: [1, 2, 3],
        mimeType: liveCameraPhotoMimeType,
      ),
      isFalse,
    );
    expect(
      policy.acceptsUpload(
        request: liveCamera,
        bytes: const [],
        mimeType: liveCameraPhotoMimeType,
      ),
      isFalse,
    );
  });

  test('live camera jpeg is inside the waypoint-photos allowlist', () {
    expect(liveCameraPhotoMimeType, 'image/jpeg');
    expect(allowedWaypointPhotoMimeTypes, contains(liveCameraPhotoMimeType));
    expect(waypointPhotoFileExtension(liveCameraPhotoMimeType), 'jpg');
    expect(
      waypointPhotoRejection(
        bytes: const [1],
        mimeType: liveCameraPhotoMimeType,
      ),
      isNull,
    );
  });

  test('rejects a content type outside the waypoint-photos allowlist', () {
    for (final mimeType in [
      'image/gif',
      'image/jpg',
      'image/heic',
      'IMAGE/JPEG',
      'application/octet-stream',
      'text/html',
    ]) {
      expect(
        waypointPhotoRejection(bytes: const [1, 2, 3], mimeType: mimeType),
        WaypointPhotoRejection.mime,
        reason: mimeType,
      );
      expect(
        policy.acceptsUpload(
          request: liveCamera,
          bytes: const [1, 2, 3],
          mimeType: mimeType,
        ),
        isFalse,
        reason: mimeType,
      );
      expect(
        () => requireWaypointPhoto(bytes: const [1, 2, 3], mimeType: mimeType),
        throwsA(
          isA<WaypointPhotoRejected>().having(
            (error) => error.reason,
            'reason',
            WaypointPhotoRejection.mime,
          ),
        ),
        reason: mimeType,
      );
    }
  });

  test('accepts png and webp at the size cap and rejects one byte over', () {
    final atCap = List<int>.filled(waypointPhotoMaxBytes, 1);
    final over = List<int>.filled(waypointPhotoMaxBytes + 1, 1);
    expect(waypointPhotoMaxBytes, 8388608);

    for (final mimeType in allowedWaypointPhotoMimeTypes) {
      expect(
        waypointPhotoRejection(bytes: atCap, mimeType: mimeType),
        isNull,
        reason: mimeType,
      );
      expect(
        policy.acceptsUpload(
          request: liveCamera,
          bytes: atCap,
          mimeType: mimeType,
        ),
        isTrue,
        reason: mimeType,
      );
      expect(
        waypointPhotoRejection(bytes: over, mimeType: mimeType),
        WaypointPhotoRejection.oversize,
        reason: mimeType,
      );
      expect(
        () => requireWaypointPhoto(bytes: over, mimeType: mimeType),
        throwsA(
          isA<WaypointPhotoRejected>().having(
            (error) => error.reason,
            'reason',
            WaypointPhotoRejection.oversize,
          ),
        ),
        reason: mimeType,
      );
    }
  });

  test('migration limits waypoint-photos and leaves read policies alone', () {
    final sql = File(
      'supabase/migrations/0016_waypoint_photos_upload_limits.sql',
    ).readAsStringSync().replaceAll(RegExp(r'--[^\n]*'), '');
    expect(sql, contains("where id = 'waypoint-photos'"));
    expect(sql, contains('file_size_limit = 8388608'));
    expect(sql, contains("'image/jpeg'"));
    expect(sql, contains("'image/png'"));
    expect(sql, contains("'image/webp'"));
    expect(sql, isNot(contains('create policy')));
    expect(sql, isNot(contains('is_shared_verification_photo')));
    expect(sql, isNot(contains('challenge_waypoint_photos')));
    expect(sql, isNot(contains('public =')));
  });

  test('draft and archived catalog rows are not public', () {
    expect(isPubliclyVisible(PublishStatus.published), isTrue);
    expect(isPubliclyVisible(PublishStatus.draft), isFalse);
    expect(isPubliclyVisible(PublishStatus.archived), isFalse);
  });

  test('promo stripes honor schedule and status', () {
    final now = DateTime.utc(2026, 9, 7);
    final published = PromoStripe(
      id: 'p',
      status: PublishStatus.published,
      sortOrder: 0,
      translations: const [],
      startsAt: DateTime.utc(2026, 9, 1),
      endsAt: DateTime.utc(2026, 9, 30),
    );
    final draft = PromoStripe(
      id: 'd',
      status: PublishStatus.draft,
      sortOrder: 0,
      translations: const [],
    );
    expect(published.isActiveAt(now), isTrue);
    expect(draft.isActiveAt(now), isFalse);
    expect(published.isActiveAt(DateTime.utc(2026, 8, 1)), isFalse);
  });
}
