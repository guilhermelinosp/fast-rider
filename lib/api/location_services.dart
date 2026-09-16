import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import 'package:fast_rider/config/app_config.dart';

class AddressPlace {
  const AddressPlace({required this.label, required this.point});
  final String label;
  final LatLng point;
}

class RoadRoute {
  RoadRoute({
    required List<LatLng> points,
    required this.distanceMeters,
    required this.durationSeconds,
  }) : points = List.unmodifiable(points);
  final List<LatLng> points;
  final double distanceMeters;
  final double durationSeconds;
}

abstract interface class Geocoder {
  Future<List<AddressPlace>> search(String query);
}

abstract interface class RoadRouter {
  Future<RoadRoute> route(LatLng pickup, LatLng destination);
}

class LocationException implements Exception {
  const LocationException(this.code, this.message);
  final String code;
  final String message;
  @override
  String toString() => '$code: $message';
}

/// One queue shared by all default geocoders in this application isolate.
/// Serial execution also prevents a burst when several requests are waiting.
class SearchScheduler {
  SearchScheduler({
    DateTime Function()? now,
    Future<void> Function(Duration)? sleep,
  }) : now = now ?? DateTime.now,
       _sleep = sleep ?? Future<void>.delayed;
  static final shared = SearchScheduler();
  final DateTime Function() now;
  final Future<void> Function(Duration) _sleep;
  Future<void> _tail = Future.value();
  DateTime? _nextStart;

  void defer(Duration duration) {
    final until = now().add(duration);
    if (_nextStart == null || until.isAfter(_nextStart!)) _nextStart = until;
  }

  Future<T> run<T>(Future<T> Function() action) {
    final result = _tail.then((_) async {
      final wait = _nextStart?.difference(now()) ?? Duration.zero;
      if (wait > Duration.zero) await _sleep(wait);
      _nextStart = now().add(const Duration(seconds: 1));
      return action();
    });
    _tail = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }
}

bool validCoordinate(LatLng p) =>
    p.latitude.isFinite &&
    p.longitude.isFinite &&
    p.latitude.abs() <= 90 &&
    p.longitude.abs() <= 180;

Uri _endpoint(String value) {
  final uri = Uri.tryParse(value);
  if (uri == null ||
      !['https', 'http'].contains(uri.scheme) ||
      uri.host.isEmpty ||
      uri.userInfo.isNotEmpty ||
      uri.hasFragment) {
    throw const LocationException(
      'invalid_configuration',
      'URL do provedor inválida.',
    );
  }
  return uri;
}

Future<http.Response> _get(
  http.Client client,
  Uri uri,
  String userAgent,
  Duration timeout,
) async {
  try {
    return await client
        .get(
          uri,
          headers: {
            'User-Agent': userAgent,
            'Accept': 'application/json',
            'Accept-Language': 'pt-BR,pt;q=0.9',
          },
        )
        .timeout(timeout);
  } on TimeoutException {
    throw const LocationException(
      'timeout',
      'O serviço demorou a responder. Tente novamente.',
    );
  } on http.ClientException {
    throw const LocationException(
      'connection_error',
      'Não foi possível conectar ao serviço.',
    );
  } on SocketException {
    throw const LocationException(
      'connection_error',
      'Não foi possível conectar ao serviço.',
    );
  }
}

void _checkStatus(http.Response response) {
  if (response.statusCode == 429) {
    throw const LocationException(
      'rate_limited',
      'Limite do provedor atingido. Aguarde antes de buscar novamente.',
    );
  }
  if (response.statusCode < 200 || response.statusCode >= 300) {
    throw LocationException(
      'http_error',
      'Serviço indisponível (HTTP ${response.statusCode}). Tente novamente.',
    );
  }
}

/// Nominatim-compatible /search API. No autocomplete or background searches.
/// Cache is bounded, memory-only, ten minutes; failed requests are never cached.
class NominatimGeocoder implements Geocoder {
  NominatimGeocoder({
    String? baseUrl,
    String? userAgent,
    http.Client? client,
    SearchScheduler? scheduler,
    this.timeout = const Duration(seconds: 10),
  }) : baseUrl = baseUrl ?? AppConfig.geocodingUrl,
       userAgent = userAgent ?? AppConfig.mapsUserAgent,
       _client = client ?? http.Client(),
       _ownsClient = client == null,
       scheduler = scheduler ?? SearchScheduler.shared;
  final String baseUrl;
  final String userAgent;
  final Duration timeout;
  final SearchScheduler scheduler;
  final http.Client _client;
  final bool _ownsClient;
  final _cache = <String, ({DateTime at, List<AddressPlace> places})>{};
  final _pending = <String, Future<List<AddressPlace>>>{};
  bool _closed = false;

  @override
  Future<List<AddressPlace>> search(String query) async {
    if (_closed) throw const LocationException('closed', 'Busca encerrada.');
    final normalized = query.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (normalized.isEmpty) return const [];
    if (normalized.length > 300) {
      throw const LocationException(
        'invalid_query',
        'Use um endereço com até 300 caracteres.',
      );
    }
    final key = normalized.toLowerCase();
    final cached = _cache[key];
    if (cached != null &&
        scheduler.now().difference(cached.at) < const Duration(minutes: 10)) {
      return cached.places;
    }
    if (_pending[key] case final future?) return future;
    final future = scheduler.run(() async {
      if (_closed) throw const LocationException('closed', 'Busca encerrada.');
      final endpoint = _endpoint(baseUrl);
      final response = await _get(
        _client,
        endpoint.replace(
          queryParameters: {
            ...endpoint.queryParameters,
            'q': normalized,
            'format': 'jsonv2',
            'limit': '5',
          },
        ),
        userAgent,
        timeout,
      );
      if (response.statusCode == 429 || response.statusCode == 503) {
        final header = response.headers['retry-after'];
        final seconds = int.tryParse(header ?? '');
        Duration delay = const Duration(seconds: 60);
        if (seconds != null && seconds >= 0) {
          delay = Duration(seconds: seconds);
        } else if (header != null) {
          try {
            delay = HttpDate.parse(header).difference(scheduler.now());
          } on FormatException {
            /* use default */
          }
        }
        scheduler.defer(delay);
      }
      _checkStatus(response);
      try {
        final decoded = jsonDecode(response.body);
        if (decoded is! List) throw const FormatException();
        final places = decoded
            .map((item) {
              if (item is! Map<String, dynamic>) throw const FormatException();
              final label = item['display_name'];
              final lat = double.tryParse('${item['lat']}');
              final lon = double.tryParse('${item['lon']}');
              if (label is! String ||
                  label.trim().isEmpty ||
                  lat == null ||
                  lon == null) {
                throw const FormatException();
              }
              final point = LatLng(lat, lon);
              if (!validCoordinate(point)) throw const FormatException();
              return AddressPlace(label: label, point: point);
            })
            .toList(growable: false);
        final result = List<AddressPlace>.unmodifiable(places);
        _cache.remove(key);
        if (_cache.length >= 100) _cache.remove(_cache.keys.first);
        _cache[key] = (at: scheduler.now(), places: result);
        return result;
      } on FormatException {
        throw const LocationException(
          'malformed_response',
          'Resposta de endereços inválida. Tente novamente.',
        );
      }
    });
    _pending[key] = future;
    try {
      return await future;
    } finally {
      final _ = _pending.remove(key);
    }
  }

  void close() {
    _closed = true;
    _cache.clear();
    if (_ownsClient) _client.close();
  }
}

/// OSRM-compatible driving route. Never substitutes a straight line for failure.
class OsrmRouter implements RoadRouter {
  OsrmRouter({
    String? baseUrl,
    String? userAgent,
    http.Client? client,
    this.timeout = const Duration(seconds: 15),
  }) : baseUrl = baseUrl ?? AppConfig.routingUrl,
       userAgent = userAgent ?? AppConfig.mapsUserAgent,
       _client = client ?? http.Client(),
       _ownsClient = client == null;

  final String baseUrl;
  final String userAgent;
  final Duration timeout;
  final http.Client _client;
  final bool _ownsClient;

  @override
  Future<RoadRoute> route(LatLng pickup, LatLng destination) async {
    if (!validCoordinate(pickup) ||
        !validCoordinate(destination) ||
        pickup == destination) {
      throw const LocationException(
        'invalid_coordinates',
        'Origem e destino devem ser pontos válidos e diferentes.',
      );
    }
    final base = _endpoint(baseUrl);
    final path =
        '${base.path.replaceFirst(RegExp(r'/+$'), '')}/route/v1/driving/'
        '${pickup.longitude},${pickup.latitude};${destination.longitude},${destination.latitude}';
    final response = await _get(
      _client,
      base.replace(
        path: path,
        queryParameters: {
          ...base.queryParameters,
          'overview': 'full',
          'geometries': 'geojson',
          'steps': 'false',
        },
      ),
      userAgent,
      timeout,
    );
    _checkStatus(response);
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) throw const FormatException();
      if (decoded['code'] == 'NoRoute' || decoded['code'] == 'NoSegment') {
        throw const LocationException(
          'no_route',
          'Nenhuma rota viária encontrada entre esses endereços.',
        );
      }
      if (decoded['code'] != 'Ok') {
        throw const LocationException(
          'provider_error',
          'O provedor não conseguiu calcular a rota.',
        );
      }
      final routes = decoded['routes'];
      if (routes is! List) throw const FormatException();
      if (routes.isEmpty) {
        throw const LocationException(
          'no_route',
          'Nenhuma rota viária encontrada entre esses endereços.',
        );
      }
      final route = routes.first;
      if (route is! Map) throw const FormatException();
      final geometry = route['geometry'];
      final distance = route['distance'];
      final duration = route['duration'];
      if (geometry is! Map ||
          geometry['type'] != 'LineString' ||
          distance is! num ||
          !distance.isFinite ||
          distance < 0 ||
          duration is! num ||
          !duration.isFinite ||
          duration < 0) {
        throw const FormatException();
      }
      final coordinates = geometry['coordinates'];
      if (coordinates is! List || coordinates.length < 2) {
        throw const FormatException();
      }
      final points = coordinates.map((pair) {
        if (pair is! List ||
            pair.length < 2 ||
            pair[0] is! num ||
            pair[1] is! num) {
          throw const FormatException();
        }
        final p = LatLng(
          (pair[1] as num).toDouble(),
          (pair[0] as num).toDouble(),
        );
        if (!validCoordinate(p)) throw const FormatException();
        return p;
      }).toList();
      if (points.every((p) => p == points.first)) throw const FormatException();
      return RoadRoute(
        points: points,
        distanceMeters: distance.toDouble(),
        durationSeconds: duration.toDouble(),
      );
    } on FormatException {
      throw const LocationException(
        'malformed_response',
        'Resposta de rota inválida. Tente novamente.',
      );
    }
  }

  void close() {
    if (_ownsClient) _client.close();
  }
}
