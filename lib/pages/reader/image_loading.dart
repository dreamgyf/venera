import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';

Widget buildReaderImageLoading(BuildContext context, ImageChunkEvent? event) {
  // PhotoView's image wrapper re-resolves its stream on dependency changes.
  // Keep size/theme dependencies in this child so folding cannot reset a
  // loaded wrapper to its loading state while it retains the same stream.
  return _ReaderImageLoading(event: event);
}

class _ReaderImageLoading extends StatelessWidget {
  const _ReaderImageLoading({required this.event});

  final ImageChunkEvent? event;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return PhotoView.customChild(
      childSize: MediaQuery.sizeOf(context),
      initialScale: PhotoViewComputedScale.contained,
      minScale: PhotoViewComputedScale.contained * 1.0,
      maxScale: PhotoViewComputedScale.covered * 10.0,
      backgroundDecoration: BoxDecoration(color: colors.surface),
      child: Center(
        child: SizedBox(
          width: 20.0,
          height: 20.0,
          child: CircularProgressIndicator(
            backgroundColor: colors.surfaceContainerHigh,
            value: event == null || event!.expectedTotalBytes == null
                ? null
                : event!.cumulativeBytesLoaded / event!.expectedTotalBytes!,
          ),
        ),
      ),
    );
  }
}
