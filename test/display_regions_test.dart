import 'dart:ui';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:venera/components/display_regions.dart';

Map<String, Object> snapshot({
  double width = 900,
  double height = 600,
  List<Object>? regions,
}) => {
  'width': width,
  'height': height,
  'regions':
      regions ??
      [
        {'kind': 'division', 'x': 430, 'y': 0, 'width': 40, 'height': 600},
      ],
};

void main() {
  const engineFeature = DisplayFeature(
    bounds: Rect.fromLTWH(0, 0, 30, 20),
    type: DisplayFeatureType.cutout,
    state: DisplayFeatureState.unknown,
  );
  const mediaQuery = MediaQueryData(
    size: Size(900, 600),
    displayFeatures: [engineFeature],
  );

  test('maps divisions and clips occlusions to the view without scaling', () {
    final value = DisplayRegionSnapshot.fromMessage(
      snapshot(
        regions: [
          {'kind': 'division', 'x': 430, 'y': 0, 'width': 40, 'height': 600},
          {'kind': 'occlusion', 'x': -10, 'y': 10, 'width': 40, 'height': 20},
        ],
      ),
    )!;
    expect(value.features[0].type, DisplayFeatureType.fold);
    expect(value.features[0].state, DisplayFeatureState.postureHalfOpened);
    expect(value.features[0].bounds, const Rect.fromLTWH(430, 0, 40, 600));
    expect(value.features[1].type, DisplayFeatureType.cutout);
    expect(value.features[1].state, DisplayFeatureState.unknown);
    expect(value.features[1].bounds, const Rect.fromLTWH(0, 10, 30, 20));
  });

  test('rejects invalid snapshots and skips malformed or empty regions', () {
    expect(DisplayRegionSnapshot.fromMessage(null), isNull);
    expect(
      DisplayRegionSnapshot.fromMessage(snapshot(width: double.nan)),
      isNull,
    );
    expect(DisplayRegionSnapshot.fromMessage(snapshot(height: 0)), isNull);
    final value = DisplayRegionSnapshot.fromMessage(
      snapshot(
        regions: [
          'invalid',
          {'kind': 'other', 'x': 0, 'y': 0, 'width': 40, 'height': 600},
          {'kind': 'division', 'x': 430, 'y': 0, 'width': 0, 'height': 600},
          {
            'kind': 'division',
            'x': double.infinity,
            'y': 0,
            'width': 40,
            'height': 600,
          },
          {'kind': 'occlusion', 'x': 950, 'y': 0, 'width': 40, 'height': 20},
        ],
      ),
    )!;
    expect(value.features, isEmpty);
  });

  test('keeps engine features and avoids duplicate native regions', () {
    final value = DisplayRegionSnapshot.fromMessage(
      snapshot(
        regions: [
          {'kind': 'occlusion', 'x': 0, 'y': 0, 'width': 30, 'height': 20},
          {'kind': 'division', 'x': 430, 'y': 0, 'width': 40, 'height': 600},
          {'kind': 'division', 'x': 430, 'y': 0, 'width': 40, 'height': 600},
        ],
      ),
    )!;
    final features = value.merge(mediaQuery);
    expect(features, hasLength(2));
    expect(identical(features.first, engineFeature), isTrue);
  });

  test('ignores stale width or height after folding or rotating', () {
    final value = DisplayRegionSnapshot.fromMessage(snapshot())!;
    expect(value.merge(mediaQuery.copyWith(size: const Size(450, 600))), [
      engineFeature,
    ]);
    expect(value.merge(mediaQuery.copyWith(size: const Size(900, 300))), [
      engineFeature,
    ]);
    expect(
      value.merge(mediaQuery.copyWith(size: const Size(900.1, 600.1))),
      hasLength(2),
    );
  });

  test(
    'an unfolded snapshot removes native features but keeps engine features',
    () {
      final value = DisplayRegionSnapshot.fromMessage(snapshot(regions: []))!;
      expect(value.merge(mediaQuery), [engineFeature]);
    },
  );

  testWidgets(
    'updates MediaQuery, drops stale frames, handles errors and cancels',
    (tester) async {
      final messenger = tester.binding.defaultBinaryMessenger;
      const support = MethodChannel('venera/display_regions_support');
      const events = MethodChannel('venera/display_regions');
      final calls = <String>[];
      messenger.setMockMethodCallHandler(support, (_) async => true);
      messenger.setMockMethodCallHandler(events, (call) async {
        calls.add(call.method);
        return null;
      });
      addTearDown(() {
        messenger.setMockMethodCallHandler(support, null);
        messenger.setMockMethodCallHandler(events, null);
      });
      late MediaQueryData observed;
      Widget host(MediaQueryData data) => MediaQuery(
        data: data,
        child: DisplayRegions(
          child: Builder(
            builder: (context) {
              observed = MediaQuery.of(context);
              return const SizedBox();
            },
          ),
        ),
      );
      void send(ByteData? data) =>
          tester.binding.channelBuffers.push(events.name, data, (_) {});
      const codec = StandardMethodCodec();

      await tester.pumpWidget(host(mediaQuery));
      await tester.pump();
      expect(calls, ['listen']);
      send(codec.encodeSuccessEnvelope(snapshot()));
      await tester.pumpAndSettle();
      expect(observed.displayFeatures, hasLength(2));

      await tester.pumpWidget(
        host(mediaQuery.copyWith(size: const Size(450, 600))),
      );
      expect(observed.displayFeatures, [engineFeature]);
      send(codec.encodeSuccessEnvelope(snapshot(width: 450, regions: [])));
      await tester.pumpAndSettle();
      expect(observed.displayFeatures, [engineFeature]);

      send(codec.encodeErrorEnvelope(code: 'unavailable'));
      await tester.pumpAndSettle();
      expect(observed.displayFeatures, [engineFeature]);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      expect(calls, ['listen', 'cancel']);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );

  testWidgets(
    'an absent native bridge leaves the engine MediaQuery intact',
    (tester) async {
      late MediaQueryData observed;
      await tester.pumpWidget(
        MediaQuery(
          data: mediaQuery,
          child: DisplayRegions(
            child: Builder(
              builder: (context) {
                observed = MediaQuery.of(context);
                return const SizedBox();
              },
            ),
          ),
        ),
      );
      await tester.pump();
      expect(observed.displayFeatures, [engineFeature]);
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );
}
