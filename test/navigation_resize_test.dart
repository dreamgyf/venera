import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:venera/components/components.dart';

class _CounterPage extends StatefulWidget {
  const _CounterPage();

  @override
  State<_CounterPage> createState() => _CounterPageState();
}

class _CounterPageState extends State<_CounterPage> {
  int count = 0;

  @override
  Widget build(BuildContext context) => SizedBox.expand(
    key: const ValueKey('page-bounds'),
    child: Center(
      child: TextButton(
        onPressed: () => setState(() => count++),
        child: Text('count: $count'),
      ),
    ),
  );
}

void main() {
  late GlobalKey<NaviPaneState> paneKey;
  late GlobalKey<NavigatorState> navigatorKey;
  late NaviObserver observer;

  setUp(() {
    paneKey = GlobalKey<NaviPaneState>();
    navigatorKey = GlobalKey<NavigatorState>();
    observer = NaviObserver();
  });

  Future<void> pumpPane(
    WidgetTester tester,
    Size size, {
    EdgeInsets padding = EdgeInsets.zero,
    double? constrainedWidth,
  }) async {
    await tester.binding.setSurfaceSize(size);
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(
            size: size,
            padding: padding,
            viewPadding: padding,
          ),
          child: Center(
            child: SizedBox(
              width: constrainedWidth ?? size.width,
              child: NaviPane(
                key: paneKey,
                observer: observer,
                navigatorKey: navigatorKey,
                paneItems: List.generate(
                  6,
                  (i) => PaneItemEntry(
                    label: 'Tab $i',
                    icon: Icons.book_outlined,
                    activeIcon: Icons.book,
                  ),
                ),
                paneActions: [
                  PaneActionEntry(
                    label: 'Settings',
                    icon: Icons.settings,
                    onTap: () {},
                  ),
                ],
                pageBuilder: (_) => const _CounterPage(),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  }

  testWidgets('fold and unfold preserve content state and switch navigation', (
    tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await pumpPane(tester, const Size(390, 700));
    await tester.tap(find.text('count: 0'));
    await tester.pump();
    expect(paneKey.currentState!.controller.value, 0);

    await pumpPane(tester, const Size(820, 700));
    expect(paneKey.currentState!.controller.value, 2);
    expect(find.text('count: 1'), findsOneWidget);
    expect(find.text('Tab 0'), findsNothing);

    await pumpPane(tester, const Size(390, 700));
    expect(paneKey.currentState!.controller.value, 0);
    expect(find.text('count: 1'), findsOneWidget);
    expect(find.text('Tab 0'), findsOneWidget);
  });

  testWidgets('resize preserves a pushed route', (tester) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await pumpPane(tester, const Size(390, 700));
    navigatorKey.currentState!.push(
      MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Text('Comic details')),
      ),
    );
    await tester.pumpAndSettle();
    await pumpPane(tester, const Size(820, 700));
    expect(find.text('Comic details'), findsOneWidget);
    expect(navigatorKey.currentState!.canPop(), isTrue);
    await pumpPane(tester, const Size(390, 700));
    expect(find.text('Comic details'), findsOneWidget);
  });

  testWidgets('portrait side safe areas affect navigation breakpoint', (
    tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await pumpPane(
      tester,
      const Size(680, 900),
      padding: const EdgeInsets.only(left: 48, right: 48),
    );
    expect(paneKey.currentState!.controller.value, 0);
    final bounds = tester.getRect(find.byKey(const ValueKey('page-bounds')));
    expect(bounds.left, 48);
    expect(bounds.right, 632);
  });

  testWidgets('navigation uses available window constraints', (tester) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await pumpPane(tester, const Size(1400, 900), constrainedWidth: 500);
    expect(paneKey.currentState!.controller.value, 0);
  });

  testWidgets('side navigation scrolls in a short window without overflow', (
    tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await pumpPane(
      tester,
      const Size(820, 220),
      padding: const EdgeInsets.only(bottom: 24),
    );
    expect(paneKey.currentState!.controller.value, 2);
    await tester.drag(
      find.byType(SingleChildScrollView),
      const Offset(0, -400),
    );
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.settings).hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
