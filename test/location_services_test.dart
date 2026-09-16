import 'dart:async';
import 'dart:convert';

import 'package:fast_rider/api/location_services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:latlong2/latlong.dart';

const a = LatLng(-23.55, -46.63);
const b = LatLng(-23.56, -46.65);
final placesJson = [
  {'display_name': 'Praça da Sé, São Paulo', 'lat': '-23.55', 'lon': '-46.63'},
  {'display_name': 'Outra Praça da Sé', 'lat': '-22.5', 'lon': '-45.6'},
];
final routeJson = {
  'code': 'Ok',
  'routes': [
    {
      'distance': 3200,
      'duration': 600,
      'geometry': {
        'type': 'LineString',
        'coordinates': [
          [-46.63, -23.55],
          [-46.64, -23.57],
          [-46.65, -23.56],
        ],
      },
    },
  ],
};

class TestClock {
  DateTime value = DateTime.utc(2026);
  final waits = <Duration>[];
  DateTime now() => value;
  Future<void> sleep(Duration duration) async {
    waits.add(duration);
    value = value.add(duration);
  }

  SearchScheduler scheduler() => SearchScheduler(now: now, sleep: sleep);
}

Matcher failure(String code) =>
    throwsA(isA<LocationException>().having((e) => e.code, 'code', code));

void main() {
  test('explicit geocoding encodes query, identifies app, parses and caches normalized searches', () async {
    final requests = <http.Request>[];
    final client = NominatimGeocoder(
      baseUrl: 'https://geo.example/search',
      userAgent: 'FastRiderTests/1.0',
      scheduler: TestClock().scheduler(),
      client: MockClient((r) async {
        requests.add(r);
        return http.Response(jsonEncode(placesJson), 200);
      }),
    );
    final found = await client.search('  Praça   da Sé  ');
    expect(found.map((p) => p.label), [
      'Praça da Sé, São Paulo',
      'Outra Praça da Sé',
    ]);
    expect(found.first.point, a);
    expect(
      requests.single.url.queryParameters,
      containsPair('q', 'Praça da Sé'),
    );
    expect(
      requests.single.url.queryParameters,
      containsPair('format', 'jsonv2'),
    );
    expect(requests.single.headers['user-agent'], 'FastRiderTests/1.0');
    expect(await client.search('praça da sé'), found);
    expect(requests, hasLength(1));
    expect(await client.search('  '), isEmpty);
    expect(requests, hasLength(1));
  });

  test('shared scheduler spaces starts across clients and survives failed requests', () async {
    final clock = TestClock();
    final scheduler = clock.scheduler();
    final starts = <DateTime>[];
    var count = 0;
    final httpClient = MockClient((r) async {
      starts.add(clock.now());
      if (++count == 1) throw http.ClientException('offline');
      return http.Response('[]', 200);
    });
    final first = NominatimGeocoder(client: httpClient, scheduler: scheduler);
    final second = NominatimGeocoder(client: httpClient, scheduler: scheduler);
    await expectLater(first.search('A'), failure('connection_error'));
    await Future.wait([first.search('B'), second.search('C')]);
    expect(starts.map((t) => t.difference(starts.first).inSeconds), [0, 1, 2]);
  });

  test(
    'identical concurrent searches share HTTP and empty results are cached',
    () async {
      final pending = Completer<http.Response>();
      var calls = 0;
      final client = NominatimGeocoder(
        scheduler: TestClock().scheduler(),
        client: MockClient((_) {
          calls++;
          return pending.future;
        }),
      );
      final f1 = client.search('Rua A');
      final f2 = client.search(' rua a ');
      pending.complete(http.Response('[]', 200));
      expect(await f1, isEmpty);
      expect(await f2, isEmpty);
      await client.search('Rua A');
      expect(calls, 1);
    },
  );

  for (final body in [
    'invalid',
    '{}',
    '[{"display_name":"A","lat":"NaN","lon":"0"}]',
    '[{"display_name":"","lat":"0","lon":"0"}]',
  ]) {
    test('geocoding rejects malformed payload $body', () async {
      final client = NominatimGeocoder(
        scheduler: TestClock().scheduler(),
        client: MockClient((_) async => http.Response(body, 200)),
      );
      await expectLater(client.search('Rua'), failure('malformed_response'));
    });
  }

  test(
    '429 honors Retry-After for subsequent manual search without auto retry',
    () async {
      final clock = TestClock();
      var calls = 0;
      final client = NominatimGeocoder(
        scheduler: clock.scheduler(),
        client: MockClient((_) async {
          calls++;
          return calls == 1
              ? http.Response('', 429, headers: {'retry-after': '5'})
              : http.Response('[]', 200);
        }),
      );
      await expectLater(client.search('Rua'), failure('rate_limited'));
      expect(calls, 1);
      await client.search('Rua');
      expect(clock.waits.single, const Duration(seconds: 5));
    },
  );

  test('routing sends lon,lat and decodes real GeoJSON shape including intermediate points', () async {
    late Uri url;
    final client = OsrmRouter(
      baseUrl: 'https://route.example/',
      client: MockClient((r) async {
        url = r.url;
        return http.Response(jsonEncode(routeJson), 200);
      }),
    );
    final route = await client.route(a, b);
    expect(url.path, '/route/v1/driving/-46.63,-23.55;-46.65,-23.56');
    expect(url.queryParameters['geometries'], 'geojson');
    expect(url.queryParameters['overview'], 'full');
    expect(route.points, [a, const LatLng(-23.57, -46.64), b]);
    expect(route.distanceMeters, 3200);
    expect(route.durationSeconds, 600);
  });

  for (final body in ['{"code":"NoRoute"}', '{"code":"Ok","routes":[]}']) {
    test('no route never synthesizes straight line: $body', () async {
      final client = OsrmRouter(
        client: MockClient((_) async => http.Response(body, 200)),
      );
      await expectLater(client.route(a, b), failure('no_route'));
    });
  }
  for (final body in [
    'oops',
    '[]',
    '{"code":"Ok","routes":[{}]}',
    '{"code":"InvalidQuery"}',
  ]) {
    test('routing malformed/provider errors: $body', () async {
      final client = OsrmRouter(
        client: MockClient((_) async => http.Response(body, 200)),
      );
      await expectLater(client.route(a, b), throwsA(isA<LocationException>()));
    });
  }

  test('route timeout and HTTP failures are typed', () async {
    final timeout = OsrmRouter(
      timeout: Duration.zero,
      client: MockClient((_) => Completer<http.Response>().future),
    );
    await expectLater(timeout.route(a, b), failure('timeout'));
    final unavailable = OsrmRouter(
      client: MockClient((_) async => http.Response('unavailable', 503)),
    );
    await expectLater(unavailable.route(a, b), failure('http_error'));
  });
}
