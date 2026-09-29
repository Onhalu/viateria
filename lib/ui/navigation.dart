import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../data/last_opened_challenge.dart';

/// Records [challengeId] as last-opened and pushes the challenge detail route.
///
/// [fromProfile] nests the detail under `/profile` so the profile branch
/// stays selected. Profile is the bottom-nav tab. Žebříček opens as a
/// sheet from the welcome header and the profile card.
Future<void> openChallenge(
  BuildContext context,
  String challengeId, {
  bool fromProfile = false,
}) async {
  await context.read<LastOpenedChallengeStore>().remember(challengeId);
  if (!context.mounted) return;
  context.push(
    fromProfile ? '/profile/challenge/$challengeId' : '/challenge/$challengeId',
  );
}
