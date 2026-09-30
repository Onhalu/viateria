import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/app_services.dart';
import '../../domain/leaderboard_score.dart';
import '../../l10n/locale_controller.dart';
import '../../models/models.dart';
import '../../theme/brand_colors.dart';

/// Modal sheet metrics. Height is 82% of the viewport, clamped to 70–88%.
abstract final class LeaderboardSheet {
  static const fraction = 0.82;
  static const minFraction = 0.70;
  static const maxFraction = 0.88;
  static const radius = 18.0;
  static const closeHit = 44.0;

  static Color get barrierColor => BrandColors.forest.withValues(alpha: 0.4);

  static double heightFor(double viewportHeight) {
    final fraction = LeaderboardSheet.fraction.clamp(minFraction, maxFraction);
    return viewportHeight * fraction;
  }
}

/// Opens the all-time board over [context]. Dismiss with the arrow or the barrier.
Future<void> showLeaderboardSheet(BuildContext context) {
  final height = LeaderboardSheet.heightFor(MediaQuery.sizeOf(context).height);
  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    useSafeArea: false,
    isDismissible: true,
    enableDrag: true,
    showDragHandle: false,
    backgroundColor: BrandColors.cream,
    barrierColor: LeaderboardSheet.barrierColor,
    elevation: 0,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(LeaderboardSheet.radius),
      ),
    ),
    clipBehavior: Clip.antiAlias,
    builder: (context) {
      return SizedBox(
        key: const Key('leaderboard-sheet'),
        height: height,
        child: const LeaderboardSheetFrame(),
      );
    },
  );
}

/// Cream sheet surface. Shared by the modal and the `/leaderboard` route.
class LeaderboardSheetFrame extends StatelessWidget {
  const LeaderboardSheetFrame({super.key});

  @override
  Widget build(BuildContext context) {
    return const Material(
      key: Key('leaderboard-sheet-surface'),
      color: BrandColors.cream,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(LeaderboardSheet.radius),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: LeaderboardScreen(),
    );
  }
}

/// `/leaderboard` uses the same sheet, not a full-screen page.
class LeaderboardRoutePage extends StatelessWidget {
  const LeaderboardRoutePage({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final desired = LeaderboardSheet.heightFor(
          MediaQuery.sizeOf(context).height,
        );
        final height = desired > constraints.maxHeight
            ? constraints.maxHeight
            : desired;
        return Material(
          color: LeaderboardSheet.barrierColor,
          child: Stack(
            children: [
              Positioned.fill(
                child: GestureDetector(
                  onTap: () => Navigator.of(context).maybePop(),
                  behavior: HitTestBehavior.opaque,
                ),
              ),
              Align(
                alignment: Alignment.bottomCenter,
                child: SizedBox(
                  key: const Key('leaderboard-sheet'),
                  height: height,
                  child: const LeaderboardSheetFrame(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// All-time board. Each open fetches `get_leaderboard` / `get_my_score`.
/// Scores are not stored on device.
class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  var _loading = true;
  Object? _error;
  List<LeaderboardEntry> _rows = const [];
  LeaderboardEntry? _me;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_load());
    });
  }

  Future<void> _load() async {
    final repo = context.read<AppServices>().leaderboard;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rows = await repo.fetchLeaderboard();
      final me = await repo.fetchMyScore();
      if (!mounted) return;
      setState(() {
        _rows = rows;
        _me = me;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.watch<LocaleController>().strings;
    final myId = context.read<AppServices>().auth.currentUser?.id;
    final me = _me;
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Material(
      key: const Key('leaderboard-sheet-body'),
      color: BrandColors.cream,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 8),
          const Center(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: BrandColors.beige,
                borderRadius: BorderRadius.all(Radius.circular(2)),
              ),
              child: SizedBox(width: 36, height: 4),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 4, 16, 4),
            child: Row(
              children: [
                Semantics(
                  button: true,
                  label: strings.closeCta,
                  excludeSemantics: true,
                  child: IconButton(
                    key: const Key('leaderboard-close'),
                    tooltip: strings.closeCta,
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(
                      Icons.arrow_back,
                      color: BrandColors.forest,
                    ),
                    style: IconButton.styleFrom(
                      foregroundColor: BrandColors.forest,
                      minimumSize: const Size(
                        LeaderboardSheet.closeHit,
                        LeaderboardSheet.closeHit,
                      ),
                      fixedSize: const Size(
                        LeaderboardSheet.closeHit,
                        LeaderboardSheet.closeHit,
                      ),
                      padding: EdgeInsets.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    strings.leaderboardTitle,
                    key: const Key('leaderboard-title'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: 'Playfair Display',
                      fontSize: 28,
                      height: 1.15,
                      fontWeight: FontWeight.w600,
                      color: BrandColors.forest,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_loading)
            const Expanded(
              child: Center(
                child: SizedBox(
                  key: Key('leaderboard-loading'),
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: BrandColors.forest,
                  ),
                ),
              ),
            )
          else if (_error != null)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      strings.leaderboardError,
                      key: const Key('leaderboard-error'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: BrandColors.error),
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      key: const Key('leaderboard-retry'),
                      onPressed: _load,
                      style: FilledButton.styleFrom(
                        backgroundColor: BrandColors.forest,
                        foregroundColor: BrandColors.cream,
                      ),
                      child: Text(strings.leaderboardRetry),
                    ),
                  ],
                ),
              ),
            )
          else ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _MeCard(me: me, myId: myId),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Theme(
                data: Theme.of(context)
                    .copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  key: const Key('leaderboard-how'),
                  backgroundColor: Colors.transparent,
                  collapsedBackgroundColor: Colors.transparent,
                  shape: const Border(),
                  collapsedShape: const Border(),
                  iconColor: BrandColors.forest,
                  collapsedIconColor: BrandColors.bark,
                  title: Text(
                    strings.leaderboardHowTitle,
                    style: const TextStyle(
                      color: BrandColors.forest,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                      child: Text(
                        strings.leaderboardHowBody,
                        key: const Key('leaderboard-how-body'),
                        style: const TextStyle(
                          color: BrandColors.bark,
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: _rows.isEmpty
                  ? ListView(
                      padding: EdgeInsets.only(bottom: 12 + bottomInset),
                      children: const [SizedBox(height: 48), _EmptyBoard()],
                    )
                  : ListView.separated(
                      key: const Key('leaderboard-list'),
                      padding: EdgeInsets.only(bottom: 12 + bottomInset),
                      itemCount: _rows.length,
                      separatorBuilder: (context, index) => const Divider(
                        height: 1,
                        thickness: 1,
                        color: BrandColors.beige,
                      ),
                      itemBuilder: (context, index) {
                        final entry = _rows[index];
                        final isMine = myId != null && entry.userId == myId;
                        return _BoardRow(entry: entry, highlighted: isMine);
                      },
                    ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MeCard extends StatelessWidget {
  const _MeCard({required this.me, required this.myId});

  final LeaderboardEntry? me;
  final String? myId;

  @override
  Widget build(BuildContext context) {
    final strings = context.watch<LocaleController>().strings;
    final authName = context.read<AppServices>().auth.currentUser?.displayName;
    final score = me ?? LeaderboardEntry.unscored;
    final name = leaderboardPersonName(
      displayName: score.displayName ?? authName,
      isSelf: true,
      selfLabel: strings.leaderboardMe,
    );
    final scoreLine = score.hasRank
        ? strings.leaderboardRankLine(score.rank!, score.totalPoints)
        : strings.leaderboardNoPoints;

    return DecoratedBox(
      key: const Key('leaderboard-me'),
      decoration: BoxDecoration(
        color: BrandColors.neutral,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: BrandColors.beige),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                LeaderboardAvatar(
                  name: name,
                  imageUrl: score.avatarUrl,
                  size: 40,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    name,
                    key: const Key('leaderboard-me-name'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: BrandColors.forest,
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  scoreLine,
                  key: const Key('leaderboard-me-points'),
                  style: const TextStyle(
                    color: BrandColors.forest,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              strings.leaderboardBreakdown(
                score.placePoints,
                score.challengePoints,
              ),
              key: const Key('leaderboard-breakdown'),
              style: const TextStyle(color: BrandColors.bark, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyBoard extends StatelessWidget {
  const _EmptyBoard();

  @override
  Widget build(BuildContext context) {
    final strings = context.watch<LocaleController>().strings;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          Text(
            strings.leaderboardEmpty,
            key: const Key('leaderboard-empty'),
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: BrandColors.forest,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            strings.leaderboardEmptyBody,
            key: const Key('leaderboard-empty-body'),
            textAlign: TextAlign.center,
            style: const TextStyle(color: BrandColors.bark, height: 1.35),
          ),
          const SizedBox(height: 8),
          Text(
            strings.leaderboardEmptyHint,
            key: const Key('leaderboard-empty-hint'),
            textAlign: TextAlign.center,
            style: const TextStyle(color: BrandColors.bark, height: 1.35),
          ),
        ],
      ),
    );
  }
}

class _BoardRow extends StatelessWidget {
  const _BoardRow({required this.entry, required this.highlighted});

  final LeaderboardEntry entry;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final strings = context.watch<LocaleController>().strings;
    final name = leaderboardPersonName(
      displayName: entry.displayName,
      isSelf: highlighted,
      selfLabel: strings.leaderboardMe,
    );
    return ColoredBox(
      key: Key('leaderboard-row-${entry.userId}'),
      color: highlighted ? BrandColors.neutral : BrandColors.cream,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            SizedBox(
              width: 32,
              child: Text(
                '${entry.rank ?? ''}',
                style: const TextStyle(
                  color: BrandColors.forest,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            LeaderboardAvatar(name: name, imageUrl: entry.avatarUrl, size: 40),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: BrandColors.forest),
              ),
            ),
            Text(
              strings.pointsLabel(entry.totalPoints),
              style: const TextStyle(
                color: BrandColors.forest,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _initial(String name) {
  if (name.isEmpty || name == '—') return '?';
  return String.fromCharCodes([name.runes.first]).toUpperCase();
}

class LeaderboardAvatar extends StatelessWidget {
  const LeaderboardAvatar({
    super.key,
    required this.name,
    this.imageUrl,
    this.size = 40,
  });

  final String name;
  final String? imageUrl;
  final double size;

  @override
  Widget build(BuildContext context) {
    final initial = _initial(name);
    final fallback = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: BrandColors.beige,
        shape: BoxShape.circle,
      ),
      child: Text(
        initial,
        style: TextStyle(
          color: BrandColors.forest,
          fontWeight: FontWeight.w700,
          fontSize: size * 0.4,
        ),
      ),
    );
    final url = imageUrl;
    if (url == null || url.isEmpty) return fallback;
    return ClipOval(
      child: Image.network(
        url,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => fallback,
      ),
    );
  }
}
