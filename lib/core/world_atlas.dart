import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/services.dart';

import 'geography.dart';

class AtlasSource {
  AtlasSource({WorldAtlas? initial})
    : _loading = initial == null ? null : Future.value(initial);

  Future<WorldAtlas>? _loading;

  Future<WorldAtlas> load() => _loading ??= _read();

  Future<WorldAtlas> _read() async {
    try {
      final raw = await rootBundle.loadString('assets/data/world.v1.json');
      return WorldAtlas.decode(raw);
    } catch (_) {
      _loading = null;
      rethrow;
    }
  }
}

/// Equirectangular map coordinates. East points right regardless of UI locale.
class WorldAtlas {
  WorldAtlas._(this.features, this.countries);

  factory WorldAtlas.decode(String data) {
    final json = jsonDecode(data) as Map<String, dynamic>;
    if (json['version'] != 1) throw const FormatException('Invalid map schema');
    final features = <MapFeature>[];
    final countries = <String, MapFeature>{};
    for (final entry in json['shapes'] as List) {
      final row = entry as List;
      final id = row[0] as String?;
      final longitude = (row[1] as num) / 1000;
      final latitude = (row[2] as num) / 1000;
      final rings = (row[3] as List)
          .map((ring) => (ring as List).cast<int>())
          .toList();
      if (longitude.abs() > 180 ||
          latitude.abs() > 90 ||
          rings.isEmpty ||
          rings.any((ring) => ring.length < 6 || ring.length.isOdd) ||
          (id != null && countries.containsKey(id))) {
        throw FormatException('Invalid map feature $id');
      }
      final feature = MapFeature._(id, longitude, latitude, rings);
      features.add(feature);
      if (id != null) countries[id] = feature;
    }
    return WorldAtlas._(
      List.unmodifiable(features),
      Map.unmodifiable(countries),
    );
  }

  static const extent = Rect.fromLTWH(0, 0, 360, 180);
  final List<MapFeature> features;
  final Map<String, MapFeature> countries;

  String? hitTest(
    Offset point, {
    Set<String>? allowed,
    double markerRadius = 0,
  }) {
    String? nearestMarker;
    var nearestDistance = markerRadius;
    for (final feature in countries.values) {
      final id = feature.id!;
      if (!feature.tiny || (allowed != null && !allowed.contains(id))) continue;
      final distance = (point - feature.anchor).distance;
      if (distance < nearestDistance) {
        nearestMarker = id;
        nearestDistance = distance;
      }
    }

    if (nearestMarker != null) return nearestMarker;
    for (final feature in countries.values) {
      final id = feature.id!;
      if (allowed != null && !allowed.contains(id)) continue;
      if (feature.bounds.contains(point) && feature.path.contains(point)) {
        return id;
      }
    }
    return null;
  }

  static Rect extentFor(Chapter chapter) => switch (chapter) {
    Chapter.africa => const Rect.fromLTRB(153, 50, 237, 131),
    Chapter.asia => const Rect.fromLTRB(200, 12, 360, 106),
    Chapter.europe => const Rect.fromLTRB(153, 15, 232, 57),
    Chapter.northAmerica => const Rect.fromLTRB(10, 8, 129, 86),
    Chapter.southAmerica => const Rect.fromLTRB(95, 75, 150, 151),
    Chapter.oceania => const Rect.fromLTRB(290, 60, 360, 139),
    Chapter.arab => const Rect.fromLTRB(160, 51, 244, 105),
    Chapter.world => extent,
  };
}

class MapFeature {
  MapFeature._(this.id, this.longitude, this.latitude, this._rings);

  final String? id;
  final double longitude;
  final double latitude;
  final List<List<int>> _rings;

  Offset get anchor => Offset(longitude + 180, 90 - latitude);
  late final Path path = _makePath();
  late final Rect bounds = path.getBounds();
  late final Path outline = _makePath(wrapAround: longitude);
  late final Rect outlineBounds = outline.getBounds();
  late final bool tiny = math.max(bounds.width, bounds.height) < 1.15;

  Path _makePath({double? wrapAround}) {
    final result = Path()..fillType = PathFillType.evenOdd;
    for (final ring in _rings) {
      // Shift the entire ring, so a country split at ±180° is compact without
      // stretching or mirroring any boundary in its silhouette.
      final firstLongitude = ring[0] / 1000;
      final wrap = wrapAround == null
          ? 0
          : ((firstLongitude - wrapAround + 180) / 360).floor();
      for (var index = 0; index < ring.length; index += 2) {
        final x = ring[index] / 1000 + 180 - wrap * 360;
        final y = 90 - ring[index + 1] / 1000;
        if (index == 0) {
          result.moveTo(x, y);
        } else {
          result.lineTo(x, y);
        }
      }
      result.close();
    }
    return result;
  }
}
