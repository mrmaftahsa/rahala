import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rahala/app/rahala_app.dart';
import 'package:rahala/app/widgets.dart';
import 'package:rahala/core/geography.dart';
import 'package:rahala/core/progress.dart';

import 'test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  WidgetController.hitTestWarningShouldBeFatal = true;

  setUpAll(() async {
    final fonts = FontLoader('NotoSansArabic')
      ..addFont(rootBundle.load('assets/fonts/NotoSansArabic-Medium.ttf'))
      ..addFont(rootBundle.load('assets/fonts/NotoSansArabic-ExtraBold.ttf'));
    await fonts.load();
  });

  testWidgets(
    'RTL home, chapter path, flags, results, capitals and passport at 360 dp',
    (tester) async {
      final catalog = loadCatalog();
      final backend = MemoryProgressBackend();
      await openApp(tester, catalog, backend);

      expect(
        Directionality.of(tester.element(find.text('رحّالة'))),
        TextDirection.rtl,
      );
      await tapText(tester, 'العالم العربي');
      expect(find.text('أكمل المحطة السابقة'), findsOneWidget);
      await tapText(tester, 'خمن العلم');
      expect(find.text('لأيّ دولة هذا العلم؟'), findsOneWidget);

      for (var index = 0; index < 5; index++) {
        await answerFlag(tester, correct: true, last: index == 4);
      }
      expect(find.text('أتممت المحطة!'), findsOneWidget);
      expect(find.text('٥ من ٥ إجابات صحيحة'), findsOneWidget);
      expect(find.text('نقاط الخبرة المكتسبة · ٥٠'), findsOneWidget);
      await tapText(tester, 'المحطة التالية');
      expect(find.text('ما عاصمة هذه الدولة؟'), findsOneWidget);
      expect(find.text('السؤال ١ من ٥'), findsOneWidget);

      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.text('مكتملة · يمكنك إعادتها'), findsOneWidget);
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      await tapText(tester, 'الجواز');
      expect(find.text('٥ من ٣٥ ختمًا'), findsOneWidget);
      expect(find.text('العاصمة · الرباط'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('feedback, mistake review and replay work with enlarged text', (
    tester,
  ) async {
    final catalog = loadCatalog();
    final backend = MemoryProgressBackend();
    await openApp(tester, catalog, backend, textScale: 1.8);

    await tapText(tester, 'ابدأ الرحلة');
    for (var index = 0; index < 5; index++) {
      await answerFlag(tester, correct: false, last: index == 4);
    }
    expect(find.text('جرّب المحطة من جديد'), findsOneWidget);
    expect(find.text('المحطة التالية'), findsNothing);
    await tapText(tester, 'أعد المحطة');

    await answerFlag(tester, correct: true, last: false);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    await tapText(tester, 'مراجعة الأخطاء (٤)');
    for (var index = 0; index < 4; index++) {
      await answerFlag(tester, correct: true, last: index == 3);
    }
    expect(find.text('راجعت كل أخطائك.'), findsOneWidget);
    await tapText(tester, 'إنهاء الجولة');
    expect(find.textContaining('مراجعة الأخطاء'), findsNothing);
    expect(PlayerProgress.decode(backend.snapshot!).xp, 50);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Arabic settings persist and reset requires confirmation', (
    tester,
  ) async {
    final catalog = loadCatalog();
    final backend = MemoryProgressBackend();
    final setup = await GameProgress.open(catalog, backend);
    await setup.recordAnswer(catalog.questions['flag.ma']!, correct: true);
    setup.dispose();
    await openApp(tester, catalog, backend, textScale: 1.8);

    await tapText(tester, 'الإعدادات');
    await tapText(tester, 'المؤثرات الصوتية');
    await tapText(tester, 'تقليل الحركة');

    await tapText(tester, 'إعادة ضبط التقدّم');
    expect(find.text('إعادة ضبط التقدّم؟'), findsOneWidget);
    expect(
      Directionality.of(tester.element(find.byType(AlertDialog))),
      TextDirection.rtl,
    );
    await tapText(tester, 'إلغاء');
    expect(PlayerProgress.decode(backend.snapshot!).xp, 10);

    await tapText(tester, 'إعادة ضبط التقدّم');
    await tapText(tester, 'احذف التقدّم');
    final reset = PlayerProgress.decode(backend.snapshot!);
    expect(reset.xp, 0);
    expect(reset.sound, isFalse);
    expect(reset.reducedMotion, isTrue);

    await tapText(tester, 'المصادر والتراخيص');
    expect(find.textContaining('أرشيف كتاب حقائق العالم'), findsOneWidget);
    await tapText(tester, 'إغلاق');
    await tapText(tester, 'الجواز');
    expect(find.text('ختمك الأول ينتظرك'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Future<void> openApp(
  WidgetTester tester,
  GeographyCatalog catalog,
  MemoryProgressBackend backend, {
  double textScale = 1,
}) async {
  tester.view.physicalSize = const Size(360, 640);
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  await tester.pumpWidget(
    RahalaApp(catalog: catalog, backend: backend, random: Random(5)),
  );
  await tester.pumpAndSettle();
}

Future<void> tapText(WidgetTester tester, String text) async {
  final target = find.text(text).last;
  await tester.ensureVisible(target);
  await tester.pump();
  await tester.tap(target);
  await tester.pumpAndSettle();
}

Future<void> answerFlag(
  WidgetTester tester, {
  required bool correct,
  required bool last,
}) async {
  final flag = tester.widget<CountryFlag>(find.byType(CountryFlag));
  final answer = flag.country.name;
  final choice = correct ? answer : (answer == 'المغرب' ? 'مصر' : 'المغرب');
  // Review distractors can come from any region. Use a visible choice when the
  // preferred incorrect country is outside the four options.
  final fallback = find.byWidgetPredicate(
    (widget) =>
        widget is Semantics &&
        widget.properties.button == true &&
        widget.properties.enabled == true &&
        widget.properties.label != answer,
  );
  final target = find.text(choice).evaluate().isNotEmpty
      ? find.text(choice)
      : fallback.first;
  await tester.ensureVisible(target);
  await tester.pump();
  await tester.tap(target);
  await tester.pumpAndSettle();
  expect(
    find.text(correct ? 'أحسنت! إجابة صحيحة' : 'هذه المرة لم تصب'),
    findsOneWidget,
  );
  expect(find.text('الإجابة الصحيحة هي $answer.'), findsOneWidget);
  await tapText(tester, last ? 'عرض النتيجة' : 'السؤال التالي');
}
