import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The catalog results [ListView], not nested hero/featured scrollables.
Finder catalogVerticalScrollable() {
  return find.descendant(
    of: find.byKey(const Key('catalog-results')),
    matching: find.byWidgetPredicate(
      (widget) =>
          widget is Scrollable && widget.axisDirection == AxisDirection.down,
    ),
  );
}
