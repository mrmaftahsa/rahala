import 'package:flutter_test/flutter_test.dart';
import 'package:rahala/core/geography.dart';
import 'package:rahala/core/progress.dart';

import 'test_support.dart';

void main() {
  late GeographyCatalog catalog;
  late MemoryProgressBackend backend;
  late GameProgress progress;
  late Mission first;

  setUp(() async {
    catalog = loadCatalog();
    backend = MemoryProgressBackend();
    progress = await GameProgress.open(catalog, backend);
    first = catalog.missions.first;
  });

  tearDown(() => progress.dispose());

  test(
    'passing opens new routes and world challenge requires the regional path',
    () async {
      final arabCapitals = catalog.missionsIn(Chapter.arab)[1];
      final africa = catalog.missionsIn(Chapter.africa).first;
      final world = catalog.missionsIn(Chapter.world).single;
      expect(progress.nextMission, first);
      expect(progress.isUnlocked(arabCapitals), isFalse);
      expect(progress.isUnlocked(africa), isFalse);
      expect(progress.practiceUnlocked, isFalse);

      await progress.finish(first, const QuizScore(3, 5));
      expect(progress.nextMission, first);
      await progress.finish(first, const QuizScore(4, 5));
      expect(progress.after(first), arabCapitals);
      expect(progress.isUnlocked(africa), isTrue);
      expect(progress.practiceUnlocked, isTrue);
      expect(progress.isUnlocked(world), isFalse);

      for (final mission in catalog.missions.where(
        (mission) => mission != world,
      )) {
        await progress.finish(mission, const QuizScore(5, 5));
      }
      expect(progress.nextMission, world);
      await progress.finish(world, const QuizScore(10, 10));
      expect(progress.nextMission, isNull);
    },
  );

  test(
    'replaying preserves best stars and concurrent mastery pays XP once',
    () async {
      final question = first.questions.first;
      expect(
        await Future.wait(
          List.generate(
            3,
            (_) => progress.recordAnswer(question, correct: true),
          ),
        ),
        [10, 0, 0],
      );
      await progress.finish(first, const QuizScore(5, 5));
      await progress.finish(first, const QuizScore(4, 5));
      await progress.finish(first, const QuizScore(2, 5));
      expect(progress.value.starsFor(first), 3);
      expect(progress.value.xp, 10);
      await progress.recordAnswer(
        catalog.questions['capital.${question.country.id}']!,
        correct: true,
      );
      expect(progress.value.xp, 20);
      expect(progress.value.stamps(catalog), {question.country.id});
    },
  );

  test(
    'mistakes, mastery, stars and preferences survive reopening storage',
    () async {
      final [one, two, ...] = first.questions;
      await progress.recordAnswer(one, correct: false);
      await progress.recordAnswer(one, correct: false);
      await progress.recordAnswer(two, correct: true);
      await progress.finish(first, const QuizScore(4, 5));
      await progress.setPreferences(sound: false, reducedMotion: true);

      final restored = await GameProgress.open(catalog, backend);
      expect(restored.reviewIds, [one.id]);
      expect(restored.value.xp, 10);
      expect(restored.value.starsFor(first), 1);
      expect(restored.value.sound, isFalse);
      expect(restored.value.reducedMotion, isTrue);
      expect(await restored.recordAnswer(one, correct: true), 10);
      expect(restored.reviewIds, isEmpty);
      await restored.recordAnswer(one, correct: false);
      expect(restored.reviewIds, [one.id]);
      expect(await restored.recordAnswer(one, correct: true), 0);
      expect(restored.reviewIds, isEmpty);

      await restored.reset();
      expect(restored.value.xp, 0);
      expect(restored.value.stars, 0);
      expect(restored.value.stamps(catalog), isEmpty);
      expect(restored.practiceUnlocked, isFalse);
      expect(restored.value.sound, isFalse);
      expect(restored.value.reducedMotion, isTrue);
      restored.dispose();
    },
  );

  test(
    'failed writes leave progress intact and the same answer can be retried',
    () async {
      final question = first.questions.first;
      backend.failNextSave = true;
      await expectLater(
        progress.recordAnswer(question, correct: true),
        throwsStateError,
      );
      expect(progress.value.xp, 0);
      expect(backend.snapshot, isNull);
      expect(await progress.recordAnswer(question, correct: true), 10);
      expect(progress.value.xp, 10);
    },
  );

  test('an unsupported saved version is preserved', () async {
    backend.snapshot = '{"version":2}';
    await expectLater(
      GameProgress.open(catalog, backend),
      throwsFormatException,
    );
    expect(backend.snapshot, '{"version":2}');
  });
}
