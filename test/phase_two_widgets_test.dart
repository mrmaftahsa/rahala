import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rahala/app/rahala_app.dart';
import 'package:rahala/app/theme.dart';
import 'package:rahala/core/geography.dart';
import 'package:rahala/core/progress.dart';
import 'package:rahala/core/world_atlas.dart';
import 'package:rahala/features/atlas/world_map.dart';
import 'package:rahala/features/quiz/quiz_page.dart';

import 'test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  WidgetController.hitTestWarningShouldBeFatal = true;
  late GeographyCatalog catalog;
  late WorldAtlas atlas;

  setUpAll(() async {
    catalog = loadWorldCatalog();
    atlas = WorldAtlas.decode(
      File('assets/data/world.v1.json').readAsStringSync(),
    );
    final fonts = FontLoader('NotoSansArabic')
      ..addFont(rootBundle.load('assets/fonts/NotoSansArabic-Medium.ttf'))
      ..addFont(rootBundle.load('assets/fonts/NotoSansArabic-ExtraBold.ttf'));
    await fonts.load();
  });

  testWidgets(
    'Arabic atlas searches within continents and opens tiny state details',
    (tester) async {
      smallScreen(tester);
      await tester.pumpWidget(
        RahalaApp(
          catalog: catalog,
          atlas: atlas,
          backend: MemoryProgressBackend(),
        ),
      );
      await tester.pumpAndSettle();
      await tap(tester, find.text('الأطلس'));
      expect(
        Directionality.of(tester.element(find.byType(WorldMap))),
        TextDirection.rtl,
      );
      await tap(tester, find.byType(DropdownButtonFormField<Chapter>));
      await tap(tester, find.text('أوقيانوسيا').last);

      final search = find.byType(TextField);
      await tester.ensureVisible(search);
      await tester.pumpAndSettle();
      await tester.enterText(search, 'يارين');
      await tester.pumpAndSettle();
      final result = find.text('ناورو');
      await tester.scrollUntilVisible(
        result,
        130,
        scrollable: find.byType(Scrollable).first,
      );
      await tap(tester, result);
      expect(find.text('من جغرافيا الدولة'), findsOneWidget);
      expect(find.text('مقرّ الحكومة'), findsOneWidget);
      expect(find.textContaining('ليس لناورو عاصمة رسمية'), findsOneWidget);
      expect(find.byType(WorldMap), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('passport browses uncollected countries at 360 dp', (
    tester,
  ) async {
    smallScreen(tester);
    final backend = MemoryProgressBackend();
    final progress = await GameProgress.open(catalog, backend);
    await progress.recordAnswer(catalog.questions['flag.ma']!, correct: true);
    progress.dispose();
    await tester.pumpWidget(
      RahalaApp(catalog: catalog, atlas: atlas, backend: backend),
    );
    await tester.pumpAndSettle();
    await tap(tester, find.text('الجواز'));
    expect(find.text('١ من ١٩٥ ختمًا'), findsOneWidget);
    await tap(tester, find.text('أختام متبقّية'));
    expect(find.text('المغرب'), findsNothing);
    final entry = find.text('مصر');
    await tester.scrollUntilVisible(entry, 120);
    expect(entry, findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'map answers, zoom, pan and the accessible location list work at 360 dp',
    (tester) async {
      smallScreen(tester);
      final question = QuizQuestion(catalog.questions['location.jp']!, [
        catalog.countries['jp']!,
        catalog.countries['kr']!,
        catalog.countries['th']!,
        catalog.countries['vn']!,
      ]);
      final progress = await showQuiz(tester, catalog, atlas, question);
      addTearDown(progress.dispose);

      final map = find.byType(WorldMap);
      await tester.ensureVisible(map);
      await tester.pumpAndSettle();
      final viewer = tester.widget<InteractiveViewer>(
        find.byType(InteractiveViewer),
      );
      final camera = viewer.transformationController!;
      await tap(tester, find.byTooltip('تكبير الخريطة'));
      expect(camera.value.getMaxScaleOnAxis(), greaterThan(1));
      final before = camera.value.getTranslation().x;
      await tester.dragFrom(
        tester.getCenter(map) + const Offset(-24, 0),
        const Offset(48, 0),
      );
      await tester.pumpAndSettle();
      expect(camera.value.getTranslation().x, isNot(before));
      await tap(tester, find.byTooltip('إعادة توسيط الخريطة'));

      final rect = tester.getRect(map);
      final unit = math.min(rect.width / 360, rect.height / 180);
      final japan = atlas.countries['jp']!.anchor;
      final scene =
          rect.size.center(Offset.zero) +
          (japan - const Offset(180, 90)) * unit;
      await tester.tapAt(
        rect.topLeft + MatrixUtils.transformPoint(camera.value, scene),
      );
      await tester.pumpAndSettle();
      expect(find.text('الإجابة الصحيحة هي اليابان.'), findsOneWidget);
      expect(progress.value.xp, 10);

      await tap(tester, find.text('عرض النتيجة'));
      expect(find.text('أختام جديدة في جوازك · ١'), findsOneWidget);
      await tap(tester, find.text('أعد الجولة'));
      await tap(tester, find.text('اختيار موقع من القائمة'));
      final alternative = find.byKey(const ValueKey('location-choice-kr'));
      expect(
        find.descendant(
          of: alternative,
          matching: find.textContaining('شرقًا'),
        ),
        findsOneWidget,
      );
      await tap(tester, alternative);
      expect(find.text('هذه المرة لم تصب'), findsOneWidget);
      expect(progress.reviewIds, ['location.jp']);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('outline question uses real boundaries and a useful hint', (
    tester,
  ) async {
    smallScreen(tester, textScale: 1.8);
    final question = QuizQuestion(catalog.questions['outline.nz']!, [
      catalog.countries['au']!,
      catalog.countries['nz']!,
      catalog.countries['ws']!,
      catalog.countries['to']!,
    ]);
    final progress = await showQuiz(tester, catalog, atlas, question);
    addTearDown(progress.dispose);
    expect(find.byType(CountryOutline), findsOneWidget);
    expect(find.text('لأيّ دولة هذا الشكل؟'), findsOneWidget);
    await tap(tester, find.text('تلميح'));
    expect(find.text('تلميح · أستراليا ونيوزيلندا'), findsOneWidget);
    expect(find.text('ساموا'), findsNothing);
    await tap(tester, find.text('نيوزيلندا'));
    expect(find.text('أحسنت! إجابة صحيحة'), findsOneWidget);
    expect(progress.value.mastered, {'outline.nz'});
    expect(tester.takeException(), isNull);
  });
}

void smallScreen(WidgetTester tester, {double textScale = 1.5}) {
  tester.view.physicalSize = const Size(360, 640);
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
}

Future<void> tap(WidgetTester tester, Finder target) async {
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  await tester.tap(target);
  await tester.pumpAndSettle();
}

Future<GameProgress> showQuiz(
  WidgetTester tester,
  GeographyCatalog catalog,
  WorldAtlas atlas,
  QuizQuestion question,
) async {
  final progress = await GameProgress.open(catalog, MemoryProgressBackend());
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      theme: rahalaTheme(),
      home: QuizPage(
        title: question.key.mode.label,
        progress: progress,
        atlas: AtlasSource(initial: atlas),
        makeDeck: () => [question],
        openNext: (_) {},
      ),
    ),
  );
  await tester.pumpAndSettle();
  return progress;
}
