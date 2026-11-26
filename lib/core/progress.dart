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

class PlayerProgress {
  PlayerProgress({
    Set<String> mastered = const {},
    Set<String> mistakes = const {},
    Map<String, int> bestStars = const {},
    this.sound = true,
    this.reducedMotion = false,
  }) : mastered = Set.unmodifiable(mastered),
       mistakes = Set.unmodifiable(mistakes),
       bestStars = Map.unmodifiable(bestStars);

  factory PlayerProgress.decode(String snapshot) {
    final json = jsonDecode(snapshot) as Map<String, dynamic>;
    if (json['version'] != 1) {
      throw const FormatException('Unsupported progress schema');
    }
    final stars = (json['bestStars'] as Map<String, dynamic>)
        .cast<String, int>();
    if (stars.values.any((count) => count < 1 || count > 3)) {
      throw const FormatException('Invalid mission stars');
    }
    return PlayerProgress(
      mastered: (json['mastered'] as List).cast<String>().toSet(),
      mistakes: (json['mistakes'] as List).cast<String>().toSet(),
      bestStars: stars,
      sound: json['sound'] as bool,
      reducedMotion: json['reducedMotion'] as bool,
    );
  }

  final Set<String> mastered;
  final Set<String> mistakes;
  final Map<String, int> bestStars;
  final bool sound;
  final bool reducedMotion;

  int get xp => mastered.length * 10;
  int get stars => bestStars.values.fold(0, (total, value) => total + value);

  int starsFor(Mission mission) => bestStars[mission.id] ?? 0;

  Set<String> stamps(GeographyCatalog catalog) =>
      mastered.map((id) => catalog.questions[id]?.country.id).nonNulls.toSet();

  String encode() => jsonEncode({
    'version': 1,
    'mastered': mastered.toList()..sort(),
    'mistakes': mistakes.toList()..sort(),
    'bestStars': bestStars,
    'sound': sound,
    'reducedMotion': reducedMotion,
  });

  PlayerProgress copyWith({
    Set<String>? mastered,
    Set<String>? mistakes,
    Map<String, int>? bestStars,
    bool? sound,
    bool? reducedMotion,
  }) => PlayerProgress(
    mastered: mastered ?? this.mastered,
    mistakes: mistakes ?? this.mistakes,
    bestStars: bestStars ?? this.bestStars,
    sound: sound ?? this.sound,
    reducedMotion: reducedMotion ?? this.reducedMotion,
  );
}

class GameProgress extends ChangeNotifier {
  GameProgress._(this.catalog, this._backend, this._value);

  static Future<GameProgress> open(
    GeographyCatalog catalog,
    ProgressBackend backend,
  ) async {
    final snapshot = await backend.load();
    return GameProgress._(
      catalog,
      backend,
      snapshot == null ? PlayerProgress() : PlayerProgress.decode(snapshot),
    );
  }

  final GeographyCatalog catalog;
  final ProgressBackend _backend;
  PlayerProgress _value;
  Future<void> _pending = Future.value();

  PlayerProgress get value => _value;

  bool get practiceUnlocked =>
      _value.starsFor(catalog.missionsIn(Chapter.arab).first) > 0;

  bool isUnlocked(Mission mission) {
    final path = catalog.missionsIn(mission.chapter);
    final index = path.indexOf(mission);
    if (index < 0) return false;
    if (index > 0) return _value.starsFor(path[index - 1]) > 0;
    return switch (mission.chapter) {
      Chapter.arab => true,
      Chapter.world =>
        catalog.missions
            .where((mission) => mission.chapter != Chapter.world)
            .every((mission) => _value.starsFor(mission) > 0),
      _ => practiceUnlocked,
    };
  }

  Mission? get nextMission => catalog.missions
      .where((mission) => isUnlocked(mission) && _value.starsFor(mission) == 0)
      .firstOrNull;

  Mission? after(Mission mission) {
    final path = catalog.missionsIn(mission.chapter);
    final index = path.indexOf(mission) + 1;
    if (index < path.length && isUnlocked(path[index])) return path[index];
    return nextMission;
  }

  List<String> get reviewIds =>
      _value.mistakes.where(catalog.questions.containsKey).toList();

  Future<int> recordAnswer(QuestionKey question, {required bool correct}) =>
      _serialize(() async {
        if (!catalog.questions.containsKey(question.id)) {
          throw ArgumentError.value(question.id, 'question');
        }
        final isNew = correct && !_value.mastered.contains(question.id);
        final mistakes = {..._value.mistakes};
        final changed = correct
            ? mistakes.remove(question.id)
            : mistakes.add(question.id);
        if (isNew || changed) {
          await _save(
            _value.copyWith(
              mastered: isNew ? {..._value.mastered, question.id} : null,
              mistakes: mistakes,
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
