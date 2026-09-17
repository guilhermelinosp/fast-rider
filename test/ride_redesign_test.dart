import 'package:fast_rider/theme.dart';
import 'package:fast_rider/widgets/ride_map.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';

import 'address_flow_test.dart';

const removedKeys = [
  'map-service-details',
  'submit-ride',
  'search-1',
  'address-0',
  'ride-sheet',
];

const removedStrings = [
  'Para onde vamos?',
  'FAST / RIDER',
  'Sobre mapas e privacidade',
  'Solicitar corrida',
];

void expectOnlyFloatingInput(WidgetTester tester, Size size) {
  expect(find.byType(AppBar), findsNothing);
  expect(find.byType(TextField), findsOneWidget);
  expect(find.byKey(const ValueKey('address-1')), findsOneWidget);
  for (final key in removedKeys) {
    expect(find.byKey(ValueKey(key)), findsNothing);
  }
  for (final text in removedStrings) {
    expect(find.text(text), findsNothing);
  }
  expect(find.byType(IconButton), findsNothing);
  expect(find.byType(FilledButton), findsNothing);
  expect(find.byType(OutlinedButton), findsNothing);
  expect(find.byType(ExpansionTile), findsNothing);
  expect(find.byType(ListTile), findsNothing);
  expect(
    tester.getRect(find.byType(RideMap)),
    Rect.fromLTWH(0, 0, size.width, size.height),
  );
  expect(find.byKey(const Key('osm_attribution')), findsOneWidget);
}

void expectOnScreen(WidgetTester tester, Finder finder, Size size) {
  final bounds = tester.getRect(finder);
  expect(bounds.left, greaterThanOrEqualTo(0));
  expect(bounds.top, greaterThanOrEqualTo(0));
  expect(bounds.right, lessThanOrEqualTo(size.width));
  expect(bounds.bottom, lessThanOrEqualTo(size.height));
}

void expectBottomLayout(
  WidgetTester tester,
  Size size, {
  required double safeBottom,
  double safeTop = 0,
  double keyboardBottom = 0,
}) {
  final field = tester.getRect(find.byKey(const ValueKey('address-1')));
  final attribution = tester.getRect(
    find.byKey(const Key('osm_attribution_surface')),
  );
  final bottomInset = keyboardBottom > safeBottom ? keyboardBottom : safeBottom;

  expect(
    field.bottom,
    moreOrLessEquals(size.height - bottomInset - 16, epsilon: 1),
  );
  expect(
    attribution.bottom,
    lessThanOrEqualTo(field.top - 8),
    reason: 'Attribution must stay above the destination input',
  );
  expect(
    rideMap(tester).bottomObstruction,
    moreOrLessEquals(size.height - field.top, epsilon: 1),
    reason: 'Camera and attribution must reserve the complete bottom overlay',
  );
  expect(rideMap(tester).topObstruction, safeTop);
}

void main() {
  testWidgets('390x844 is a full-screen graphite map with one floating field', (
    tester,
  ) async {
    const size = Size(390, 844);
    tester.view.padding = FakeViewPadding(
      top: 47 * tester.view.devicePixelRatio,
      bottom: 34 * tester.view.devicePixelRatio,
    );
    addTearDown(tester.view.resetPadding);
    final geocoder = FakeGeocoder();
    await mount(tester, geocoder, FakeRouter(), size: size);

    final theme = Theme.of(tester.element(find.byType(RideMap)));
    expect(theme.brightness, Brightness.dark);
    expect(theme.colorScheme.surface, RideTheme.panel);
    expect(theme.colorScheme.primary, RideTheme.text);
    expectOnlyFloatingInput(tester, size);
    expectOnScreen(tester, find.byKey(const ValueKey('address-1')), size);
    expectOnScreen(tester, find.byKey(const Key('osm_attribution')), size);
    expectBottomLayout(tester, size, safeBottom: 34, safeTop: 47);
    expect(geocoder.queries, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'only OSM tiles are gray; route, markers and attribution are not',
    (tester) async {
      await mount(tester, FakeGeocoder(), FakeRouter());
      await submitDestination(tester, destination.label);

      final filter = find.byKey(const Key('graphite-map-tiles'));
      expect(tester.widget(filter), isA<ColorFiltered>());
      expect(
        find.descendant(of: filter, matching: find.byType(TileLayer)),
        findsOneWidget,
      );
      expect(
        find.descendant(of: filter, matching: find.byType(MarkerLayer)),
        findsNothing,
      );
      expect(
        find.descendant(of: filter, matching: find.byType(PolylineLayer)),
        findsNothing,
      );
      expect(
        find.descendant(
          of: filter,
          matching: find.byKey(const Key('osm_attribution')),
        ),
        findsNothing,
      );
      final tileLayer = tester.widget<TileLayer>(find.byType(TileLayer));
      expect(
        tileLayer.urlTemplate,
        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
      );
      final tileUri = Uri.parse(
        tileLayer.urlTemplate!
            .replaceAll('{z}', '1')
            .replaceAll('{x}', '2')
            .replaceAll('{y}', '3'),
      );
      expect(tileUri.scheme, 'https');
      expect(tileUri.host, 'tile.openstreetmap.org');
      expect(tileUri.queryParameters, isEmpty);
      expect(tileLayer.urlTemplate!.toLowerCase(), isNot(contains('carto')));
      expect(tileLayer.urlTemplate!.toLowerCase(), isNot(contains('api_key')));
      expect(tileLayer.urlTemplate!.toLowerCase(), isNot(contains('apikey')));
      expect(
        tileLayer.tileProvider.headers['User-Agent'],
        'flutter_map (com.guilhermelino.fastrider)',
      );
      final line = tester
          .widget<PolylineLayer>(find.byType(PolylineLayer))
          .polylines
          .single;
      expect(line.color, RideTheme.text);
      expect(line.borderStrokeWidth, greaterThan(0));
      expect(find.text('A'), findsOneWidget);
      expect(find.text('B'), findsOneWidget);
    },
  );

  testWidgets('320x568 at 2x stays above the safe area and an open keyboard', (
    tester,
  ) async {
    const size = Size(320, 568);
    tester.view.padding = FakeViewPadding(
      top: 20 * tester.view.devicePixelRatio,
      bottom: 20 * tester.view.devicePixelRatio,
    );
    addTearDown(tester.view.resetPadding);
    await mount(tester, FakeGeocoder(), FakeRouter(), size: size, textScale: 2);

    expectOnlyFloatingInput(tester, size);
    expectBottomLayout(tester, size, safeBottom: 20, safeTop: 20);

    await tester.tap(find.byKey(const ValueKey('address-1')));
    tester.view.viewInsets = FakeViewPadding(
      bottom: 260 * tester.view.devicePixelRatio,
    );
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpAndSettle();

    expectOnlyFloatingInput(tester, size);
    expectOnScreen(tester, find.byKey(const ValueKey('address-1')), size);
    expectBottomLayout(
      tester,
      size,
      safeBottom: 20,
      safeTop: 20,
      keyboardBottom: 260,
    );
    await submitDestination(tester, destination.label);
    expectBottomLayout(
      tester,
      size,
      safeBottom: 20,
      safeTop: 20,
      keyboardBottom: 260,
    );
    expect(rideMap(tester).destination, destinationPoint);
    expect(rideMap(tester).route, isNotNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('landscape safe area contains the field and attribution', (
    tester,
  ) async {
    const size = Size(844, 390);
    tester.view.padding = FakeViewPadding(
      top: 12 * tester.view.devicePixelRatio,
      left: 44 * tester.view.devicePixelRatio,
      right: 44 * tester.view.devicePixelRatio,
      bottom: 21 * tester.view.devicePixelRatio,
    );
    addTearDown(tester.view.resetPadding);
    await mount(tester, FakeGeocoder(), FakeRouter(), size: size, textScale: 2);

    expectOnlyFloatingInput(tester, size);
    final field = tester.getRect(find.byKey(const ValueKey('address-1')));
    expect(field.left, greaterThanOrEqualTo(60));
    expect(field.right, lessThanOrEqualTo(784));
    expect(field.top, greaterThanOrEqualTo(12));
    final attribution = tester.getRect(
      find.byKey(const Key('osm_attribution')),
    );
    expect(attribution.left, greaterThanOrEqualTo(44));
    expect(attribution.right, lessThanOrEqualTo(800));
    expect(attribution.bottom, lessThanOrEqualTo(369));
    expectBottomLayout(tester, size, safeBottom: 21, safeTop: 12);
    await submitDestination(tester, destination.label);
    expectBottomLayout(tester, size, safeBottom: 21, safeTop: 12);
    expect(rideMap(tester).route, isNotNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('loading and service failures are rendered only by the field', (
    tester,
  ) async {
    final geocoder = FakeGeocoder()
      ..respond = (_) async => throw StateError('offline');
    await mount(tester, geocoder, FakeRouter());

    await submitDestination(tester, 'Destino indisponível');

    expect(
      destinationDecoration(tester).errorText,
      'Não foi possível buscar. Tente novamente.',
    );
    expect(find.byType(TextField), findsOneWidget);
    expect(find.byType(ListTile), findsNothing);
    for (final key in removedKeys) {
      expect(find.byKey(ValueKey(key)), findsNothing);
    }
    expectBottomLayout(tester, const Size(390, 844), safeBottom: 0);
  });

  testWidgets(
    '320x568 tile feedback stays above the input with the keyboard open',
    (tester) async {
      const size = Size(320, 568);
      tester.view.padding = FakeViewPadding(
        top: 20 * tester.view.devicePixelRatio,
        bottom: 20 * tester.view.devicePixelRatio,
      );
      addTearDown(tester.view.resetPadding);
      await mount(
        tester,
        FakeGeocoder(),
        FakeRouter(),
        size: size,
        textScale: 2,
      );

      final field = find.byKey(const ValueKey('address-1'));
      await tester.tap(field);
      tester.view.viewInsets = FakeViewPadding(
        bottom: 260 * tester.view.devicePixelRatio,
      );
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpAndSettle();

      final callback = tester
          .widget<RideMap>(find.byType(RideMap))
          .onTileError!;

      callback();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      final snackBar = find.byType(SnackBar);
      final snackBarSurface = find.descendant(
        of: snackBar,
        matching: find.byType(Material),
      );
      expect(snackBar, findsOneWidget);
      expect(snackBarSurface, findsOneWidget);
      expect(find.textContaining('parte do mapa'), findsOneWidget);
      expect(
        tester.getRect(snackBarSurface).bottom,
        lessThan(tester.getRect(field).top),
      );
      expectOnScreen(tester, field, size);
      expect(field.hitTestable(), findsOneWidget);
      expect(find.byKey(const ValueKey('ride-sheet')), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
