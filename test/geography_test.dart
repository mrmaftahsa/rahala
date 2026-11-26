import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:rahala/core/geography.dart';

import 'test_support.dart';

void main() {
  late GeographyCatalog catalog;

  setUp(() => catalog = loadCatalog());

  test(
    'bundled catalog has provenance, unique IDs and decodable original-ratio flags',
    () async {
      expect(catalog.countries.length, greaterThanOrEqualTo(30));
      expect(catalog.missions.length, greaterThanOrEqualTo(12));
      expect(
        catalog.countries.values
            .expand((country) => country.continents)
            .toSet()
            .length,
        6,
      );

      for (final country in catalog.countries.values) {
        expect(country.fact, matches(RegExp(r'[\u0600-\u06ff]')));
        expect(country.source, endsWith('.json'));
        final codec = await ui.instantiateImageCodec(
          File(country.flag).readAsBytesSync(),
        );
        final frame = await codec.getNextFrame();
        expect(frame.image.width, 600, reason: country.id);
        expect(frame.image.height, greaterThan(0));
        frame.image.dispose();
        codec.dispose();
      }
    },
  );

  test(
    'each question has four distinct choices of the right type and one answer',
    () {
      final quiz = QuizBuilder(catalog, random: Random(42));
      final covered = <String>{};
      for (final mission in catalog.missions) {
        final deck = quiz.mission(mission);
        expect(deck.length, mission.questions.length);
        expect(
          deck.map((question) => question.key.id),
          unorderedEquals(mission.questions.map((key) => key.id)),
        );
        for (final question in deck) {
          final key = question.key;
          covered.add(key.id);
          expect(question.choices.toSet().length, 4);
          expect(
            question.choices.where((choice) => choice == key.answer),
            hasLength(1),
          );
          for (final choice in question.choices) {
            expect(
              catalog.countries.values.any(
                (country) => QuestionKey(country, key.mode).answer == choice,
              ),
              isTrue,
            );
          }
        }
      }
      expect(covered, unorderedEquals(catalog.questions.keys));
      expect(catalog.missionsIn(Chapter.world).single.questions, hasLength(10));
    },
  );

  test('shuffling is reproducible with an injected random source', () {
    List<Object> snapshot(int seed) =>
        QuizBuilder(catalog, random: Random(seed))
            .mission(catalog.missions.first)
            .map((question) => [question.key.id, ...question.choices])
            .toList();
    expect(snapshot(77), snapshot(77));
    expect(snapshot(77), isNot(snapshot(88)));
  });

  test('targeted practice and mistake review keep stable question IDs', () {
    final quiz = QuizBuilder(catalog, random: Random(30));
    final practice = quiz.practice(Chapter.oceania, QuizMode.capital);
    expect(practice, hasLength(5));
    expect(
      practice.every(
        (question) =>
            question.key.mode == QuizMode.capital &&
            question.key.country.chapters.contains(Chapter.oceania.id),
      ),
      isTrue,
    );
    final review = quiz.review(['flag.ma', 'capital.jp', 'unknown']);
    expect(
      review.map((question) => question.key.id),
      unorderedEquals(['flag.ma', 'capital.jp']),
    );
  });

  test(
    'catalog rejects duplicate, out-of-chapter and unknown mission questions',
    () {
      for (final invalidId in ['ma', 'jp', 'xx']) {
        final json =
            jsonDecode(
                  File('test/fixtures/geography.v1.json').readAsStringSync(),
                )
                as Map<String, dynamic>;
        final countries = (json['missions'] as List).first['flag'] as List;
        countries[1] = invalidId;
        expect(
          () => GeographyCatalog.decode(jsonEncode(json)),
          throwsFormatException,
        );
      }
    },
  );

  test(
    '80, 90 and 100 percent star thresholds round up to whole questions',
    () {
      expect(const QuizScore(3, 5).stars, 0);
      expect(const QuizScore(4, 5).stars, 1);
      expect(const QuizScore(5, 5).stars, 3);
      expect(const QuizScore(7, 10).stars, 0);
      expect(const QuizScore(8, 10).stars, 1);
      expect(const QuizScore(9, 10).stars, 2);
      expect(const QuizScore(10, 10).stars, 3);
      expect(const QuizScore(4, 6).stars, 0);
      expect(const QuizScore(5, 6).stars, 1);
    },
  );
}
