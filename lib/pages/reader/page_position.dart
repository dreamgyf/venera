import 'dart:math' as math;

/// Maps image numbers to spreads without depending on a device's screen size.
class ReaderPageLayout {
  const ReaderPageLayout({
    required this.imagesPerPage,
    required this.singleFirstPage,
  }) : assert(imagesPerPage > 0);

  final int imagesPerPage;
  final bool singleFirstPage;

  int pageForImage(int image) {
    image = math.max(1, image);
    if (singleFirstPage && image > 1) {
      return 2 + (image - 2) ~/ imagesPerPage;
    }
    return 1 + (image - 1) ~/ imagesPerPage;
  }

  int firstImageOnPage(int page) {
    page = math.max(1, page);
    if (singleFirstPage && page > 1) {
      return 2 + (page - 2) * imagesPerPage;
    }
    return 1 + (page - 1) * imagesPerPage;
  }

  int pageCount(int imageCount) => pageForImage(math.max(1, imageCount));

  @override
  bool operator ==(Object other) =>
      other is ReaderPageLayout &&
      imagesPerPage == other.imagesPerPage &&
      singleFirstPage == other.singleFirstPage;

  @override
  int get hashCode => Object.hash(imagesPerPage, singleFirstPage);
}

/// Retains the selected image while folding, resizing, or rotating the reader.
/// A layout change must not replace that image with the start of its spread.
class ReaderPagePosition {
  ReaderPagePosition({required int image, required this.layout})
    : image = math.max(1, image);

  int image;
  ReaderPageLayout layout;
  bool _onComments = false;
  int? _imageCount;

  bool get isOnComments => _onComments;

  int get page => _onComments
      ? layout.pageCount(_imageCount ?? 1) + 1
      : layout.pageForImage(image);

  void selectPage(int page, {int? imageCount, bool hasComments = false}) {
    _imageCount = imageCount;
    if (hasComments &&
        imageCount != null &&
        page > layout.pageCount(imageCount)) {
      image = math.max(1, imageCount);
      _onComments = true;
      return;
    }
    // PageView also reports its initial page after being rebuilt. Keep the
    // image anchor when that callback still refers to the same spread.
    if (_onComments || page != layout.pageForImage(image)) {
      image = layout.firstImageOnPage(page);
    }
    _onComments = false;
  }

  int reflow(
    ReaderPageLayout newLayout, {
    int? imageCount,
    bool hasComments = false,
  }) {
    layout = newLayout;
    _imageCount = imageCount;
    if (imageCount != null) {
      image = image.clamp(1, math.max(1, imageCount));
    }
    _onComments = _onComments && hasComments;
    return page;
  }
}
