import 'dart:convert';

import 'package:flutter/services.dart';

import '../domain/poi.dart';

abstract class PoiRepository {
  Future<List<Poi>> fetchAll();
}

class AssetPoiRepository implements PoiRepository {
  const AssetPoiRepository({
    this.assetPath = 'assets/map/pois.geojson',
  });

  final String assetPath;

  @override
  Future<List<Poi>> fetchAll() async {
    final raw = await rootBundle.loadString(assetPath);
    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('POI catalog is not a FeatureCollection');
    }
    final pois = Poi.fromFeatureCollection(decoded);
    if (pois.isEmpty) {
      throw const FormatException('POI catalog is empty');
    }
    return pois;
  }
}

class MemoryPoiRepository implements PoiRepository {
  const MemoryPoiRepository(this.pois, {this.error});

  final List<Poi> pois;
  final Object? error;

  @override
  Future<List<Poi>> fetchAll() async {
    if (error != null) throw error!;
    return List<Poi>.from(pois);
  }
}
