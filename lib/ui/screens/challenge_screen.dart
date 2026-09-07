import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/app_services.dart';
import '../../domain/route_planner.dart';
import '../../domain/unlock_rules.dart';
import '../../l10n/app_strings.dart';
import '../../l10n/locale_controller.dart';
import '../../models/models.dart';
import '../widgets/challenge_map.dart';
import '../widgets/route_planner_panel.dart';

class ChallengeScreen extends StatefulWidget {
  const ChallengeScreen({super.key, required this.challengeId});

  final String challengeId;

  @override
  State<ChallengeScreen> createState() => _ChallengeScreenState();
}

class _ChallengeScreenState extends State<ChallengeScreen> {
  static const _rules = UnlockRules();
  static const _planner = RoutePlanner();

  TravelMode _mode = TravelMode.hike;
  Future<_ChallengePageData>? _future;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _future ??= _load();
  }

  Future<_ChallengePageData> _load() async {
    final services = context.read<AppServices>();
    final detail = await services.catalog.fetchChallenge(widget.challengeId);
    final progress = await services.progress.fetchProgress(widget.challengeId);
    final purchase = await services.purchases.fetchPurchase(widget.challengeId);
    return _ChallengePageData(
      detail: detail,
      progress: progress,
      purchase: purchase,
    );
  }

  Future<void> _reload() async {
    setState(() => _future = _load());
    await _future;
  }

  Future<void> _unlockPaid() async {
    final services = context.read<AppServices>();
    final session = await services.purchases.startCheckout(widget.challengeId);
    await launchUrl(
      Uri.parse(session.url),
      mode: LaunchMode.externalApplication,
    );
    if (mounted) await _reload();
  }

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<LocaleController>().locale;
    final strings = context.watch<LocaleController>().strings;
    return Scaffold(
      appBar: AppBar(title: Text(strings.appName)),
      body: FutureBuilder<_ChallengePageData>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError || snapshot.data == null) {
            return Center(
              child: TextButton(
                onPressed: _reload,
                child: Text(strings.retry),
              ),
            );
          }
          final data = snapshot.data!;
          final challenge = data.detail.challenge;
          final copy = challenge.copyFor(locale);
          final waypoints = data.detail.orderedWaypoints;
          final completed = data.progress?.completedWaypointIds ?? {};
          final hasAccess = _rules.hasAccess(
            pricing: challenge.pricingType,
            purchased: data.purchase?.isPaid ?? false,
          );
          final summary = _planner.plan(mode: _mode, waypoints: waypoints);
          final isComplete = _rules.isChallengeComplete(
            waypoints: waypoints,
            completedWaypointIds: completed,
          );
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                copy.title,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(copy.description),
              const SizedBox(height: 12),
              ChallengeMap(waypoints: waypoints),
              const SizedBox(height: 12),
              RoutePlannerPanel(
                summary: summary,
                mode: _mode,
                onModeChanged: (mode) => setState(() => _mode = mode),
                strings: strings,
              ),
              const SizedBox(height: 16),
              if (!hasAccess) ...[
                Text(strings.challengeLockedPaid),
                const SizedBox(height: 8),
                FilledButton(
                  onPressed: _unlockPaid,
                  child: Text(strings.unlockWithStripe),
                ),
                if (data.purchase?.status == PurchaseStatus.pending)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(strings.purchasePending),
                  ),
              ],
              if (isComplete)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: FilledButton.tonal(
                    onPressed: () => context.push(
                      '/diploma/${challenge.id}',
                      extra: data,
                    ),
                    child: Text(strings.viewDiploma),
                  ),
                ),
              const SizedBox(height: 16),
              Text(
                strings.waypoints,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              for (var i = 0; i < waypoints.length; i++)
                _WaypointTile(
                  waypoint: waypoints[i],
                  locale: locale,
                  unlocked: _rules.isWaypointUnlocked(
                    mode: challenge.accessMode,
                    hasAccess: hasAccess,
                    waypointIndex: i,
                    completedIndexes: {
                      for (var j = 0; j < waypoints.length; j++)
                        if (completed.contains(waypoints[j].id)) j,
                    },
                  ),
                  completed: completed.contains(waypoints[i].id),
                  strings: strings,
                  onVerify: () => context.push(
                    '/verify/${challenge.id}/${waypoints[i].id}',
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _WaypointTile extends StatelessWidget {
  const _WaypointTile({
    required this.waypoint,
    required this.locale,
    required this.unlocked,
    required this.completed,
    required this.strings,
    required this.onVerify,
  });

  final Waypoint waypoint;
  final String locale;
  final bool unlocked;
  final bool completed;
  final AppStrings strings;
  final VoidCallback onVerify;

  @override
  Widget build(BuildContext context) {
    final copy = waypoint.copyFor(locale);
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          child: Text('${waypoint.sortOrder + 1}'),
        ),
        title: Text(copy.title),
        subtitle: Text(
          completed
              ? strings.verified
              : unlocked
              ? (copy.hint ?? copy.description)
              : strings.storyLockedHint,
        ),
        trailing: completed
            ? const Icon(Icons.check_circle, color: Color(0xFF2D6A4F))
            : unlocked
            ? FilledButton(
                onPressed: onVerify,
                child: Text(strings.verify),
              )
            : const Icon(Icons.lock_outline),
      ),
    );
  }
}

class ChallengePageData {
  const ChallengePageData({
    required this.detail,
    required this.progress,
    required this.purchase,
  });

  final ChallengeDetail detail;
  final ChallengeProgress? progress;
  final Purchase? purchase;
}

typedef _ChallengePageData = ChallengePageData;
