import 'dart:convert';

import 'package:flutter/services.dart';

import 'place.dart';

abstract class PlaceCatalog {
  Future<List<Place>> fetchAll();
}

class AssetPlaceCatalog implements PlaceCatalog {
  const AssetPlaceCatalog({this.assetPath = 'assets/map/pois.geojson'});

  final String assetPath;

  @override
  Future<List<Place>> fetchAll() async {
    final raw = await rootBundle.loadString(assetPath);
    final decoded = jsonDecode(raw);
    if (decoded is! Map) {
      throw const FormatException('Place catalog is not a FeatureCollection');
    }
    final places = Place.fromFeatureCollection(
      Map<String, dynamic>.from(decoded),
    );
    if (places.isEmpty) {
      throw const FormatException('Place catalog is empty');
    }
    return places;
  }
}

class MemoryPlaceCatalog implements PlaceCatalog {
  const MemoryPlaceCatalog(this.places, {this.error});

  final List<Place> places;
  final Object? error;

  @override
  Future<List<Place>> fetchAll() async {
    if (error != null) throw error!;
    return List<Place>.from(places);
  }
}
