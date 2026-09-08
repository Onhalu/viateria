import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/app_services.dart';
import '../../l10n/locale_controller.dart';
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
    final copy = detail.challenge.copyFor(locale);
    return _DiplomaData(
      title: copy.title,
      headline: copy.diplomaHeadline,
      body: copy.diplomaBody,
      medalCount: detail.waypoints.length,
      completedAt: progress?.completedAt ?? DateTime.now(),
      explorer:
          services.auth.currentUser?.displayName ??
          services.auth.currentUser?.email ??
          'Explorer',
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
  });

  final String title;
  final String explorer;
  final DateTime completedAt;
  final int medalCount;
  final String? headline;
  final String? body;
}
