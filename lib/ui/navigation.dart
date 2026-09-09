import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../data/last_opened_challenge.dart';

/// Records [challengeId] as last-opened and pushes the challenge detail route.
Future<void> openChallenge(BuildContext context, String challengeId) async {
  await context.read<LastOpenedChallengeStore>().remember(challengeId);
  if (!context.mounted) return;
  context.push('/challenge/$challengeId');
}
