import 'package:flutter/widgets.dart';

import '../data/vandery_plus_session.dart';
import '../domain/vandery_plus.dart';

/// Turns a FAPI return into a server poll.
///
/// Web reads [initialUri] (the page URL). Mobile links are delivered by
/// [VanderyPlusSession.consumeReturnUri] from `app_links`. Coming back to
/// the app while checkout is still submitting polls as well.
class VanderyPlusReturnBinding extends StatefulWidget {
  const VanderyPlusReturnBinding({
    super.key,
    required this.session,
    required this.child,
    this.initialUri,
  });

  final VanderyPlusSession session;
  final Widget child;
  final Uri? initialUri;

  @override
  State<VanderyPlusReturnBinding> createState() =>
      _VanderyPlusReturnBindingState();
}

class _VanderyPlusReturnBindingState extends State<VanderyPlusReturnBinding>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final uri = widget.initialUri;
    if (uri != null &&
        parseVanderyPlusReturn(uri) != VanderyPlusReturnKind.none) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        widget.session.consumeReturnUri(uri);
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      widget.session.onAppResumed();
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
