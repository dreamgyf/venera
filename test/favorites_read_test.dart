import 'package:flutter_test/flutter_test.dart';
import 'package:venera/foundation/appdata.dart';
import 'package:venera/foundation/comic_type.dart';
import 'package:venera/foundation/favorites.dart';

void main() {
  test('reading without a follow updates folder does not throw', () {
    final previousFolder = appdata.settings['followUpdatesFolder'];
    addTearDown(() {
      appdata.settings['followUpdatesFolder'] = previousFolder;
    });
    appdata.settings['followUpdatesFolder'] = null;

    expect(
      () => LocalFavoritesManager().markAsRead('local-comic', ComicType.local),
      returnsNormally,
    );
  });
}
