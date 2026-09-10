import 'package:flutter_test/flutter_test.dart';
import 'package:viateria/domain/photo_verify.dart';
import 'package:viateria/models/models.dart';

void main() {
  const policy = PhotoVerifyPolicy();

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
        request: const PhotoCaptureRequest(source: PhotoSource.liveCamera),
        bytes: [1, 2, 3],
      ),
      isTrue,
    );
    expect(
      policy.acceptsUpload(
        request: const PhotoCaptureRequest(source: PhotoSource.liveCamera),
        bytes: const [],
      ),
      isFalse,
    );
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
