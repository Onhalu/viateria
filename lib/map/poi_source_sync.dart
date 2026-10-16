import 'place.dart';

/// Skips [setGeoJsonSource] when the marker payload has not changed.
class PoiSourceGate {
  int? _signature;

  /// True only the first time [signature] is seen.
  bool shouldReplace(int signature) {
    if (_signature == signature) return false;
    _signature = signature;
    return true;
  }
}

/// Cheap content hash: place id + derived placeState, plus selection.
int poiMarkerSignature({
  required List<Place> places,
  required String? selectedId,
  required Set<String> challengePlaceIds,
  required Set<String> verifiedPlaceIds,
}) {
  var hash = Object.hash(
    selectedId,
    Object.hashAllUnordered(challengePlaceIds),
    Object.hashAllUnordered(verifiedPlaceIds),
  );
  for (final place in places) {
    hash = Object.hash(
      hash,
      place.id,
      placeStateOf(
        inChallenge: challengePlaceIds.contains(place.id),
        verified: verifiedPlaceIds.contains(place.id),
      ),
    );
  }
  return hash;
}
