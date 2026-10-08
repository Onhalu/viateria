import '../models/models.dart';

/// What the diploma screen and the reward section may show.
enum DiplomaPhase { incomplete, blurred, needName, revoked, ready }

/// Remote `diploma_status` wins when the migration is applied.
/// Otherwise the client uses completion, entitlement, and the profile name.
DiplomaPhase resolveDiplomaPhase({
  required bool completed,
  required bool entitled,
  required bool hasDisplayName,
  String? remoteState,
}) {
  switch (remoteState) {
    case 'locked':
      return DiplomaPhase.incomplete;
    case 'revoked':
      return DiplomaPhase.revoked;
    case 'buy':
      return DiplomaPhase.blurred;
    case 'need_name':
      return DiplomaPhase.needName;
    case 'render':
    case 'ready':
      return DiplomaPhase.ready;
    default:
      break;
  }
  if (!completed) return DiplomaPhase.incomplete;
  if (!entitled) return DiplomaPhase.blurred;
  if (!hasDisplayName) return DiplomaPhase.needName;
  return DiplomaPhase.ready;
}

/// The Edge function is the only source of the full PNG.
bool shouldRequestDiplomaFile(DiplomaPhase phase) =>
    phase == DiplomaPhase.ready;

/// Final printed form for a one-time diploma edit.
/// Null when the trimmed text is empty, longer than 40 characters, or
/// contains an ASCII control character.
String? normalizeDiplomaEditedName(String raw) {
  final name = raw.trim();
  if (name.isEmpty || name.runes.length > 40) return null;
  for (final rune in name.runes) {
    if (rune <= 31 || rune == 127 || (rune >= 128 && rune <= 159)) {
      return null;
    }
  }
  return name;
}

/// `vyslapni-diplom-{slug}.png`
String diplomaFileName(String slug) {
  final clean = slug
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
  return 'vyslapni-diplom-${clean.isEmpty ? 'vyzva' : clean}.png';
}

/// Profile name only. An email address is not a diploma name.
bool hasDiplomaDisplayName(String? displayName) {
  final name = displayName?.trim();
  return name != null && name.isNotEmpty;
}

/// Prefer the SQL label. Otherwise format [completedAt] in Europe/Prague.
String? diplomaCompletionLine({String? remoteLabel, DateTime? completedAt}) {
  final remote = remoteLabel?.trim();
  if (remote != null && remote.isNotEmpty) return remote;
  if (completedAt == null) return null;
  return formatDiplomaCompletedOn(completedAt);
}
