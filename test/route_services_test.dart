import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:latlong2/latlong.dart';
import 'package:viateria/data/route_services.dart';
import 'package:viateria/domain/route_planner.dart';
import 'package:viateria/models/models.dart';

import 'helpers/fakes.dart';

void main() {
  test('parseCoordinateQuery accepts lat, lng', () {
    final point = parseCoordinateQuery(' 50.08, 14.42 ');
    expect(point, isNotNull);
    expect(point!.lat, 50.08);
    expect(point.lng, 14.42);
    expect(parseCoordinateQuery('Praha'), isNull);
    expect(parseCoordinateQuery('91, 0'), isNull);
  });

  test('samplePoints keeps ends and downsamples', () {
    final line = [for (var i = 0; i < 10; i++) LatLng(50 + i * 0.01, 14)];
    final sampled = samplePoints(line, maxPoints: 5);
    expect(sampled, hasLength(5));
    expect(sampled.first, line.first);
    expect(sampled.last, line.last);
    expect(samplePoints(const []), isEmpty);
  });

  test('OsrmRoutingClient parses FOSSGIS geojson', () async {
    final client = OsrmRoutingClient(
      client: MockClient((request) async {
        expect(request.url.host, 'routing.openstreetmap.de');
        expect(request.url.path, contains('routed-foot'));
        expect(request.headers['User-Agent'], contains('Viateria'));
        return http.Response(
          '{"code":"Ok","routes":[{"distance":1600.4,"duration":1080,'
          '"geometry":{"coordinates":[[14.42,50.08],[14.425,50.085],'
          '[14.43,50.09]]}}]}',
          200,
        );
      }),
    );
    final path = await client.route(
      mode: TravelMode.hike,
      start: const LatLng(50.08, 14.42),
      end: const LatLng(50.09, 14.43),
    );
    expect(path.distanceKm, closeTo(1.6004, 0.0001));
    expect(path.points, hasLength(3));
    expect(path.points.first.latitude, 50.08);
    expect(path.points.first.longitude, 14.42);
  });

  test('OsrmRoutingClient fails on non-Ok payload', () async {
    final client = OsrmRoutingClient(
      client: MockClient((request) async {
        return http.Response('{"code":"NoRoute","routes":[]}', 200);
      }),
    );
    expect(
      () => client.route(
        mode: TravelMode.bike,
        start: const LatLng(50, 14),
        end: const LatLng(50.1, 14.1),
      ),
      throwsA(isA<RoutingFailure>()),
    );
  });

  test('NominatimGeocoder returns first hit', () async {
    final geocoder = NominatimGeocoder(
      client: MockClient((request) async {
        expect(request.url.host, 'nominatim.openstreetmap.org');
        return http.Response(
          '[{"lat":"50.0755","lon":"14.4378","display_name":"Praha"}]',
          200,
        );
      }),
    );
    final found = await geocoder.findPlace('Praha');
    expect(found?.lat, 50.0755);
    expect(found?.lng, 14.4378);
    expect(found?.label, 'Praha');
  });

  test('DualRoutePlanner returns walking and cycling stats', () async {
    final plan =
        await DualRoutePlanner(
          routing: MemoryRoutingClient(),
          elevation: MemoryElevationLookup(),
        ).plan(
          start: const RouteEndpoint(lat: 50.08, lng: 14.42, label: 'A'),
          end: const RouteEndpoint(lat: 50.09, lng: 14.43, label: 'B'),
        );
    expect(plan.hike, isNotNull);
    expect(plan.bike, isNotNull);
    expect(plan.hike!.distanceKm, 1.6);
    expect(plan.bike!.distanceKm, 1.2);
    expect(plan.hike!.elevationGainM, greaterThan(0));
    expect(plan.hike!.estimatedTime.inMinutes, greaterThan(0));
    expect(plan.bike!.estimatedTime < plan.hike!.estimatedTime, isTrue);
    expect(plan.hikeLine, isNotEmpty);
    expect(plan.bikeLine, isNotEmpty);
  });

  test('DualRoutePlanner throws when both profiles fail', () async {
    expect(
      () =>
          DualRoutePlanner(
            routing: MemoryRoutingClient(fail: true),
            elevation: MemoryElevationLookup(),
          ).plan(
            start: const RouteEndpoint(lat: 50.08, lng: 14.42, label: 'A'),
            end: const RouteEndpoint(lat: 50.09, lng: 14.43, label: 'B'),
          ),
      throwsA(isA<RoutingFailure>()),
    );
  });

  test('DualRoutePlanner is empty when start and end match', () async {
    const point = RouteEndpoint(lat: 50.08, lng: 14.42, label: 'A');
    final plan = await DualRoutePlanner(
      routing: MemoryRoutingClient(),
      elevation: MemoryElevationLookup(),
    ).plan(start: point, end: point);
    expect(plan.isEmpty, isTrue);
  });
}
