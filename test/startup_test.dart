import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:puppy_ledger/ui/startup_welcome.dart';

void main() {
  Widget scene() => MaterialApp(
    home: StartupWelcome(
      child: Scaffold(
        body: Center(
          child: Builder(
            builder: (context) => TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const Scaffold(body: Text('下一页')),
                ),
              ),
              child: const Text('首页入口'),
            ),
          ),
        ),
      ),
    ),
  );
  testWidgets(
    'greeting keeps approved pair intact, animates once, then enables content',
    (tester) async {
      await tester.pumpWidget(scene());
      expect(find.byKey(const ValueKey('startup-welcome')), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 200));
      final imageFinder = find.byKey(const ValueKey('greeting-dogs'));
      final firstImage = tester.widget<Image>(imageFinder);
      expect(
        firstImage.image,
        const AssetImage('assets/illustrations/puppy_sage.png'),
      );
      expect(firstImage.fit, BoxFit.contain);
      expect(firstImage.gaplessPlayback, isTrue);
      // Identity and the decoded image element stay stable while only its parent
      // transform moves. This prevents another custom redraw of the characters.
      final imageElement = tester.element(imageFinder);
      final first = tester
          .widget<Transform>(find.byKey(const ValueKey('greeting-motion')))
          .transform
          .clone();
      await tester.pump(const Duration(milliseconds: 200));
      final second = tester
          .widget<Transform>(find.byKey(const ValueKey('greeting-motion')))
          .transform;
      expect(second, isNot(equals(first)));
      expect(tester.element(imageFinder), same(imageElement));
      expect(tester.widget<Image>(imageFinder).image, firstImage.image);
      expect(find.text('嗨～'), findsOneWidget);
      expect(find.text('你好呀'), findsOneWidget);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('startup-welcome')), findsNothing);
      await tester.tap(find.text('首页入口'));
      await tester.pumpAndSettle();
      expect(find.text('下一页'), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('startup-welcome')), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('small screen large type greeting fits and can be skipped', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpWidget(scene());
    await tester.pump(const Duration(milliseconds: 200));
    expect(tester.takeException(), isNull);
    await tester.tap(find.byKey(const ValueKey('skip-welcome')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('startup-welcome')), findsNothing);
  });
  testWidgets(
    'reduced motion skips greeting; background cancels it permanently',
    (tester) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      await tester.pumpWidget(scene());
      expect(find.byKey(const ValueKey('startup-welcome')), findsNothing);
      await tester.pumpWidget(const SizedBox());
      tester.platformDispatcher.clearAccessibilityFeaturesTestValue();
      await tester.pumpWidget(scene());
      await tester.pump(const Duration(milliseconds: 100));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('startup-welcome')), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
