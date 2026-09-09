import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../data/last_opened_challenge.dart';
import '../../l10n/locale_controller.dart';
import '../widgets/empty_state.dart';
import 'challenge_screen.dart';

class LastChallengeScreen extends StatelessWidget {
  const LastChallengeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final strings = context.watch<LocaleController>().strings;
    final challengeId = context.watch<LastOpenedChallengeStore>().challengeId;
    if (challengeId == null || challengeId.isEmpty) {
      return SafeArea(
        bottom: false,
        child: EmptyState(
          key: const Key('last-challenge-empty'),
          title: strings.lastChallengeEmpty,
          hint: strings.lastChallengeEmptyHint,
          actionLabel: strings.lastChallengeBrowse,
          onAction: () => context.go('/'),
        ),
      );
    }
    return ChallengeScreen(
      key: ValueKey(challengeId),
      challengeId: challengeId,
      embedded: true,
    );
  }
}
