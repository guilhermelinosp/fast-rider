import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import 'package:fast_rider/api/location_services.dart';
import 'package:fast_rider/theme.dart';

/// Mapa exclusivamente de exibição: sem zoom, arrasto, rotação ou seleção.
///
/// Mostra os pontos marcados (A origem / B destino) e a rota viária
/// calculada pelo [RoadRouter]. A câmera ajusta automaticamente para
/// enquadrar pontos e rota.
class RideMap extends StatefulWidget {
  const RideMap({
    super.key,
    required this.tileUrl,
    required this.tileUserAgentPackageName,
    this.pickup,
    this.destination,
    this.route,
    this.tileProvider,
    this.bottomObstruction = 0,
    this.topObstruction = 0,
    this.onTileError,
  });

  final String tileUrl;
  final String tileUserAgentPackageName;
  final LatLng? pickup;
  final LatLng? destination;
  final RoadRoute? route;
  final double bottomObstruction;
  final double topObstruction;

  /// Lets a containing page surface a transient notice for tile failures.
  final VoidCallback? onTileError;

  /// Allows offline map tiles in widget tests; production uses OSM tiles.
  final TileProvider? tileProvider;

  @override
  State<RideMap> createState() => _RideMapState();
}

class _RideMapState extends State<RideMap> {
  final MapController _mapController = MapController();
  bool _tileError = false;
  Size? _size;
  double _attributionSpace = 32;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _fitCamera());
  }

  @override
  void didUpdateWidget(RideMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.pickup != widget.pickup ||
        oldWidget.destination != widget.destination ||
        oldWidget.route != widget.route ||
        oldWidget.bottomObstruction != widget.bottomObstruction ||
        oldWidget.topObstruction != widget.topObstruction) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _fitCamera();
      });
    }
  }

  void _fitCamera() {
    final safe = MediaQuery.paddingOf(context);
    final points = <LatLng>[
      if (widget.pickup != null) widget.pickup!,
      if (widget.destination != null) widget.destination!,
      ...?widget.route?.points,
    ];
    if (points.isEmpty) return;
    if (points.every((point) => point == points.first)) {
      try {
        _mapController.move(points.first, 16);
      } catch (_) {
        // The first frame may not have attached the controller yet.
      }
      return;
    }
    final freeHeight =
        (_size?.height ?? 500) -
        widget.bottomObstruction -
        widget.topObstruction -
        _attributionSpace;
    final margin = (freeHeight / 4).clamp(0.0, 32.0);
    try {
      _mapController.fitCamera(
        CameraFit.bounds(
          bounds: LatLngBounds.fromPoints(points),
          padding: EdgeInsets.fromLTRB(
            safe.left + 40,
            widget.topObstruction + margin,
            safe.right + 40,
            widget.bottomObstruction + _attributionSpace + margin,
          ),
          maxZoom: 16,
        ),
      );
    } catch (_) {
      // Mantém a câmera atual se o fit falhar (ex.: primeira montagem).
    }
  }

  void _onTileError() {
    if (_tileError) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_tileError) {
        setState(() => _tileError = true);
        widget.onTileError?.call();
      }
    });
    // Network failures can arrive while the read-only map is idle. Registering
    // a post-frame callback alone does not schedule a frame.
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  Marker _marker(LatLng point, String label, Color color) => Marker(
    point: point,
    width: 44,
    height: 44,
    child: Semantics(
      label: label == 'A' ? 'Ponto A, origem' : 'Ponto B, destino',
      child: Container(
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: RideTheme.text, width: 3),
          boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 8)],
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            color: label == 'A' ? RideTheme.text : RideTheme.panel,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final routePoints = widget.route?.points ?? const <LatLng>[];
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        final safe = MediaQuery.paddingOf(context);
        final attributionSpace = MediaQuery.textScalerOf(context).scale(10) > 16
            ? 44.0
            : 32.0;
        if (size != _size || attributionSpace != _attributionSpace) {
          _size = size;
          _attributionSpace = attributionSpace;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _fitCamera();
          });
        }
        return FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter:
                widget.pickup ?? const LatLng(-23.550520, -46.633308),
            initialZoom: 13,
            minZoom: 1,
            maxZoom: 18,
            backgroundColor: RideTheme.background,
            // Somente leitura: nenhuma interação (sem zoom, arrasto ou toque).
            interactionOptions: const InteractionOptions(
              flags: InteractiveFlag.none,
            ),
          ),
          children: [
            // Inverted luminance affects only map tiles, never route, markers or
            // attribution. Same provider, URLs, cache and attribution obligations.
            ColorFiltered(
              key: const Key('graphite-map-tiles'),
              colorFilter: const ColorFilter.matrix([
                -0.1382,
                -0.4649,
                -0.0469,
                0,
                205,
                -0.1382,
                -0.4649,
                -0.0469,
                0,
                205,
                -0.1382,
                -0.4649,
                -0.0469,
                0,
                205,
                0,
                0,
                0,
                1,
                0,
              ]),
              child: TileLayer(
                urlTemplate: widget.tileUrl,
                userAgentPackageName: widget.tileUserAgentPackageName,
                maxNativeZoom: 18,
                tileProvider: widget.tileProvider,
                errorTileCallback: (_, _, _) => _onTileError(),
              ),
            ),
            if (routePoints.length > 1)
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: routePoints,
                    strokeWidth: 5,
                    color: RideTheme.text,
                    borderColor: RideTheme.panel,
                    borderStrokeWidth: 2,
                  ),
                ],
              ),
            MarkerLayer(
              markers: [
                if (widget.pickup case final point?)
                  _marker(point, 'A', RideTheme.panel),
                if (widget.destination case final point?)
                  _marker(point, 'B', RideTheme.text),
              ],
            ),
            if (_tileError && widget.onTileError == null)
              Align(
                alignment: Alignment.topCenter,
                child: Padding(
                  padding: EdgeInsets.only(
                    top: widget.topObstruction + 4,
                    left: 12,
                    right: 12,
                  ),
                  child: Material(
                    color: RideTheme.panel,
                    borderRadius: BorderRadius.circular(16),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Semantics(
                        liveRegion: true,
                        child: const Text(
                          'Não foi possível carregar parte do mapa. Verifique sua conexão.',
                          style: TextStyle(color: RideTheme.text),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            // Atribuição legível em qualquer tile, obrigatória mesmo sem conexão.
            Align(
              alignment: Alignment.bottomLeft,
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  safe.left + 12,
                  4,
                  safe.right + 12,
                  (widget.bottomObstruction > safe.bottom
                          ? widget.bottomObstruction
                          : safe.bottom) +
                      8,
                ),
                child: Material(
                  key: const Key('osm_attribution_surface'),
                  color: Colors.black.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(4),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 3,
                      vertical: 1,
                    ),
                    child: Text(
                      '© OpenStreetMap contributors · ODbL',
                      key: const Key('osm_attribution'),
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.white.withValues(alpha: 0.85),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
