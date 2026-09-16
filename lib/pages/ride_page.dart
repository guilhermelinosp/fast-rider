import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';

import 'package:fast_rider/api/location_services.dart';
import 'package:fast_rider/api/ride_api_client.dart';
import 'package:fast_rider/location/current_location.dart';
import 'package:fast_rider/ride_theme.dart';
import 'package:fast_rider/widgets/ride_map.dart';

class RidePage extends StatefulWidget {
  const RidePage({
    super.key,
    required this.apiClient,
    required this.riderId,
    this.geocoder,
    this.router,
    this.tileProvider,
    this.currentLocation,
  });

  /// Kept for compatibility with the existing app composition. This preview
  /// screen never creates a ride.
  final RideApiClient apiClient;
  final String riderId;
  final Geocoder? geocoder;
  final RoadRouter? router;
  final TileProvider? tileProvider;
  final CurrentLocation? currentLocation;

  @override
  State<RidePage> createState() => _RidePageState();
}

class _AddressInput {
  final controller = TextEditingController();
  int revision = 0;
  bool busy = false;
  String? message;
  AddressPlace? selected;
}

class _RidePageState extends State<RidePage> with WidgetsBindingObserver {
  final _destination = _AddressInput();
  final _destinationSurfaceKey = GlobalKey();
  late final Geocoder _geocoder = widget.geocoder ?? NominatimGeocoder();
  late final RoadRouter _router = widget.router ?? OsrmRouter();
  late final CurrentLocation _location =
      widget.currentLocation ?? deviceCurrentLocation();

  LocationAttempt? _locationAttempt;
  AddressPlace? _pickup;
  int _locationRevision = 0;
  bool _locating = false;
  String? _locationMessage;

  int _routeRevision = 0;
  bool _routing = false;
  RoadRoute? _route;
  String? _routeError;
  bool _mapErrorShown = false;
  double _destinationHeight = 72;
  bool _destinationMeasurementScheduled = false;

  bool get _busy => _destination.busy || _locating || _routing;

  String? get _inputError =>
      _destination.message ?? _routeError ?? _locationMessage;

  String? get _inputHelper {
    if (_destination.busy) return 'Buscando destino…';
    if (_locating) return 'Obtendo sua localização…';
    if (_routing) return 'Calculando rota…';
    final route = _route;
    if (route != null) {
      final distance = (route.distanceMeters / 1000).toStringAsFixed(1);
      final minutes = (route.durationSeconds / 60).ceil();
      return 'Rota: $distance km • $minutes min estimados';
    }
    if (_destination.selected != null && _pickup == null) {
      return 'Destino encontrado. Aguardando sua localização…';
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_locate());
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Native permission dialogs can be inactive; do not treat that as leaving.
    if (_locating &&
        (state == AppLifecycleState.paused ||
            state == AppLifecycleState.hidden ||
            state == AppLifecycleState.detached)) {
      setState(() {
        _locationRevision++;
        _cancelLocation();
        _pickup = null;
        _clearRoute();
        _locationMessage = const CurrentLocationException(
          LocationFailure.cancelled,
        ).message;
      });
    }
  }

  void _cancelLocation() {
    _locationAttempt?.cancel();
    _locationAttempt = null;
    _locating = false;
  }

  void _clearRoute() {
    _routeRevision++;
    _route = null;
    _routing = false;
    _routeError = null;
  }

  Future<void> _locate() async {
    if (!mounted || _locating) return;

    final revision = ++_locationRevision;
    final attempt = LocationAttempt();
    setState(() {
      _cancelLocation();
      _pickup = null;
      _locationMessage = null;
      _locating = true;
      _clearRoute();
    });
    _locationAttempt = attempt;

    bool current() =>
        mounted &&
        _locationRevision == revision &&
        identical(_locationAttempt, attempt);

    try {
      final fix = await _location
          .locate(attempt)
          .timeout(GeolocatorCurrentLocation.deadline);
      if (!current()) return;
      fix.validate(DateTime.now());
      setState(() {
        _pickup = AddressPlace(label: 'Sua localização', point: fix.point);
        _locationMessage = null;
        _locating = false;
        _locationAttempt = null;
      });
      attempt.cancel();
      await _calculateRoute();
    } catch (error) {
      if (!current()) return;
      final failure = error is CurrentLocationException
          ? error
          : CurrentLocationException(
              error is TimeoutException
                  ? LocationFailure.timeout
                  : LocationFailure.unavailable,
            );
      setState(() => _locationMessage = failure.message);
    } finally {
      attempt.cancel();
      if (mounted && identical(_locationAttempt, attempt)) {
        setState(() {
          _locating = false;
          _locationAttempt = null;
        });
      }
    }
  }

  void _invalidateDestination() {
    _destination.revision++;
    _destination.selected = null;
    _destination.message = null;
    _destination.busy = false;
    _clearRoute();
  }

  void _editDestination() => setState(_invalidateDestination);

  Future<void> _searchDestination() async {
    if (_destination.busy) return;

    final query = _destination.controller.text.trim();
    setState(() {
      _invalidateDestination();
      _destination.busy = query.isNotEmpty;
      if (query.isEmpty) {
        _destination.message = 'Digite um destino para buscar.';
      }
    });
    if (query.isEmpty) return;

    if (_pickup == null && !_locating) unawaited(_locate());
    final revision = _destination.revision;
    try {
      final results = await _geocoder.search(query);
      if (!mounted || revision != _destination.revision) return;

      AddressPlace? firstValid;
      for (final result in results) {
        if (validCoordinate(result.point)) {
          firstValid = result;
          break;
        }
      }
      if (firstValid == null) {
        setState(() {
          _destination.message = results.isEmpty
              ? 'Nenhum endereço encontrado. Inclua cidade e número.'
              : 'Nenhum destino com coordenadas válidas foi encontrado.';
        });
        return;
      }

      FocusScope.of(context).unfocus();
      setState(() {
        _destination.selected = firstValid;
        _destination.controller.text = firstValid!.label;
        _destination.message = null;
      });
      await _calculateRoute();
    } catch (error) {
      if (!mounted || revision != _destination.revision) return;
      setState(
        () => _destination.message = error is LocationException
            ? error.message
            : 'Não foi possível buscar. Tente novamente.',
      );
    } finally {
      if (mounted && revision == _destination.revision) {
        setState(() => _destination.busy = false);
      }
    }
  }

  Future<void> _calculateRoute() async {
    if (_routing) return;
    final pickup = _pickup;
    final destination = _destination.selected;
    if (pickup == null || destination == null) return;
    if (pickup.point == destination.point) {
      setState(
        () => _routeError = 'Origem e destino devem ser pontos diferentes.',
      );
      return;
    }

    final revision = ++_routeRevision;
    setState(() {
      _route = null;
      _routing = true;
      _routeError = null;
    });
    try {
      final route = await _router.route(pickup.point, destination.point);
      if (!mounted || revision != _routeRevision) return;
      if (route.points.length < 2 ||
          !route.points.every(validCoordinate) ||
          route.points.every((point) => point == route.points.first)) {
        throw const LocationException(
          'no_route',
          'Nenhuma rota viária válida encontrada.',
        );
      }
      setState(() => _route = route);
    } catch (error) {
      if (!mounted || revision != _routeRevision) return;
      setState(
        () => _routeError = error is LocationException
            ? error.message
            : 'Não foi possível calcular a rota. Tente novamente.',
      );
    } finally {
      if (mounted && revision == _routeRevision) {
        setState(() => _routing = false);
      }
    }
  }

  void _showMapError() {
    if (!mounted || _mapErrorShown) return;
    _mapErrorShown = true;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Não foi possível carregar parte do mapa. Verifique sua conexão.',
        ),
      ),
    );
  }

  void _scheduleDestinationMeasurement() {
    if (_destinationMeasurementScheduled) return;
    _destinationMeasurementScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _destinationMeasurementScheduled = false;
      if (!mounted) return;
      final renderObject = _destinationSurfaceKey.currentContext
          ?.findRenderObject();
      if (renderObject is! RenderBox || !renderObject.hasSize) return;
      final height = renderObject.size.height;
      if ((height - _destinationHeight).abs() <= 0.5) return;
      setState(() => _destinationHeight = height);
    });
  }

  Widget _destinationInput() =>
      NotificationListener<SizeChangedLayoutNotification>(
        onNotification: (_) {
          _scheduleDestinationMeasurement();
          return false;
        },
        child: SizeChangedLayoutNotifier(
          child: Material(
            key: _destinationSurfaceKey,
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(26),
            elevation: 12,
            shadowColor: Colors.black54,
            child: TextField(
              key: const ValueKey('address-1'),
              controller: _destination.controller,
              maxLength: 300,
              textInputAction: TextInputAction.search,
              keyboardType: TextInputType.streetAddress,
              scrollPadding: const EdgeInsets.all(24),
              onChanged: (_) => _editDestination(),
              onSubmitted: (_) => unawaited(_searchDestination()),
              decoration: InputDecoration(
                labelText: 'Destino',
                hintText: 'Rua, número, cidade',
                counterText: '',
                helperText: _inputHelper,
                helperMaxLines: 2,
                errorText: _inputError,
                errorMaxLines: 3,
                prefixIcon: Icon(
                  _route != null
                      ? Icons.check_circle_outline
                      : Icons.location_on_outlined,
                  color: RideTheme.muted,
                  size: 22,
                ),
                suffixIcon: _busy
                    ? const Padding(
                        padding: EdgeInsets.all(14),
                        child: SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : null,
              ),
            ),
          ),
        ),
      );

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _locationRevision++;
    _cancelLocation();
    _destination.controller.dispose();
    if (widget.geocoder == null) (_geocoder as NominatimGeocoder).close();
    if (widget.router == null) (_router as OsrmRouter).close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const overlayMargin = 16.0;
    final safe = MediaQuery.paddingOf(context);
    final keyboard = MediaQuery.viewInsetsOf(context);
    final bottomInset = keyboard.bottom > safe.bottom
        ? keyboard.bottom
        : safe.bottom;
    final inputBottom = bottomInset + overlayMargin;
    final bottomObstruction = inputBottom + _destinationHeight;
    _scheduleDestinationMeasurement();

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        body: Stack(
          children: [
            Positioned.fill(
              child: RideMap(
                pickup: _pickup?.point,
                destination: _destination.selected?.point,
                route: _route,
                tileProvider: widget.tileProvider,
                topObstruction: safe.top,
                bottomObstruction: bottomObstruction,
                onTileError: _showMapError,
              ),
            ),
            Positioned(
              bottom: inputBottom,
              left: safe.left + overlayMargin,
              right: safe.right + overlayMargin,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: _destinationInput(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
