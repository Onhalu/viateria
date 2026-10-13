import 'package:flutter/foundation.dart';

import '../data/route_services.dart';
import '../domain/route_planner.dart';
import '../models/models.dart';

/// Route planner, navigation, and destination. Notifies only the widgets
/// that draw the map and the planner, not the photo gallery or reward.
class ChallengeRouteController extends ChangeNotifier {
  String? destinationId;
  RouteEndpoint? start;
  DualRoutePlan? routes;
  var routing = false;
  var enteringCustomStart = false;
  String? routeError;
  TravelMode? navigating;

  void apply(void Function(ChallengeRouteController route) change) {
    change(this);
    notifyListeners();
  }
}
