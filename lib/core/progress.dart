import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'geography.dart';

abstract interface class ProgressBackend {
  Future<String?> load();
  Future<void> save(String snapshot);
}

class DeviceProgressBackend implements ProgressBackend {
  DeviceProgressBackend() : _preferences = SharedPreferencesAsync();

  static const _key = 'rahala_progress';
  final SharedPreferencesAsync _preferences;

  @override
  Future<String?> load() => _preferences.getString(_key);

  @override
  Future<void> save(String snapshot) => _preferences.setString(_key, snapshot);
}

class ReviewMemory {
  const ReviewMemory({
    required this.misses,
    required this.step,
    required this.dueDay,
  });

  factory ReviewMemory.decode(Object? data) {
    if (data is! List ||
        data.length != 3 ||
        data.any((entry) => entry is! int || entry < 0) ||
        (data[1] as int) > intervals.length) {
      throw const FormatException('Invalid review schedule');
    }
    return ReviewMemory(
      misses: data[0] as int,
      step: data[1] as int,
      dueDay: data[2] as int,
    );
  }

  static const intervals = [1, 3, 7, 14, 30];

  final int misses;
  final int step;
  final int dueDay;

  List<int> encode() => [misses, step, dueDay];

  ReviewMemory advance(int day) {
    final index = step.clamp(0, intervals.length - 1);
    return ReviewMemory(
      misses: misses,
      step: index + 1,
      dueDay: day + intervals[index],
    );
  }
}

class PlayerProgress {
  PlayerProgress({
    Set<String> mastered = const {},
    Set<String> mistakes = const {},
    Map<String, int> bestStars = const {},
    Map<String, ReviewMemory> review = const {},
    this.sound = true,
    this.reducedMotion = false,
  }) : mastered = Set.unmodifiable(mastered),
       mistakes = Set.unmodifiable(mistakes),
       bestStars = Map.unmodifiable(bestStars),
       review = Map.unmodifiable(review);

  factory PlayerProgress.decode(String snapshot) {
    final json = jsonDecode(snapshot) as Map<String, dynamic>;
    final version = json['version'];
    if ((version != 1 && version != 2) ||
        (version == 2 && json['review'] is! Map<String, dynamic>)) {
      throw const FormatException('Unsupported progress schema');
    }
    return PlayerProgress._fromJson(json);
  }

  factory PlayerProgress._fromJson(Map<String, dynamic> json) {
    final stars = (json['bestStars'] as Map<String, dynamic>)
        .cast<String, int>();
    if (stars.values.any((count) => count < 1 || count > 3)) {
      throw const FormatException('Invalid mission stars');
    }
    return PlayerProgress(
      mastered: (json['mastered'] as List).cast<String>().toSet(),
      mistakes: (json['mistakes'] as List).cast<String>().toSet(),
      bestStars: stars,
      review: json['version'] == 1
          ? {}
          : (json['review'] as Map<String, dynamic>).map(
              (id, data) => MapEntry(id, ReviewMemory.decode(data)),
            ),
      sound: json['sound'] as bool,
      reducedMotion: json['reducedMotion'] as bool,
    );
  }

  final Set<String> mastered;
  final Set<String> mistakes;
  final Map<String, int> bestStars;
  final Map<String, ReviewMemory> review;
  final bool sound;
  final bool reducedMotion;

  int get xp => mastered.length * 10;
  int get stars => bestStars.values.fold(0, (total, value) => total + value);

  int starsFor(Mission mission) => bestStars[mission.id] ?? 0;

  Set<String> stamps(GeographyCatalog catalog) =>
      mastered.map((id) => catalog.questions[id]?.country.id).nonNulls.toSet();

  String encode() => jsonEncode({
    'version': 2,
    'mastered': mastered.toList()..sort(),
    'mistakes': mistakes.toList()..sort(),
    'bestStars': bestStars,
    'review': review.map((id, memory) => MapEntry(id, memory.encode())),
    'sound': sound,
    'reducedMotion': reducedMotion,
  });

  PlayerProgress copyWith({
    Set<String>? mastered,
    Set<String>? mistakes,
    Map<String, int>? bestStars,
    Map<String, ReviewMemory>? review,
    bool? sound,
    bool? reducedMotion,
  }) => PlayerProgress(
    mastered: mastered ?? this.mastered,
    mistakes: mistakes ?? this.mistakes,
    bestStars: bestStars ?? this.bestStars,
    review: review ?? this.review,
    sound: sound ?? this.sound,
    reducedMotion: reducedMotion ?? this.reducedMotion,
  );
}

class GameProgress extends ChangeNotifier {
  GameProgress._(this.catalog, this._backend, this._value, this._now);

  static Future<GameProgress> open(
    GeographyCatalog catalog,
    ProgressBackend backend, {
    DateTime Function()? now,
  }) async {
    final snapshot = await backend.load();
    if (snapshot == null) {
      return GameProgress._(
        catalog,
        backend,
        PlayerProgress(),
        now ?? DateTime.now,
      );
    }
    final value = PlayerProgress.decode(snapshot);
    if ((jsonDecode(snapshot) as Map<String, dynamic>)['version'] == 1) {
      await backend.save(value.encode());
    }
    return GameProgress._(catalog, backend, value, now ?? DateTime.now);
  }

  final GeographyCatalog catalog;
  final ProgressBackend _backend;
  final DateTime Function() _now;
  PlayerProgress _value;
  Future<void> _pending = Future.value();

  PlayerProgress get value => _value;

  bool get practiceUnlocked =>
      _value.starsFor(catalog.missionsIn(Chapter.arab).first) > 0;

  bool get regionalPathsComplete => catalog.missions
      .where((mission) => mission.chapter != Chapter.world)
      .every((mission) => _value.starsFor(mission) > 0);

  bool isUnlocked(Mission mission) {
    final path = catalog.missionsIn(mission.chapter);
    final index = mission.index;
    if (index >= path.length || path[index] != mission) return false;
    if (_value.starsFor(mission) > 0) return true;
    if (index > 0) {
      return _value.starsFor(path[index - 1]) > 0 &&
          (mission.chapter != Chapter.world || regionalPathsComplete);
    }
    return switch (mission.chapter) {
      Chapter.arab => true,
      Chapter.world =>
        catalog.missions
            .where(
              (mission) => mission.chapter != Chapter.world && mission.legacy,
            )
            .every((mission) => _value.starsFor(mission) > 0),
      _ => practiceUnlocked,
    };
  }

  Mission? get nextMission {
    final available = catalog.missions.where(
      (mission) => isUnlocked(mission) && _value.starsFor(mission) == 0,
    );
    if (catalog.schemaVersion == 1) return available.firstOrNull;

    // Open nearby stages across the atlas before recommending the longest path.
    Mission? next;
    for (final mission in available) {
      if (next == null ||
          (mission.chapter != Chapter.world &&
              (next.chapter == Chapter.world || mission.index < next.index))) {
        next = mission;
      }
    }
    return next;
  }

  Mission? after(Mission mission) {
    final path = catalog.missionsIn(mission.chapter);
    final index = mission.index + 1;
    if (index < path.length && isUnlocked(path[index])) return path[index];
    return nextMission;
  }

  int get _day =>
      _now().toUtc().millisecondsSinceEpoch ~/ Duration.millisecondsPerDay;

  List<String> get reviewIds {
    final ids = _value.mistakes.where(catalog.questions.containsKey).toList();
    ids.sort(
      (a, b) => (_value.review[b]?.misses ?? 0).compareTo(
        _value.review[a]?.misses ?? 0,
      ),
    );
    return ids;
  }

  List<String> get dueReviewIds {
    final day = _day;
    final due =
        _value.review.entries
            .where(
              (entry) =>
                  entry.value.dueDay <= day &&
                  !_value.mistakes.contains(entry.key) &&
                  catalog.questions.containsKey(entry.key),
            )
            .toList()
          ..sort((a, b) => a.value.dueDay.compareTo(b.value.dueDay));
    return due.map((entry) => entry.key).toList();
  }

  Future<int> recordAnswer(QuestionKey question, {required bool correct}) =>
      _serialize(() async {
        if (!catalog.questions.containsKey(question.id)) {
          throw ArgumentError.value(question.id, 'question');
        }
        final id = question.id;
        final isNew = correct && !_value.mastered.contains(id);
        final mistakes = {..._value.mistakes};
        final schedule = {..._value.review};
        final previous = schedule[id];
        final day = _day;
        if (!correct) {
          mistakes.add(id);
          schedule[id] = ReviewMemory(
            misses: (previous?.misses ?? 0) + 1,
            step: 0,
            dueDay: day,
          );
        } else {
          final wasMistake = mistakes.remove(id);
          if (wasMistake || (previous != null && previous.dueDay <= day)) {
            schedule[id] =
                (previous ?? ReviewMemory(misses: 1, step: 0, dueDay: day))
                    .advance(day);
          }
        }
        if (isNew || !correct || schedule[id] != previous) {
          await _save(
            _value.copyWith(
              mastered: isNew ? {..._value.mastered, id} : null,
              mistakes: mistakes,
              review: schedule,
            ),
          );
        }
        return isNew ? 10 : 0;
      });

  Future<void> finish(Mission mission, QuizScore score) => _serialize(() async {
    if (!isUnlocked(mission) || score.total != mission.questions.length) {
      throw ArgumentError.value(mission.id, 'mission');
    }
    if (score.stars > _value.starsFor(mission)) {
      await _save(
        _value.copyWith(
          bestStars: {..._value.bestStars, mission.id: score.stars},
        ),
      );
    }
  });

  Future<void> setPreferences({bool? sound, bool? reducedMotion}) => _serialize(
    () => _save(_value.copyWith(sound: sound, reducedMotion: reducedMotion)),
  );

  Future<void> reset() => _serialize(
    () => _save(
      PlayerProgress(sound: _value.sound, reducedMotion: _value.reducedMotion),
    ),
  );

  Future<T> _serialize<T>(Future<T> Function() change) {
    final operation = _pending.then((_) => change());
    _pending = operation.then<void>(
      (_) {},
      onError: (Object error, StackTrace stack) {},
    );
    return operation;
  }

  Future<void> _save(PlayerProgress next) async {
    await _backend.save(next.encode());
    _value = next;
    notifyListeners();
  }
}
