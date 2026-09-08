import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../data/app_services.dart';
import '../../domain/photo_verify.dart';
import '../../domain/unlock_rules.dart';
import '../../l10n/locale_controller.dart';

class VerifyWaypointScreen extends StatefulWidget {
  const VerifyWaypointScreen({
    super.key,
    required this.challengeId,
    required this.waypointId,
  });

  final String challengeId;
  final String waypointId;

  @override
  State<VerifyWaypointScreen> createState() => _VerifyWaypointScreenState();
}

class _VerifyWaypointScreenState extends State<VerifyWaypointScreen> {
  static const _rules = UnlockRules();
  static const _policy = PhotoVerifyPolicy();

  bool _busy = false;
  String? _error;
  LivePhoto? _photo;

  Future<void> _capture() async {
    final strings = context.read<LocaleController>().strings;
    setState(() => _error = null);
    try {
      final captured = await context.read<AppServices>().photoCapture
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

  Future<void> _submit() async {
    final services = context.read<AppServices>();
    final strings = context.read<LocaleController>().strings;
    final photo = _photo;
    if (photo == null) {
      setState(() => _error = strings.photoRequired);
      return;
    }
    final user = services.auth.currentUser;
    if (user == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final detail = await services.catalog.fetchChallenge(widget.challengeId);
      final progress = await services.progress.fetchProgress(widget.challengeId);
      final purchase = await services.purchases.fetchPurchase(widget.challengeId);
      final hasAccess = _rules.hasAccess(
        pricing: detail.challenge.pricingType,
        purchased: purchase?.isPaid ?? false,
      );
      final allowed = _rules.canVerifyPhoto(
        mode: detail.challenge.accessMode,
        hasAccess: hasAccess,
        orderedWaypoints: detail.orderedWaypoints,
        waypointId: widget.waypointId,
        completedWaypointIds: progress?.completedWaypointIds ?? {},
      );
      if (!allowed) {
        setState(() {
          _busy = false;
          _error = strings.needAccess;
        });
        return;
      }
      final path = await services.photos.uploadWaypointPhoto(
        userId: user.id,
        challengeId: widget.challengeId,
        waypointId: widget.waypointId,
        bytes: Uint8List.fromList(photo.bytes),
        mimeType: photo.mimeType,
      );
      final updated = await services.progress.verifyWaypoint(
        challengeId: widget.challengeId,
        waypointId: widget.waypointId,
        photoPath: path,
      );
      if (!mounted) return;
      if (updated.isCompleted) {
        context.go('/diploma/${widget.challengeId}');
      } else {
        context.pop();
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = strings.errorGeneric);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

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
            Text(strings.photoRequired),
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
                style: TextStyle(color: Theme.of(context).colorScheme.error),
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
              onPressed: _busy ? null : _submit,
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
