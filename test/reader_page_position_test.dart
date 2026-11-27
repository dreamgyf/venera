import 'package:flutter_test/flutter_test.dart';
import 'package:venera/pages/reader/page_position.dart';

void main() {
  const single = ReaderPageLayout(imagesPerPage: 1, singleFirstPage: false);
  const spread = ReaderPageLayout(imagesPerPage: 2, singleFirstPage: false);
  const cover = ReaderPageLayout(imagesPerPage: 2, singleFirstPage: true);

  test(
    'folding back restores the same image, including the second in a spread',
    () {
      final position = ReaderPagePosition(image: 10, layout: single);
      expect(position.reflow(spread, imageCount: 30), 5);
      // PageView reports its initial page when the spread layout is mounted.
      position.selectPage(5, imageCount: 30);
      expect(position.image, 10);
      expect(position.reflow(single, imageCount: 30), 10);
    },
  );

  test(
    'repeated resizing retains the anchor across different spread sizes',
    () {
      final position = ReaderPagePosition(image: 11, layout: single);
      expect(position.reflow(cover, imageCount: 30), 6);
      expect(position.reflow(spread, imageCount: 30), 6);
      expect(
        position.reflow(
          const ReaderPageLayout(imagesPerPage: 3, singleFirstPage: false),
          imageCount: 30,
        ),
        4,
      );
      expect(position.reflow(single, imageCount: 30), 11);
    },
  );

  test('turning a spread advances the image restored on folding', () {
    final position = ReaderPagePosition(image: 10, layout: single);
    position.reflow(spread, imageCount: 30);
    position.selectPage(6, imageCount: 30);
    expect(position.reflow(single, imageCount: 30), 11);
  });

  test('changing the cover layout preserves the selected image', () {
    final position = ReaderPagePosition(image: 10, layout: spread);
    expect(position.reflow(cover, imageCount: 30), 6);
    expect(position.reflow(single, imageCount: 30), 10);
  });

  test(
    'resizing while images load does not clamp the reading position to one',
    () {
      final position = ReaderPagePosition(image: 24, layout: single);
      expect(position.reflow(spread), 12);
      expect(position.reflow(single), 24);
      expect(position.reflow(cover, imageCount: 30), 13);
    },
  );

  test('the chapter comments page stays selected across folding', () {
    final position = ReaderPagePosition(image: 30, layout: single);
    position.selectPage(31, imageCount: 30, hasComments: true);
    expect(position.reflow(spread, imageCount: 30, hasComments: true), 16);
    expect(position.reflow(cover, imageCount: 30, hasComments: true), 17);
    expect(position.reflow(single, imageCount: 30, hasComments: true), 31);
  });

  test(
    'hiding comments returns to the final image instead of an invalid page',
    () {
      final position = ReaderPagePosition(image: 30, layout: single);
      position.selectPage(31, imageCount: 30, hasComments: true);
      expect(position.reflow(spread, imageCount: 30), 15);
      expect(position.isOnComments, isFalse);
      expect(position.reflow(single, imageCount: 30), 30);
    },
  );

  test('jumping to the chapter end updates the anchor before folding', () {
    final position = ReaderPagePosition(image: 1, layout: spread);
    position.selectPage(15, imageCount: 30);
    expect(position.reflow(single, imageCount: 30), 29);
  });

  test('short or empty chapters always produce a valid page', () {
    final position = ReaderPagePosition(image: 100, layout: single);
    expect(position.reflow(cover, imageCount: 1), 1);
    expect(position.reflow(spread, imageCount: 0), 1);
    expect(single.pageCount(0), 1);
    expect(cover.pageCount(30), 16);
    expect(spread.pageCount(30), 15);
  });
}
