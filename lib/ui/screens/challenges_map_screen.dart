import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/app_services.dart';
import '../../l10n/locale_controller.dart';
import '../../models/models.dart';
import '../navigation.dart';
import '../widgets/challenges_overview_map.dart';
import '../widgets/empty_state.dart';

class ChallengesMapScreen extends StatefulWidget {
  const ChallengesMapScreen({super.key});

  @override
  State<ChallengesMapScreen> createState() => _ChallengesMapScreenState();
}

class _ChallengesMapScreenState extends State<ChallengesMapScreen> {
  Future<List<ChallengeDetail>>? _future;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _future ??= _load();
  }

  Future<List<ChallengeDetail>> _load() async {
    final catalog = context.read<AppServices>().catalog;
    final published = await catalog.fetchPublishedChallenges();
    final details = await Future.wait(
      published.map((challenge) async {
        try {
          return await catalog.fetchChallenge(challenge.id);
        } catch (_) {
          return null;
        }
      }),
    );
    return details.whereType<ChallengeDetail>().toList();
  }

  Future<void> _reload() async {
    setState(() => _future = _load());
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.watch<LocaleController>().strings;
    return SafeArea(
      bottom: false,
      child: FutureBuilder<List<ChallengeDetail>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(strings.errorGeneric),
                  TextButton(onPressed: _reload, child: Text(strings.retry)),
                ],
              ),
            );
          }
          final mapped = mappedChallengesFrom(snapshot.data ?? const []);
          if (mapped.isEmpty) {
            return RefreshIndicator(
              onRefresh: _reload,
              child: EmptyState(
                key: const Key('map-empty'),
                title: strings.mapEmpty,
                hint: strings.mapEmptyHint,
              ),
            );
          }
          return ChallengesOverviewMap(
            challenges: mapped,
            onChallengeTap: (id) => openChallenge(context, id),
          );
        },
      ),
    );
  }
}
