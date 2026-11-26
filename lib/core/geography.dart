import 'dart:convert';
import 'dart:math';

enum QuizMode {
  flag('خمن العلم'),
  capital('عواصم العالم'),
  location('حدد الدولة على الخريطة'),
  outline('خمن الدولة من شكلها');

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
  world('تحدي العالم', 'جولات تجمع مهارات الرحلة كلها');

  const Chapter(this.label, this.description, [this.dataId]);
  final String label;
  final String description;
  final String? dataId;
  String get id => dataId ?? name;

  static Iterable<Chapter> get continents =>
      values.where((chapter) => chapter != arab && chapter != world);
}

enum Difficulty {
  introduction('تمهيد'),
  exploration('استكشاف'),
  mastery('إتقان');

  const Difficulty(this.label);
  final String label;
}

class Country {
  Country._(Map<String, dynamic> json)
    : id = _text(json, 'id'),
      name = _text(json, 'name'),
      capital = _text(json, 'capital'),
      capitalNote = json['capitalNote'] as String?,
      capitalQuiz = json['capitalQuiz'] as bool? ?? true,
      mapQuiz = json['mapQuiz'] as bool? ?? true,
      region = json['region'] as String? ?? '',
      aliases = List.unmodifiable((json['aliases'] as List).cast<String>()),
      continents = Set.unmodifiable(
        (json['continents'] as List).cast<String>(),
      ),
      chapters = Set.unmodifiable((json['chapters'] as List).cast<String>()),
      flag = _text(json, 'flag'),
      fact = _text(json, 'fact'),
      source = _text(json, 'source');

  final String id;
  final String name;
  final String capital;
  final String? capitalNote;
  final bool capitalQuiz;
  final bool mapQuiz;
  final String region;
  final List<String> aliases;
  final Set<String> continents;
  final Set<String> chapters;
  final String flag;
  final String fact;
  final String source;

  bool supports(QuizMode mode) => switch (mode) {
    QuizMode.capital => capitalQuiz,
    QuizMode.location || QuizMode.outline => mapQuiz,
    QuizMode.flag => true,
  };
}

class QuestionKey {
  const QuestionKey(this.country, this.mode);

  final Country country;
  final QuizMode mode;
  String get id => '${mode.name}.${country.id}';
  String get answer =>
      mode == QuizMode.capital ? country.capital : country.name;
}

class Mission {
  Mission._({
    required this.id,
    required this.chapter,
    required this.index,
    required List<QuestionKey> questions,
    required this.difficulty,
    required this.legacy,
    this.name,
  }) : questions = List.unmodifiable(questions);

  final String id;
  final Chapter chapter;
  final int index;
  final List<QuestionKey> questions;
  final Difficulty difficulty;
  final bool legacy;
  final String? name;

  QuizMode? get mode {
    final first = questions.first.mode;
    return questions.every((question) => question.mode == first) ? first : null;
  }

  String get title => name ?? mode?.label ?? 'جولة حول العالم';
  String get format => mode?.label ?? 'جولة متنوّعة';
}

class GeographyCatalog {
  GeographyCatalog._(
    this.schemaVersion,
    this.countries,
    this.paths,
    this.questions,
  ) : missions = List.unmodifiable(paths.values.expand((path) => path));

  factory GeographyCatalog.decode(String source) {
    final json = jsonDecode(source) as Map<String, dynamic>;
    final version = json['schemaVersion'];
    if (version != 1 && version != 2) {
      throw const FormatException('Unsupported geography schema');
    }
    final chapterIds = Chapter.values
        .where((chapter) => chapter != Chapter.world)
        .map((chapter) => chapter.id)
        .toSet();
    final continentIds = Chapter.continents
        .map((chapter) => chapter.id)
        .toSet();
    final countries = <String, Country>{};
    final names = <String>{};
    for (final record in json['countries'] as List) {
      final country = Country._(record as Map<String, dynamic>);
      if (!RegExp(r'^[a-z]{2}$').hasMatch(country.id) ||
          countries.containsKey(country.id) ||
          !names.add(arabicSearchKey(country.name)) ||
          country.flag != 'assets/flags/${country.id}.png' ||
          !RegExp(r'^[a-z-]+/[a-z0-9_-]+\.json$').hasMatch(country.source) ||
          country.chapters.isEmpty ||
          country.continents.isEmpty ||
          !chapterIds.containsAll(country.chapters) ||
          !continentIds.containsAll(country.continents) ||
          country.aliases.any((alias) => alias.trim().isEmpty) ||
          (version == 2 && country.region.isEmpty)) {
        throw FormatException('Invalid country: ${country.id}');
      }
      countries[country.id] = country;
    }
    if (countries.length < 4) {
      throw const FormatException('At least four countries are required');
    }

    final modes = version == 1
        ? [QuizMode.flag, QuizMode.capital]
        : QuizMode.values;
    final questions = <String, QuestionKey>{};
    for (final country in countries.values) {
      for (final mode in modes.where(country.supports)) {
        final key = QuestionKey(country, mode);
        questions[key.id] = key;
      }
    }

    final paths = {for (final chapter in Chapter.values) chapter: <Mission>[]};
    final missionIds = <String>{};
    for (final record in json['missions'] as List) {
      final data = record as Map<String, dynamic>;
      final id = _text(data, 'id');
      final chapter = Chapter.values.firstWhere(
        (chapter) => chapter.id == data['chapter'],
        orElse: () => throw FormatException('Invalid chapter for $id'),
      );
      final keys = <String, QuestionKey>{};
      for (final mode in modes) {
        for (final countryId in (data[mode.name] as List?) ?? const []) {
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
      final path = paths[chapter]!;
      final tier =
          data['difficulty'] as String? ?? Difficulty.introduction.name;
      path.add(
        Mission._(
          id: id,
          chapter: chapter,
          index: path.length,
          questions: keys.values.toList(),
          difficulty: Difficulty.values.byName(tier),
          legacy: version == 1 || data['legacy'] == true,
          name: data['title'] as String?,
        ),
      );
    }
    if (paths.values.any((path) => path.isEmpty)) {
      throw const FormatException('Every chapter needs a mission');
    }
    return GeographyCatalog._(
      version as int,
      Map.unmodifiable(countries),
      Map.unmodifiable(
        paths.map(
          (chapter, missions) =>
              MapEntry(chapter, List<Mission>.unmodifiable(missions)),
        ),
      ),
      Map.unmodifiable(questions),
    );
  }

  final int schemaVersion;
  final Map<String, Country> countries;
  final Map<Chapter, List<Mission>> paths;
  final List<Mission> missions;
  final Map<String, QuestionKey> questions;

  List<Mission> missionsIn(Chapter chapter) => paths[chapter]!;

  Iterable<Country> countriesIn(Chapter chapter) => chapter == Chapter.world
      ? countries.values
      : countries.values.where(
          (country) => country.chapters.contains(chapter.id),
        );
}

String _text(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! String || value.trim().isEmpty) {
    throw FormatException('Missing or empty field: $key');
  }
  return value;
}

String arabicSearchKey(String input) => input
    .replaceAll(RegExp(r'[\u0640\u064b-\u065f\u0670]'), '')
    .replaceAll(RegExp('[أإآٱ]'), 'ا')
    .replaceAll('ى', 'ي')
    .replaceAll('ة', 'ه')
    .trim()
    .toLowerCase();

class QuizQuestion {
  QuizQuestion(this.key, List<Country> options)
    : options = List.unmodifiable(options);

  final QuestionKey key;
  final List<Country> options;
  List<String> get choices => options.map(labelFor).toList(growable: false);

  String labelFor(Country country) => QuestionKey(country, key.mode).answer;
}

class QuizBuilder {
  QuizBuilder(this.catalog, {Random? random}) : _random = random ?? Random();

  final GeographyCatalog catalog;
  final Random _random;

  List<QuizQuestion> mission(Mission mission) =>
      _deck(mission.questions, mission.chapter, mission.difficulty);

  List<QuizQuestion> practice(
    Chapter chapter,
    QuizMode mode, {
    Iterable<String> review = const [],
    Set<String> mastered = const {},
  }) {
    final keys =
        catalog
            .countriesIn(chapter)
            .map((country) => catalog.questions['${mode.name}.${country.id}'])
            .nonNulls
            .toList()
          ..shuffle(_random);
    final priority = {for (final (index, id) in review.indexed) id: index};
    int rank(QuestionKey key) =>
        priority[key.id] ??
        (mastered.contains(key.id) ? priority.length + 1 : priority.length);
    keys.sort((a, b) => rank(a).compareTo(rank(b)));
    return _deck(keys.take(5), chapter, Difficulty.exploration);
  }

  List<QuizQuestion> review(Iterable<String> ids) => _deck(
    ids.toSet().map((id) => catalog.questions[id]).nonNulls.take(10),
    Chapter.world,
    Difficulty.exploration,
  );

  List<QuizQuestion> _deck(
    Iterable<QuestionKey> keys,
    Chapter chapter,
    Difficulty difficulty,
  ) {
    final deck = keys.toList()..shuffle(_random);
    return deck
        .map((key) {
          final preferred = catalog.countriesIn(chapter).toList()
            ..shuffle(_random);
          final sameRegion = preferred.where(
            (country) => country.region == key.country.region,
          );
          final fallback = catalog.countries.values.toList()..shuffle(_random);
          final options = <Country>[key.country];
          final labels = {arabicSearchKey(key.answer)};
          for (final country in [
            if (difficulty == Difficulty.mastery &&
                key.country.region.isNotEmpty)
              ...sameRegion,
            ...preferred,
            ...fallback,
          ]) {
            if (options.length == 4) break;
            if (country.supports(key.mode) &&
                labels.add(
                  arabicSearchKey(QuestionKey(country, key.mode).answer),
                )) {
              options.add(country);
            }
          }
          if (options.length < 4) {
            throw FormatException('Not enough unique choices for ${key.id}');
          }
          return QuizQuestion(key, options..shuffle(_random));
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
