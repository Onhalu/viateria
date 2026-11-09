import 'package:flutter/widgets.dart';

/// True when the platform asks for reduced motion.
///
/// Covers both [MediaQuery.disableAnimationsOf] and
/// [MediaQuery.accessibleNavigationOf]. Reduced motion drops spring, stretch,
/// burst, and shake; the new state is shown on the next frame.
bool motionReduced(BuildContext context) {
  return MediaQuery.disableAnimationsOf(context) ||
      MediaQuery.accessibleNavigationOf(context);
}
