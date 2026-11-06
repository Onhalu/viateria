import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../data/app_services.dart';
import '../../data/place_visit_sync.dart';
import '../../data/route_services.dart';
import '../../domain/photo_verify.dart';
import '../../domain/stop_verify.dart';
import '../../domain/story_feed.dart';
import '../../domain/unlock_rules.dart';
import '../../l10n/app_strings.dart';
import '../../l10n/locale_controller.dart';
import '../../models/models.dart';
import '../../map/place.dart';
import '../../map/place_catalog.dart';
import '../../map/place_query.dart';
import '../../theme/app_theme.dart';
import '../widgets/place_presentation.dart';
import '../widgets/verify_success_confetti.dart';
import 'diploma_screen.dart';

/// Local visited-place ids recorded after a successful verify.
///
/// A challenge stop contributes [waypointPlaceId] (`waypoints.place_id`).
/// A nearby catalog row is not included.
Set<String> placeIdsPersistedForVerify({
  String? placeId,
  String? shownPlaceId,
  String? waypointPlaceId,
}) {
  final ids = <String>{};
  void add(String? id) {
    final trimmed = id?.trim();
    if (trimmed == null || trimmed.isEmpty) return;
    ids.add(trimmed);
  }

  add(placeId);
  add(shownPlaceId);
  add(waypointPlaceId);
  return ids;
}

class VerifyWaypointScreen extends StatefulWidget {
  const VerifyWaypointScreen({
    super.key,
    this.challengeId,
    this.waypointId,
    this.placeId,
    this.place,
    this.places,
  });

  final String? challengeId;
  final String? waypointId;
  final String? placeId;
  final Place? place;
  final PlaceCatalog? places;

  bool get isChallengeStop =>
      challengeId != null && waypointId != null && challengeId!.isNotEmpty;

  @override
  State<VerifyWaypointScreen> createState() => _VerifyWaypointScreenState();
}

class _VerifyWaypointScreenState extends State<VerifyWaypointScreen> {
  static const _rules = UnlockRules();
  static const _policy = PhotoVerifyPolicy();

  bool _busy = false;
  bool _gpsChecking = true;
  String? _error;
  String? _fallbackHint;
  int? _distanceMeters;
  LivePhoto? _photo;
  GeoPoint? _target;
  Place? _catalogPlace;
  String? _waypointPlaceId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_tryGps());
    });
  }

  Future<GeoPoint?> _resolveTarget() async {
    final extra = widget.place;
    if (extra != null) {
      _catalogPlace = extra;
      return extra.location;
    }
    if (widget.isChallengeStop) {
      final services = context.read<AppServices>();
      final detail = await services.catalog.fetchChallenge(widget.challengeId!);
      for (final waypoint in detail.waypoints) {
        if (waypoint.id == widget.waypointId) {
          final fallback = GeoPoint(waypoint.lat, waypoint.lng);
          final placeId = waypoint.placeId;
          _waypointPlaceId = placeId;
          if (placeId == null || placeId.isEmpty) return fallback;
          try {
            final places = await (widget.places ?? services.places).fetchAll();
            for (final place in places) {
              if (place.id == placeId) {
                _catalogPlace = place;
                return place.location;
              }
            }
          } catch (_) {
            // Description stays hidden when the catalog cannot be read.
          }
          return fallback;
        }
      }
      return null;
    }
    final placeId = widget.placeId;
    if (placeId == null) return null;
    final catalog = widget.places ?? context.read<AppServices>().places;
    final places = await catalog.fetchAll();
    for (final place in places) {
      if (place.id == placeId) {
        _catalogPlace = place;
        return place.location;
      }
    }
    return null;
  }

  Future<void> _tryGps() async {
    final strings = context.read<LocaleController>().strings;
    setState(() {
      _gpsChecking = true;
      _error = null;
    });
    try {
      _target = await _resolveTarget();
      if (!mounted) return;
      final target = _target;
      if (target == null) {
        setState(() {
          _gpsChecking = false;
          _fallbackHint = strings.gpsUnavailableFallback;
        });
        return;
      }
      final here = await context.read<AppServices>().deviceLocation.current();
      if (!mounted) return;
      final at = GeoPoint(here.lat, here.lng);
      if (VerifyProximity.isWithin(here: at, target: target)) {
        await _complete(gps: true);
        return;
      }
      setState(() {
        _gpsChecking = false;
        _distanceMeters = (distanceKm(at, target) * 1000).round();
        _fallbackHint = strings.gpsTooFarFallback;
      });
    } on LocationFailure catch (error) {
      setState(() {
        _gpsChecking = false;
        _fallbackHint = error.message == 'denied'
            ? strings.gpsDeniedFallback
            : strings.gpsUnavailableFallback;
      });
    } catch (_) {
      setState(() {
        _gpsChecking = false;
        _fallbackHint = strings.gpsUnavailableFallback;
      });
    }
  }

  Future<void> _capture() async {
    final strings = context.read<LocaleController>().strings;
    setState(() => _error = null);
    try {
      final captured = await context
          .read<AppServices>()
          .photoCapture
          .captureLivePhoto();
      if (captured == null) return;
      final request = const PhotoCaptureRequest(source: PhotoSource.liveCamera);
      if (!_policy.allows(request)) {
        setState(() => _error = strings.liveCameraOnly);
        return;
      }
      if (!_policy.acceptsUpload(
        request: request,
        bytes: captured.bytes,
        mimeType: captured.mimeType,
      )) {
        setState(() => _error = strings.errorGeneric);
        return;
      }
      setState(() => _photo = captured);
    } catch (_) {
      setState(() => _error = strings.cameraDenied);
    }
  }

  Future<void> _submitPhoto() async {
    final strings = context.read<LocaleController>().strings;
    if (_photo == null) {
      setState(() => _error = strings.photoRequired);
      return;
    }
    await _complete(gps: false);
  }

  Set<String> _gpsPinIds() {
    return placeIdsPersistedForVerify(
      placeId: widget.placeId,
      shownPlaceId: widget.place?.id ?? _catalogPlace?.id,
      waypointPlaceId: _waypointPlaceId,
    );
  }

  Future<void> _complete({required bool gps}) async {
    final services = context.read<AppServices>();
    final strings = context.read<LocaleController>().strings;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (widget.isChallengeStop && gps) {
        // GPS path only. Photo verify waits for the RPC below.
        await _completeGpsOptimistic(services, strings);
        return;
      }
      if (widget.isChallengeStop) {
        await _completePhoto(services, strings);
        return;
      }
      final ids = await _placeIds(services);
      await commitLocalMapVisits(
        store: services.verifiedPlaces,
        leaderboard: services.leaderboard,
        ids: ids,
      );
      if (!mounted) return;
      _celebrateAndLeave(() => context.pop());
    } catch (_) {
      if (mounted) {
        setState(() {
          _gpsChecking = false;
          _error = strings.errorGeneric;
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Client proximity already passed. Show the sage pin and confetti, then
  /// call `verify_waypoint`. Story unlock, the diploma, and leaving the sheet
  /// wait for that RPC. A failure rolls the pin back.
  Future<void> _completeGpsOptimistic(
    AppServices services,
    AppStrings strings,
  ) async {
    final ids = _gpsPinIds();
    services.verifiedPlaces.addOptimisticAll(ids);
    _showConfetti();
    try {
      final allowed = await _challengeAllowed(services, strings);
      if (!allowed) {
        services.verifiedPlaces.rollbackAll(ids);
        return;
      }
      final user = services.auth.currentUser;
      if (user == null) {
        services.verifiedPlaces.rollbackAll(ids);
        return;
      }
      final photoPath = VerifyProximity.gpsPhotoPath(
        userId: user.id,
        challengeId: widget.challengeId!,
        waypointId: widget.waypointId!,
      );
      final detail = await services.catalog.fetchChallenge(widget.challengeId!);
      final updated = await services.progress.verifyWaypoint(
        challengeId: widget.challengeId!,
        waypointId: widget.waypointId!,
        photoPath: photoPath,
      );
      await _persistPlaceIds(services);
      await services.verifiedPlaces.confirmAll(ids);
      if (!mounted) return;
      _leaveAfterVerified(detail: detail, updated: updated, confetti: false);
    } catch (_) {
      services.verifiedPlaces.rollbackAll(ids);
      if (!mounted) return;
      setState(() {
        _gpsChecking = false;
        _error = strings.verifyFailed;
      });
      _showVerifyFailed(strings);
    }
  }

  /// Photo verify waits for upload and `verify_waypoint` before the pin,
  /// confetti, story step, or diploma.
  Future<void> _completePhoto(AppServices services, AppStrings strings) async {
    final allowed = await _challengeAllowed(services, strings);
    if (!allowed) return;
    final user = services.auth.currentUser;
    if (user == null) return;
    final photo = _photo;
    if (photo == null) {
      setState(() {
        _busy = false;
        _error = strings.photoRequired;
      });
      return;
    }
    if (!_policy.acceptsUpload(
      request: const PhotoCaptureRequest(source: PhotoSource.liveCamera),
      bytes: photo.bytes,
      mimeType: photo.mimeType,
    )) {
      setState(() => _error = strings.errorGeneric);
      return;
    }
    final photoPath = await services.photos.uploadWaypointPhoto(
      userId: user.id,
      challengeId: widget.challengeId!,
      waypointId: widget.waypointId!,
      bytes: Uint8List.fromList(photo.bytes),
      mimeType: photo.mimeType,
    );
    final detail = await services.catalog.fetchChallenge(widget.challengeId!);
    final updated = await services.progress.verifyWaypoint(
      challengeId: widget.challengeId!,
      waypointId: widget.waypointId!,
      photoPath: photoPath,
    );
    await _persistPlaceIds(services);
    if (!mounted) return;
    _leaveAfterVerified(detail: detail, updated: updated, confetti: true);
  }

  /// Story reveal and the diploma run only after `verify_waypoint` succeeds.
  void _leaveAfterVerified({
    required ChallengeDetail detail,
    required ChallengeProgress updated,
    required bool confetti,
  }) {
    if (!mounted) return;
    final story = detail.challenge.accessMode == AccessMode.story;
    void go(VoidCallback leave) {
      if (confetti) {
        _celebrateAndLeave(leave);
      } else {
        leave();
      }
    }

    if (updated.isCompleted && !story) {
      final id = widget.challengeId!;
      final nav = Navigator.of(context, rootNavigator: true);
      go(() {
        if (nav.canPop()) nav.pop();
        final host = nav.context;
        if (host.mounted) showDiplomaWindow(host, id);
      });
      return;
    }
    final hints = storyStepIdsAfterVerify(
      detail: detail,
      verifiedWaypointId: widget.waypointId!,
      completedIds: updated.completedWaypointIds,
    );
    final reveal =
        updated.revealStoryStepId ??
        hints.closingStoryStepId ??
        hints.nextStoryStepId;
    go(() => context.pop(story ? reveal : null));
  }

  void _showVerifyFailed(AppStrings strings) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(strings.verifyFailed, key: const Key('verify-failed')),
          behavior: SnackBarBehavior.floating,
          backgroundColor: BrandColors.forest,
        ),
      );
  }

  /// Plays the existing burst. Reduced motion and a missing overlay skip it.
  /// Photo failures never call this; GPS shows it on client PASS, before the RPC.
  void _showConfetti() {
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    if (reduceMotion || overlay == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!overlay.mounted) return;
      VerifySuccessConfetti.insertInto(overlay);
    });
  }

  /// Plays the burst on the frame the success UI appears, then leaves.
  ///
  /// The overlay is [IgnorePointer], so dismiss and other CTAs stay usable.
  /// Reduced motion and a missing overlay skip the burst.
  void _celebrateAndLeave(VoidCallback leave) {
    leave();
    _showConfetti();
  }

  Future<bool> _challengeAllowed(
    AppServices services,
    AppStrings strings,
  ) async {
    final detail = await services.catalog.fetchChallenge(widget.challengeId!);
    final progress = await services.progress.fetchProgress(widget.challengeId!);
    final purchase = await services.purchases.fetchPurchase(
      widget.challengeId!,
    );
    final hasAccess = _rules.hasAccess(
      pricing: detail.challenge.pricingType,
      purchased: purchase?.isPaid ?? false,
    );
    final allowed = _rules.canVerify(
      mode: detail.challenge.accessMode,
      hasAccess: hasAccess,
      orderedWaypoints: detail.orderedWaypoints,
      waypointId: widget.waypointId!,
      completedWaypointIds: progress?.completedWaypointIds ?? {},
    );
    if (!allowed) {
      setState(() {
        _busy = false;
        _gpsChecking = false;
        _error = strings.needAccess;
      });
    }
    return allowed;
  }

  Future<Set<String>> _placeIds(AppServices services) async {
    String? waypointPlaceId;
    if (widget.isChallengeStop) {
      try {
        final detail = await services.catalog.fetchChallenge(
          widget.challengeId!,
        );
        for (final waypoint in detail.waypoints) {
          if (waypoint.id == widget.waypointId) {
            waypointPlaceId = waypoint.placeId;
            break;
          }
        }
      } catch (_) {}
    }
    final ids = placeIdsPersistedForVerify(
      placeId: widget.placeId,
      shownPlaceId: widget.place?.id,
      waypointPlaceId: waypointPlaceId,
    );
    return ids;
  }

  Future<Set<String>> _persistPlaceIds(AppServices services) async {
    final ids = await _placeIds(services);
    await services.verifiedPlaces.addAll(ids);
    return ids;
  }

  Place? get _shownPlace => widget.place ?? _catalogPlace;

  String? get _placeDescription {
    final text = _shownPlace?.description?.trim();
    if (text == null || text.isEmpty) return null;
    return text;
  }

  double? get _placeElevation => _shownPlace?.elevationM;

  @override
  Widget build(BuildContext context) {
    final strings = context.watch<LocaleController>().strings;
    return Scaffold(
      appBar: AppBar(title: Text(strings.verify)),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_placeElevation != null) ...[
              Align(
                alignment: Alignment.centerLeft,
                child: PlaceMetaChip(
                  key: const Key('verify-place-elevation'),
                  label: strings.formatElevationM(_placeElevation!),
                ),
              ),
              const SizedBox(height: 8),
            ],
            if (_placeDescription != null) ...[
              PlaceDescriptionText(
                text: _placeDescription!,
                textKey: const Key('verify-place-description'),
                maxLines: 3,
              ),
              const SizedBox(height: 12),
            ],
            Expanded(
              child: _gpsChecking
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const CircularProgressIndicator(),
                          const SizedBox(height: 16),
                          Text(
                            strings.gpsChecking,
                            key: const Key('verify-gps-status'),
                          ),
                        ],
                      ),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (_fallbackHint != null || _error != null)
                          _VerifyIssueCard(
                            title: _distanceMeters != null
                                ? strings.verifyDistanceAway(_distanceMeters!)
                                : (_error ?? _fallbackHint!),
                            body: _distanceMeters != null
                                ? _fallbackHint
                                : (_error != null ? _fallbackHint : null),
                            retryLabel: strings.retry,
                            settingsLabel:
                                _error == strings.cameraDenied ||
                                    _fallbackHint == strings.gpsDeniedFallback
                                ? strings.openSettings
                                : null,
                            onRetry: _error == strings.cameraDenied
                                ? _capture
                                : _tryGps,
                            onOpenSettings: () {
                              unawaited(Geolocator.openAppSettings());
                            },
                          ),
                        const SizedBox(height: 16),
                        Expanded(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: Colors.black12,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: _photo == null
                                ? Center(child: Text(strings.takePhoto))
                                : ClipRRect(
                                    borderRadius: BorderRadius.circular(16),
                                    child: Image.memory(
                                      Uint8List.fromList(_photo!.bytes),
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        OutlinedButton.icon(
                          onPressed: _busy ? null : _capture,
                          icon: const Icon(Icons.photo_camera),
                          label: Text(strings.takePhoto),
                        ),
                        const SizedBox(height: 8),
                        FilledButton(
                          key: const Key('verify-submit'),
                          onPressed: _busy ? null : _submitPhoto,
                          child: _busy
                              ? Text(strings.uploading)
                              : Text(strings.verify),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VerifyIssueCard extends StatelessWidget {
  const _VerifyIssueCard({
    required this.title,
    required this.retryLabel,
    required this.onRetry,
    this.body,
    this.settingsLabel,
    this.onOpenSettings,
  });

  final String title;
  final String? body;
  final String retryLabel;
  final VoidCallback onRetry;
  final String? settingsLabel;
  final VoidCallback? onOpenSettings;

  @override
  Widget build(BuildContext context) {
    return Card(
      key: const Key('verify-issue-card'),
      color: BrandColors.neutral,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.place_outlined, color: BrandColors.bark, size: 36),
            const SizedBox(height: 8),
            SizedBox(
              height: 72,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: BrandColors.beige.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(AppTheme.radiusCard),
                ),
                child: const Icon(Icons.map_outlined, color: BrandColors.bark),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: BrandColors.error,
                fontSize: AppTheme.bodySize,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (body != null && body!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                body!,
                key: const Key('verify-gps-status'),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: BrandColors.forest,
                  fontSize: AppTheme.labelSize,
                ),
              ),
            ],
            const SizedBox(height: 12),
            FilledButton(onPressed: onRetry, child: Text(retryLabel)),
            if (settingsLabel != null && onOpenSettings != null) ...[
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: onOpenSettings,
                child: Text(settingsLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
