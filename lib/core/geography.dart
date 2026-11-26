import 'dart:convert';
import 'dart:math';

enum QuizMode {
  flag('خمن العلم'),
  capital('عواصم العالم');

  const QuizMode(this.label);
  final String label;
}

enum Chapter {
  arab('العالم العربي', 'من المحيط إلى الخليج'),
  africa('إفريقيا', 'السهول والمرتفعات'),
  asia('آسيا', 'من الهيمالايا إلى الهادئ'),
  europe('أوروبا', 'جبال وسواحل ومدن'),
  northAmerica('أمريكا الشمالية', 'من القطب إلى الكاريبي', 'north_america'),
  southAmerica('أمريكا الجنوبية', 'من الأنديز إلى الأمازون', 'south_america'),
  oceania('أوقيانوسيا', 'جزر عبر المحيط الهادئ'),
  world('تحدي العالم', 'محطة تجمع الأعلام والعواصم');

  const Chapter(this.label, this.description, [this.dataId]);
  final String label;
  final String description;
  final String? dataId;
  String get id => dataId ?? name;
}

class Country {
  Country._(Map<String, dynamic> json)
    : id = _requiredText(json, 'id'),
      name = _requiredText(json, 'name'),
      capital = _requiredText(json, 'capital'),
      capitalNote = json['capitalNote'] as String?,
      aliases = List.unmodifiable((json['aliases'] as List).cast<String>()),
      continents = Set.unmodifiable(
        (json['continents'] as List).cast<String>(),
      ),
      chapters = Set.unmodifiable((json['chapters'] as List).cast<String>()),
      flag = _requiredText(json, 'flag'),
      fact = _requiredText(json, 'fact'),
      source = _requiredText(json, 'source');

  final String id;
  final String name;
  final String capital;
  final String? capitalNote;
  final List<String> aliases;
  final Set<String> continents;
  final Set<String> chapters;
  final String flag;
  final String fact;
  final String source;
}

class QuestionKey {
  const QuestionKey(this.country, this.mode);

  final Country country;
  final QuizMode mode;
  String get id => '${mode.name}.${country.id}';
  String get answer => switch (mode) {
    QuizMode.flag => country.name,
    QuizMode.capital => country.capital,
  };
}

class Mission {
  Mission._(this.id, this.chapter, List<QuestionKey> questions)
    : questions = List.unmodifiable(questions);

  final String id;
  final Chapter chapter;
  final List<QuestionKey> questions;

  QuizMode? get mode {
    final first = questions.first.mode;
    return questions.every((question) => question.mode == first) ? first : null;
  }

  String get title => mode?.label ?? 'جولة حول العالم';
}

class GeographyCatalog {
  GeographyCatalog._(this.countries, this.missions, this.questions);

  factory GeographyCatalog.decode(String source) {
    final json = jsonDecode(source) as Map<String, dynamic>;
    if (json['schemaVersion'] != 1) {
      throw const FormatException('Unsupported geography schema');
    }
    final validChapters = Chapter.values.where(
      (chapter) => chapter != Chapter.world,
    );
    final chapterIds = validChapters.map((chapter) => chapter.id).toSet();
    final continentIds = chapterIds.difference({Chapter.arab.id});
    final countries = <String, Country>{};
    final names = <String>{};
    for (final record in json['countries'] as List) {
      final country = Country._(record as Map<String, dynamic>);
      if (!RegExp(r'^[a-z]{2}$').hasMatch(country.id) ||
          countries.containsKey(country.id) ||
          !names.add(country.name) ||
          country.flag != 'assets/flags/${country.id}.png' ||
          !RegExp(r'^[a-z-]+/[a-z]{2}\.json$').hasMatch(country.source) ||
          country.chapters.isEmpty ||
          country.continents.isEmpty ||
          !chapterIds.containsAll(country.chapters) ||
          !continentIds.containsAll(country.continents) ||
          country.aliases.any((alias) => alias.trim().isEmpty)) {
        throw FormatException('Invalid country: ${country.id}');
      }
      countries[country.id] = country;
    }
    if (countries.length < 4) {
      throw const FormatException('At least four countries are required');
    }

    final questions = <String, QuestionKey>{};
    for (final country in countries.values) {
      for (final mode in QuizMode.values) {
        final key = QuestionKey(country, mode);
        questions[key.id] = key;
      }
    }
    final missions = <Mission>[];
    final missionIds = <String>{};
    for (final record in json['missions'] as List) {
      final data = record as Map<String, dynamic>;
      final id = _requiredText(data, 'id');
      final chapter = Chapter.values.firstWhere(
        (chapter) => chapter.id == data['chapter'],
        orElse: () => throw FormatException('Invalid chapter for $id'),
      );
      final keys = <String, QuestionKey>{};
      for (final mode in QuizMode.values) {
        final countryIds = (data[mode.name] as List?) ?? const [];
        for (final countryId in countryIds) {
          final question = questions['${mode.name}.$countryId'];
          if (question == null ||
              keys.containsKey(question.id) ||
              (chapter != Chapter.world &&
                  !question.country.chapters.contains(chapter.id))) {
            throw FormatException('Invalid mission question: $id/$countryId');
          }
          keys[question.id] = question;
        }
      }
      if (!id.startsWith('${chapter.id}.') ||
          !missionIds.add(id) ||
          keys.length < 5 ||
          keys.length > 10) {
        throw FormatException('Invalid mission: $id');
      }
      missions.add(Mission._(id, chapter, keys.values.toList()));
    }
    if (Chapter.values.any(
      (chapter) => !missions.any((mission) => mission.chapter == chapter),
    )) {
      throw const FormatException('Every chapter needs a mission');
    }
    return GeographyCatalog._(
      Map.unmodifiable(countries),
      List.unmodifiable(missions),
      Map.unmodifiable(questions),
    );
  }

  final Map<String, Country> countries;
  final List<Mission> missions;
  final Map<String, QuestionKey> questions;

  List<Mission> missionsIn(Chapter chapter) =>
      missions.where((mission) => mission.chapter == chapter).toList();

  Iterable<Country> countriesIn(Chapter chapter) => chapter == Chapter.world
      ? countries.values
      : countries.values.where(
          (country) => country.chapters.contains(chapter.id),
        );
}

String _requiredText(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! String || value.trim().isEmpty) {
    throw FormatException('Missing or empty field: $key');
  }
  return value;
}

class QuizQuestion {
  QuizQuestion(this.key, List<String> choices)
    : choices = List.unmodifiable(choices);

  final QuestionKey key;
  final List<String> choices;
}

class QuizBuilder {
  QuizBuilder(this.catalog, {Random? random}) : _random = random ?? Random();

  final GeographyCatalog catalog;
  final Random _random;

  List<QuizQuestion> mission(Mission mission) =>
      _deck(mission.questions, mission.chapter);

  List<QuizQuestion> practice(Chapter chapter, QuizMode mode) {
    final keys =
        catalog
            .countriesIn(chapter)
            .map((country) => catalog.questions['${mode.name}.${country.id}']!)
            .toList()
          ..shuffle(_random);
    return _deck(keys.take(5), chapter);
  }

  List<QuizQuestion> review(Iterable<String> ids) {
    final keys = ids.map((id) => catalog.questions[id]).nonNulls.toList()
      ..shuffle(_random);
    return _deck(keys.take(10), Chapter.world);
  }

  List<QuizQuestion> _deck(Iterable<QuestionKey> keys, Chapter chapter) {
    final deck = keys.toList()..shuffle(_random);
    return deck
        .map((key) {
          final preferred = catalog.countriesIn(chapter).toList()
            ..shuffle(_random);
          final fallback = catalog.countries.values.toList()..shuffle(_random);
          final options = <String>{key.answer};
          for (final country in [...preferred, ...fallback]) {
            if (options.length == 4) break;
            options.add(QuestionKey(country, key.mode).answer);
          }
          if (options.length < 4) {
            throw FormatException('Not enough unique choices for ${key.id}');
          }
          return QuizQuestion(key, options.toList()..shuffle(_random));
        })
        .toList(growable: false);
  }
}

class QuizScore {
  const QuizScore(this.correct, this.total)
    : assert(total > 0),
      assert(correct >= 0 && correct <= total);

  final int correct;
  final int total;

  int get stars {
    if (correct == total) return 3;
    if (correct * 10 >= total * 9) return 2;
    if (correct * 5 >= total * 4) return 1;
    return 0;
  }
}
