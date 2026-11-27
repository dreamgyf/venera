import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photo_view/photo_view.dart';
import 'package:venera/pages/reader/image_loading.dart';

class _DeferredImage extends ImageProvider<_DeferredImage> {
  final frame = Completer<ImageInfo>();
  int loads = 0;

  @override
  Future<_DeferredImage> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture(this);

  @override
  ImageStreamCompleter loadImage(
    _DeferredImage key,
    ImageDecoderCallback decode,
  ) {
    loads++;
    return OneFrameImageStreamCompleter(frame.future);
  }
}

void main() {
  testWidgets('loaded reader image survives folding and theme changes', (
    tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final provider = _DeferredImage();
    final image = await tester.runAsync(
      () => createTestImage(width: 600, height: 900),
    );

    Future<void> pumpReader(Size size, Brightness brightness) async {
      await tester.binding.setSurfaceSize(size);
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(brightness: brightness),
          home: MediaQuery(
            data: MediaQueryData(size: size),
            child: PhotoView(
              imageProvider: provider,
              loadingBuilder: buildReaderImageLoading,
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
    }

    await pumpReader(const Size(820, 700), Brightness.light);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    provider.frame.complete(ImageInfo(image: image!));
    await tester.pump();
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(tester.widget<RawImage>(find.byType(RawImage)).image, isNotNull);

    for (final size in [
      const Size(390, 700),
      const Size(820, 700),
      const Size(700, 820),
    ]) {
      await pumpReader(size, Brightness.light);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(tester.widget<RawImage>(find.byType(RawImage)).image, isNotNull);
      expect(tester.takeException(), isNull);
    }
    await pumpReader(const Size(700, 820), Brightness.dark);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(tester.widget<RawImage>(find.byType(RawImage)).image, isNotNull);
    expect(provider.loads, 1);
    expect(tester.takeException(), isNull);
  });
}
