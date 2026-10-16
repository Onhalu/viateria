import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

var _dateFormatsReady = false;

void ensureLocaleDateFormats() {
  if (_dateFormatsReady) return;
  initializeDateFormatting();
  _dateFormatsReady = true;
}

/// Calendar date for [locale] via [DateFormat.yMMMd].
String formatLocaleDate(DateTime date, String locale) {
  ensureLocaleDateFormats();
  final tag = switch (locale) {
    'cs' => 'cs',
    'de' => 'de',
    _ => 'en',
  };
  return DateFormat.yMMMd(tag).format(date.toLocal());
}
