import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../data/app_services.dart';
import '../../data/route_services.dart';
import '../../domain/photo_verify.dart';
import '../../domain/stop_verify.dart';
import '../../domain/unlock_rules.dart';
import '../../l10n/app_strings.dart';
import '../../l10n/locale_controller.dart';
import '../../map/place.dart';
import '../../map/place_catalog.dart';
import '../../map/place_query.dart';

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
  LivePhoto? _photo;
  GeoPoint? _target;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_tryGps());
    });
  }

  Future<GeoPoint?> _resolveTarget() async {
    final extra = widget.place;
    if (extra != null) return extra.location;
    if (widget.isChallengeStop) {
      final detail = await context.read<AppServices>().catalog.fetchChallenge(
        widget.challengeId!,
      );
      for (final waypoint in detail.waypoints) {
        if (waypoint.id == widget.waypointId) {
          return GeoPoint(waypoint.lat, waypoint.lng);
        }
      }
      return null;
    }
    final placeId = widget.placeId;
    if (placeId == null) return null;
    final catalog = widget.places ?? const AssetPlaceCatalog();
    final places = await catalog.fetchAll();
    for (final place in places) {
      if (place.id == placeId) return place.location;
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
      if (!_policy.acceptsUpload(request: request, bytes: captured.bytes)) {
        setState(() => _error = strings.liveCameraOnly);
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

  Future<void> _complete({required bool gps}) async {
    final services = context.read<AppServices>();
    final strings = context.read<LocaleController>().strings;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (widget.isChallengeStop) {
        final allowed = await _challengeAllowed(services, strings);
        if (!allowed) return;
        final user = services.auth.currentUser;
        if (user == null) return;
        var photoPath = VerifyProximity.gpsPhotoPath(
          userId: user.id,
          challengeId: widget.challengeId!,
          waypointId: widget.waypointId!,
        );
        if (!gps) {
          final photo = _photo;
          if (photo == null) {
            setState(() {
              _busy = false;
              _error = strings.photoRequired;
            });
            return;
          }
          photoPath = await services.photos.uploadWaypointPhoto(
            userId: user.id,
            challengeId: widget.challengeId!,
            waypointId: widget.waypointId!,
            bytes: Uint8List.fromList(photo.bytes),
            mimeType: photo.mimeType,
          );
        }
        final updated = await services.progress.verifyWaypoint(
          challengeId: widget.challengeId!,
          waypointId: widget.waypointId!,
          photoPath: photoPath,
        );
        await _persistPlaceIds(services);
        if (!mounted) return;
        if (updated.isCompleted) {
          context.go('/diploma/${widget.challengeId}');
        } else {
          context.pop();
        }
        return;
      }
      await _persistPlaceIds(services);
      if (mounted) context.pop();
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

  Future<void> _persistPlaceIds(AppServices services) async {
    final ids = <String>{};
    if (widget.placeId != null) ids.add(widget.placeId!);
    if (widget.place != null) ids.add(widget.place!.id);
    if (widget.isChallengeStop && _target != null) {
      try {
        final catalog = widget.places ?? const AssetPlaceCatalog();
        final places = await catalog.fetchAll();
        ids.addAll(
          placeIdsInChallenge(
            places,
            waypointIds: [widget.waypointId!],
            waypointLocations: [_target!],
          ),
        );
      } catch (_) {}
    }
    await services.verifiedPlaces.addAll(ids);
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.watch<LocaleController>().strings;
    return Scaffold(
      appBar: AppBar(title: Text(strings.verify)),
      body: Padding(
        padding: const EdgeInsets.all(16),
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
                  if (_fallbackHint != null)
                    Text(_fallbackHint!, key: const Key('verify-gps-status')),
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
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
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
    );
  }
}
