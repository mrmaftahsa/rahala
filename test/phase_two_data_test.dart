import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:rahala/core/geography.dart';
import 'package:rahala/core/progress.dart';
import 'package:rahala/core/world_atlas.dart';

import 'test_support.dart';

void main() {
  late GeographyCatalog catalog;
  late WorldAtlas atlas;

  setUpAll(() {
    catalog = loadWorldCatalog();
    atlas = WorldAtlas.decode(
      File('assets/data/world.v1.json').readAsStringSync(),
    );
  });

  test(
    '195 member and observer assets and land shapes are available offline',
    () async {
      expect(catalog.countries, hasLength(195));
      expect(catalog.countries.keys, containsAll(['ps', 'va']));
      expect(
        catalog.countries.keys,
        isNot(contains(anyOf('tw', 'xk', 'eh', 'gl'))),
      );
      expect(catalog.countriesIn(Chapter.arab), hasLength(22));
      expect(atlas.countries.keys, unorderedEquals(catalog.countries.keys));
      for (final country in catalog.countries.values) {
        final feature = atlas.countries[country.id]!;
        expect(feature.bounds.isEmpty, isFalse, reason: country.id);
        expect(feature.outlineBounds.isEmpty, isFalse, reason: country.id);
        expect(
          atlas.hitTest(feature.anchor, allowed: {country.id}),
          country.id,
          reason: 'on-land map anchor for ${country.id}',
        );
        final codec = await ui.instantiateImageCodec(
          File(country.flag).readAsBytesSync(),
        );
        final frame = await codec.getNextFrame();
        expect(frame.image.width, 600, reason: country.id);
        expect(country.fact, matches(RegExp(r'[\u0600-\u06ff]')));
        frame.image.dispose();
        codec.dispose();
      }
    },
  );

  test('small states can be selected and Pacific silhouettes unwrap', () {
    final vatican = atlas.countries['va']!;
    expect(vatican.tiny, isTrue);
    final near = vatican.anchor + const ui.Offset(.1, .1);
    expect(atlas.hitTest(near, allowed: {'it', 'va'}, markerRadius: .2), 'va');
    expect(atlas.hitTest(near, allowed: {'au'}, markerRadius: .2), isNull);
    expect(atlas.countries['fj']!.outlineBounds.width, lessThan(10));
    expect(atlas.countries['nz']!.outlineBounds.width, lessThan(25));
    expect(
      WorldAtlas.extentFor(Chapter.europe).contains(vatican.anchor),
      isTrue,
    );
  });

  test(
    'all four formats have full validated decks across more than 100 levels',
    () {
      final builder = QuizBuilder(catalog, random: Random(68));
      final seen = <String>{};
      final modes = <QuizMode>{};
      expect(catalog.missions.length, greaterThanOrEqualTo(100));
      for (final chapter in Chapter.values) {
        final path = catalog.missionsIn(chapter);
        expect(path.length, greaterThan(2));
        for (final (index, mission) in path.indexed) {
          expect(mission.index, index);
          final deck = builder.mission(mission);
          expect(deck.length, inInclusiveRange(5, 10));
          expect(
            deck.map((question) => question.key.id).toSet(),
            hasLength(deck.length),
          );
          for (final question in deck) {
            modes.add(question.key.mode);
            seen.add(question.key.id);
            expect(question.choices.map(arabicSearchKey).toSet(), hasLength(4));
            expect(
              question.choices.where((choice) => choice == question.key.answer),
              hasLength(1),
            );
            expect(
              question.options.every(
                (country) => country.supports(question.key.mode),
              ),
              isTrue,
            );
          }
        }
      }
      expect(modes, unorderedEquals(QuizMode.values));
      expect(seen, unorderedEquals(catalog.questions.keys));
      expect(catalog.questions, isNot(contains('capital.ps')));
      expect(catalog.questions, isNot(contains('capital.za')));
      expect(catalog.questions, isNot(contains('location.ua')));
      expect(
        catalog.countries['nr']!.capitalNote,
        contains('ليس لناورو عاصمة رسمية'),
      );
      expect(catalog.countries['gq']!.capital, 'سيوداد دي لا باز');
    },
  );

  test('MVP IDs, text answers, and exact mission decks remain stable', () {
    final old = loadCatalog();
    for (final country in old.countries.values) {
      final expanded = catalog.countries[country.id]!;
      expect(expanded.name, country.name);
      expect(expanded.flag, country.flag);
      expect(expanded.chapters, containsAll(country.chapters));
    }
    for (final key in old.questions.values) {
      expect(catalog.questions[key.id]!.answer, key.answer);
    }
    for (final mission in old.missions) {
      final expanded = catalog
          .missionsIn(mission.chapter)
          .singleWhere((m) => m.id == mission.id);
      expect(expanded.legacy, isTrue);
      expect(
        expanded.questions.map((q) => q.id),
        mission.questions.map((q) => q.id),
      );
    }
  });

  test(
    'opening a shipped save keeps XP, old checkpoints, stamps and preferences',
    () async {
      final snapshot = File(
        'test/fixtures/progress-v1.json',
      ).readAsStringSync();
      final backend = MemoryProgressBackend()..snapshot = snapshot;
      final progress = await GameProgress.open(catalog, backend);
      addTearDown(progress.dispose);
      expect(jsonDecode(backend.snapshot!)['version'], 2);
      expect(progress.value.xp, 60);
      expect(progress.value.stars, 7);
      expect(progress.value.sound, isFalse);
      expect(progress.value.reducedMotion, isTrue);
      expect(progress.value.stamps(catalog), {
        'ma',
        'eg',
        'sa',
        'jo',
        'tn',
        'jp',
      });
      expect(progress.reviewIds, unorderedEquals(['flag.tn', 'capital.ma']));
      final discovery = catalog.missionsIn(Chapter.world).first;
      expect(progress.isUnlocked(discovery), isTrue);
      expect(
        progress.isUnlocked(catalog.missionsIn(Chapter.world)[1]),
        isFalse,
      );
      expect(
        await progress.recordAnswer(
          catalog.questions['flag.ma']!,
          correct: true,
        ),
        0,
      );

      final reopened = await GameProgress.open(catalog, backend);
      addTearDown(reopened.dispose);
      expect(reopened.value.xp, 60);
      expect(reopened.value.bestStars, progress.value.bestStars);
    },
  );

  test(
    'failed migration keeps the original saved snapshot available for retry',
    () async {
      final snapshot = File(
        'test/fixtures/progress-v1.json',
      ).readAsStringSync();
      final backend = MemoryProgressBackend()
        ..snapshot = snapshot
        ..failNextSave = true;
      await expectLater(GameProgress.open(catalog, backend), throwsStateError);
      expect(backend.snapshot, snapshot);
      final restored = await GameProgress.open(catalog, backend);
      addTearDown(restored.dispose);
      expect(restored.value.xp, 60);
    },
  );

  test(
    'scheduled repetition advances on due days and prioritizes missed questions',
    () async {
      var time = DateTime.utc(2026, 1, 1, 12);
      final backend = MemoryProgressBackend();
      final progress = await GameProgress.open(
        catalog,
        backend,
        now: () => time,
      );
      addTearDown(progress.dispose);
      final question = catalog.questions['location.jp']!;
      await progress.recordAnswer(question, correct: false);
      await progress.recordAnswer(
        catalog.questions['location.bt']!,
        correct: false,
      );
      await progress.recordAnswer(question, correct: false);
      expect(progress.reviewIds.first, question.id);
      final practice = QuizBuilder(
        catalog,
        random: Random(1),
      ).practice(Chapter.asia, QuizMode.location, review: progress.reviewIds);
      expect(
        practice.map((question) => question.key.id),
        containsAll(progress.reviewIds),
      );
      expect(await progress.recordAnswer(question, correct: true), 10);
      expect(progress.dueReviewIds, isEmpty);
      expect(await progress.recordAnswer(question, correct: true), 0);
      expect(progress.value.review[question.id]!.step, 1);
      time = time.add(const Duration(days: 1));
      expect(progress.dueReviewIds, [question.id]);
      expect(await progress.recordAnswer(question, correct: true), 0);
      expect(progress.value.review[question.id]!.step, 2);
    },
  );

  test(
    'every new level can unlock in order and finish the entire adventure',
    () async {
      final progress = await GameProgress.open(
        catalog,
        MemoryProgressBackend(),
      );
      addTearDown(progress.dispose);
      final completed = <String>{};
      for (
        var mission = progress.nextMission;
        mission != null;
        mission = progress.nextMission
      ) {
        expect(completed.add(mission.id), isTrue);
        await progress.finish(
          mission,
          QuizScore(mission.questions.length, mission.questions.length),
        );
      }
      expect(
        completed,
        unorderedEquals(catalog.missions.map((mission) => mission.id)),
      );
      expect(progress.value.stars, 3 * catalog.missions.length);
    },
  );
}
