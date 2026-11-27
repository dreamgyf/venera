import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// A native layout snapshot, expressed in Flutter's logical view coordinates.
@immutable
class DisplayRegionSnapshot {
  final Size size;
  final List<DisplayFeature> features;

  const DisplayRegionSnapshot(this.size, this.features);

  static DisplayRegionSnapshot? fromMessage(Object? message) {
    if (message is! Map) return null;
    final width = _number(message['width']);
    final height = _number(message['height']);
    final regions = message['regions'];
    if (width == null ||
        height == null ||
        width <= 0 ||
        height <= 0 ||
        regions is! List) {
      return null;
    }
    final size = Size(width, height);
    final features = <DisplayFeature>[];
    for (final region in regions) {
      if (region is! Map) continue;
      final kind = region['kind'];
      if (kind != 'division' && kind != 'occlusion') continue;
      final x = _number(region['x']);
      final y = _number(region['y']);
      final w = _number(region['width']);
      final h = _number(region['height']);
      if (x == null ||
          y == null ||
          w == null ||
          h == null ||
          w <= 0 ||
          h <= 0) {
        continue;
      }
      final bounds = Rect.fromLTWH(x, y, w, h).intersect(Offset.zero & size);
      if (bounds.isEmpty) continue;
      features.add(
        DisplayFeature(
          bounds: bounds,
          type: kind == 'division'
              ? DisplayFeatureType.fold
              : DisplayFeatureType.cutout,
          state: kind == 'division'
              ? DisplayFeatureState.postureHalfOpened
              : DisplayFeatureState.unknown,
        ),
      );
    }
    return DisplayRegionSnapshot(size, List.unmodifiable(features));
  }

  /// Discard coordinates from an earlier fold/rotation until the matching
  /// native layout arrives. Subpixel rounding can differ between UIKit/Flutter.
  List<DisplayFeature> merge(MediaQueryData mediaQuery) {
    final result = [...mediaQuery.displayFeatures];
    if ((size.width - mediaQuery.size.width).abs() >= 0.5 ||
        (size.height - mediaQuery.size.height).abs() >= 0.5) {
      return result;
    }
    for (final feature in features) {
      if (!result.any(
        (existing) =>
            existing.bounds == feature.bounds && existing.type == feature.type,
      )) {
        result.add(feature);
      }
    }
    return result;
  }

  static double? _number(Object? value) {
    if (value is! num || !value.isFinite) return null;
    return value.toDouble();
  }
}

/// Adds iOS reserved regions to the inherited MediaQuery for dialogs and other
/// display-feature-aware widgets, without replacing engine-provided features.
class DisplayRegions extends StatefulWidget {
  final Widget child;

  const DisplayRegions({super.key, required this.child});

  @override
  State<DisplayRegions> createState() => _DisplayRegionsState();
}

class _DisplayRegionsState extends State<DisplayRegions> {
  StreamSubscription<dynamic>? _subscription;
  DisplayRegionSnapshot? _snapshot;

  @override
  void initState() {
    super.initState();
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
      _subscribe();
    }
  }

  Future<void> _subscribe() async {
    // EventChannel reports missing-plugin activation through FlutterError,
    // rather than its stream. Probe before subscribing to this optional bridge.
    try {
      final available = await const OptionalMethodChannel(
        'venera/display_regions_support',
      ).invokeMethod<bool>('isAvailable');
      if (!mounted || available != true) return;
      _subscription = const EventChannel('venera/display_regions')
          .receiveBroadcastStream()
          .listen(
            (message) {
              if (!mounted) return;
              setState(
                () => _snapshot = DisplayRegionSnapshot.fromMessage(message),
              );
            },
            onError: (Object error) {
              if (mounted) setState(() => _snapshot = null);
            },
          );
    } on PlatformException {
      // Keep the engine's MediaQuery when the native bridge is unavailable.
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    return MediaQuery(
      data: mediaQuery.copyWith(displayFeatures: _snapshot?.merge(mediaQuery)),
      child: widget.child,
    );
  }
}
