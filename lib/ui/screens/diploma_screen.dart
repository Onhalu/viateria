import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/app_services.dart';
import '../../l10n/locale_controller.dart';
import '../../models/models.dart';
import '../widgets/diploma_view.dart';

class DiplomaScreen extends StatefulWidget {
  const DiplomaScreen({super.key, required this.challengeId});

  final String challengeId;

  @override
  State<DiplomaScreen> createState() => _DiplomaScreenState();
}

class _DiplomaScreenState extends State<DiplomaScreen> {
  Future<_DiplomaData>? _future;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _future ??= _load();
  }

  Future<_DiplomaData> _load() async {
    final services = context.read<AppServices>();
    final locale = context.read<LocaleController>().locale;
    final detail = await services.catalog.fetchChallenge(widget.challengeId);
    final progress = await services.progress.fetchProgress(widget.challengeId);
    final issued = await services.progress.fetchIssuedDiploma(
      widget.challengeId,
    );
    final copy = detail.challenge.copyFor(locale);
    final days = issued?.displayDayCount ?? progress?.inclusiveDayCount;
    final durationLabel = days == null
        ? null
        : formatParticipationDays(locale, days);
    final named =
        issued?.recipientNameDisplay ??
        issued?.recipientName ??
        services.auth.currentUser?.displayName;
    return _DiplomaData(
      title: issued?.challengeTitle ?? copy.title,
      headline: issued?.headline ?? copy.diplomaHeadline,
      body: issued?.body ?? copy.diplomaBody,
      medalCount: detail.waypoints.length,
      completedAt:
          issued?.completedAt ?? progress?.completedAt ?? DateTime.now(),
      explorer: (named != null && named.trim().isNotEmpty)
          ? named.trim()
          : (services.auth.currentUser?.email ?? 'Explorer'),
      durationLabel: durationLabel,
    );
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.watch<LocaleController>().strings;
    return Scaffold(
      appBar: AppBar(title: Text(strings.viewDiploma)),
      body: FutureBuilder<_DiplomaData>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData) {
            return Center(child: Text(strings.errorGeneric));
          }
          final data = snapshot.data!;
          return Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: DiplomaView(
                  challengeTitle: data.title,
                  explorerName: data.explorer,
                  completedAt: data.completedAt,
                  medalCount: data.medalCount,
                  strings: strings,
                  headline: data.headline,
                  body: data.body,
                  durationLabel: data.durationLabel,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _DiplomaData {
  const _DiplomaData({
    required this.title,
    required this.explorer,
    required this.completedAt,
    required this.medalCount,
    this.headline,
    this.body,
    this.durationLabel,
  });

  final String title;
  final String explorer;
  final DateTime completedAt;
  final int medalCount;
  final String? headline;
  final String? body;
  final String? durationLabel;
}
