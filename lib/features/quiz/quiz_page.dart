import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/theme.dart';
import '../../app/widgets.dart';
import '../../core/geography.dart';
import '../../core/progress.dart';
import '../../core/world_atlas.dart';
import '../atlas/world_map.dart';
import 'map_question.dart';
import 'results_page.dart';

class QuizPage extends StatefulWidget {
  const QuizPage({
    super.key,
    required this.title,
    required this.progress,
    required this.atlas,
    required this.makeDeck,
    required this.openNext,
    this.mission,
    this.chapter = Chapter.world,
    this.review = false,
  });

  final String title;
  final GameProgress progress;
  final AtlasSource atlas;
  final Chapter chapter;
  final List<QuizQuestion> Function() makeDeck;
  final ValueChanged<Mission> openNext;
  final Mission? mission;
  final bool review;

  @override
  State<QuizPage> createState() => _QuizPageState();
}

class _QuizPageState extends State<QuizPage> {
  final _feedbackKey = GlobalKey();
  final _scroll = ScrollController();
  late List<QuizQuestion> _questions = widget.makeDeck();
  int _index = 0;
  int _correct = 0;
  int _earned = 0;
  Country? _selected;
  late Set<String> _initialStamps;
  bool _hinted = false;
  bool _saving = false;
  bool _complete = false;

  QuizQuestion get _current => _questions[_index];
  bool get _last => _index == _questions.length - 1;
  bool get _reduceMotion =>
      widget.progress.value.reducedMotion ||
      MediaQuery.disableAnimationsOf(context);

  Future<void> _answer(Country choice) async {
    if (_saving || _selected != null) return;
    final correct = choice == _current.key.country;
    setState(() => _saving = true);
    try {
      final earned = await widget.progress.recordAnswer(
        _current.key,
        correct: correct,
      );
      if (!mounted) return;
      setState(() {
        _selected = choice;
        _earned += earned;
        if (correct) _correct++;
        _saving = false;
      });
      unawaited(_playFeedback(correct, sound: widget.progress.value.sound));
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final target = _feedbackKey.currentContext;
        if (mounted && target != null) {
          unawaited(
            Scrollable.ensureVisible(
              target,
              duration: _reduceMotion
                  ? Duration.zero
                  : const Duration(milliseconds: 220),
              curve: Curves.easeOut,
              alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
            ),
          );
        }
      });
    } catch (_) {
      _saveFailed();
    }
  }

  Future<void> _advance() async {
    if (_saving || _selected == null) return;
    if (!_last) {
      setState(() {
        _index++;
        _selected = null;
        _hinted = false;
      });
      _scroll.jumpTo(0);
      return;
    }
    setState(() => _saving = true);
    try {
      final mission = widget.mission;
      if (mission != null) {
        await widget.progress.finish(
          mission,
          QuizScore(_correct, _questions.length),
        );
      }
      if (!mounted) return;
      setState(() {
        _saving = false;
        _complete = true;
      });
    } catch (_) {
      _saveFailed();
    }
  }

  void _saveFailed() {
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تعذّر حفظ التقدّم. حاول مرة أخرى.')),
    );
  }

  void _retry() {
    setState(() {
      _questions = widget.makeDeck();
      _index = 0;
      _correct = 0;
      _earned = 0;
      _selected = null;
      _complete = false;
      _hinted = false;
      _initialStamps = widget.progress.value.stamps(widget.progress.catalog);
    });
  }

  @override
  void initState() {
    super.initState();
    _initialStamps = widget.progress.value.stamps(widget.progress.catalog);
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_complete) {
      final score = QuizScore(_correct, _questions.length);
      final mission = widget.mission;
      final next = mission != null && score.stars > 0
          ? widget.progress.after(mission)
          : null;
      return ResultsPage(
        score: score,
        earned: _earned,
        stamps: widget.progress.value
            .stamps(widget.progress.catalog)
            .difference(_initialStamps)
            .length,
        mission: mission,
        bestStars: mission == null
            ? 0
            : widget.progress.value.starsFor(mission),
        remainingMistakes: widget.review
            ? widget.progress.reviewIds.length
            : null,
        retry: _retry,
        next: next == null ? null : () => widget.openNext(next),
      );
    }

    final question = _current;
    final selected = _selected;
    final answer = question.key.country;
    final firstOther = question.options.firstWhere(
      (option) => option != answer,
    );
    final canAnswer = selected == null && !_saving;
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: SafeArea(
        top: false,
        child: ListView(
          controller: _scroll,
          padding: const EdgeInsetsDirectional.fromSTEB(18, 9, 18, 20),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 540),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _QuestionProgress(
                      current: _index + 1,
                      total: _questions.length,
                    ),
                    const SizedBox(height: 12),
                    if (question.key.mode == QuizMode.location)
                      MapQuestion(
                        key: ValueKey(question.key.id),
                        question: question,
                        source: widget.atlas,
                        chapter: widget.mission?.chapter ?? widget.chapter,
                        catalog: widget.progress.catalog,
                        hinted: _hinted,
                        selected: selected,
                        onAnswer: canAnswer ? _answer : null,
                      )
                    else ...[
                      _QuestionCard(question: question, atlas: widget.atlas),
                      const SizedBox(height: 12),
                      for (final (index, option) in question.options.indexed)
                        if (!_hinted ||
                            option == answer ||
                            option == firstOther)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: _Choice(
                              label: question.labelFor(option),
                              letter: 'أبجد'[index],
                              correct: selected != null && option == answer,
                              incorrect: selected == option && option != answer,
                              onTap: canAnswer ? () => _answer(option) : null,
                            ),
                          ),
                    ],
                    if (selected == null &&
                        widget.progress.catalog.schemaVersion >= 2)
                      if (_hinted)
                        Panel(
                          color: Palette.mint,
                          padding: const EdgeInsets.all(9),
                          child: Text('تلميح · ${answer.region}'),
                        )
                      else
                        TextButton.icon(
                          onPressed: _saving
                              ? null
                              : () => setState(() => _hinted = true),
                          icon: const Icon(Icons.lightbulb_outline_rounded),
                          label: const Text('تلميح'),
                        ),
                    if (selected != null)
                      Column(
                        key: _feedbackKey,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          TweenAnimationBuilder<double>(
                            tween: Tween(begin: 0, end: 1),
                            duration: _reduceMotion
                                ? Duration.zero
                                : const Duration(milliseconds: 195),
                            curve: Curves.easeOut,
                            builder: (context, value, child) =>
                                Opacity(opacity: value, child: child),
                            child: _Feedback(
                              question: question,
                              correct: selected == answer,
                            ),
                          ),
                          const SizedBox(height: 9),
                          FilledButton(
                            onPressed: _saving ? null : _advance,
                            child: Text(
                              _last ? 'عرض النتيجة' : 'السؤال التالي',
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

const _feedbackChannel = MethodChannel('com.rahala.geography/feedback');

Future<void> _playFeedback(bool correct, {required bool sound}) async {
  await HapticFeedback.selectionClick();
  if (!sound) return;
  try {
    await _feedbackChannel.invokeMethod<void>('answer', correct);
  } on MissingPluginException {
    // The native tone is Android-only.
  } on PlatformException {
    // Visual feedback is available even if audio is unavailable.
  }
}

class _QuestionProgress extends StatelessWidget {
  const _QuestionProgress({required this.current, required this.total});
  final int current;
  final int total;

  @override
  Widget build(BuildContext context) {
    final label = 'السؤال ${digits(current)} من ${digits(total)}';
    return Semantics(
      label: label,
      child: ExcludeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                color: Palette.tealInk,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 7),
            LinearProgressIndicator(
              value: current / total,
              borderRadius: const BorderRadius.all(Radius.circular(8)),
              minHeight: 7,
              color: Palette.tealInk,
              backgroundColor: const Color(0xffd6e7dc),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuestionCard extends StatelessWidget {
  const _QuestionCard({required this.question, required this.atlas});
  final QuizQuestion question;
  final AtlasSource atlas;

  @override
  Widget build(BuildContext context) {
    final country = question.key.country;
    final prompt = switch (question.key.mode) {
      QuizMode.flag => 'لأيّ دولة هذا العلم؟',
      QuizMode.capital => 'ما عاصمة هذه الدولة؟',
      QuizMode.outline => 'لأيّ دولة هذا الشكل؟',
      QuizMode.location => throw StateError(
        'Location uses the interactive map',
      ),
    };
    final visual = switch (question.key.mode) {
      QuizMode.flag => ColoredBox(
        color: Palette.cream,
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: CountryFlag(
            country: country,
            width: 168,
            height: 103,
            reveal: false,
          ),
        ),
      ),
      QuizMode.capital => Column(
        children: [
          const Icon(
            Icons.location_city_outlined,
            color: Palette.tealInk,
            size: 34,
          ),
          const SizedBox(height: 3),
          Text(
            country.name,
            style: heading(context, size: 26, color: Palette.tealInk),
            textAlign: TextAlign.center,
          ),
        ],
      ),
      QuizMode.outline => AtlasContent(
        source: atlas,
        builder: (atlas) =>
            CountryOutline(feature: atlas.countries[country.id]!),
      ),
      QuizMode.location => throw StateError(
        'Location uses the interactive map',
      ),
    };
    return Panel(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
      child: Column(
        children: [
          Text(
            prompt,
            style: heading(context, size: 22),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 9),
          visual,
        ],
      ),
    );
  }
}

class _Choice extends StatelessWidget {
  const _Choice({
    required this.label,
    required this.letter,
    required this.correct,
    required this.incorrect,
    required this.onTap,
  });

  final String label;
  final String letter;
  final bool correct;
  final bool incorrect;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ink = correct
        ? Palette.tealInk
        : incorrect
        ? Palette.redInk
        : Palette.navy;
    return Semantics(
      button: true,
      enabled: onTap != null,
      label: correct
          ? '$label، الإجابة الصحيحة'
          : incorrect
          ? '$label، إجابة غير صحيحة'
          : label,
      child: Material(
        color: correct
            ? Palette.mint
            : incorrect
            ? Palette.blush
            : Palette.paper,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
          side: BorderSide(color: correct || incorrect ? ink : Palette.line),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(15),
          child: ExcludeSemantics(
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 50),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 11,
                  vertical: 7,
                ),
                child: Row(
                  children: [
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: correct || incorrect
                            ? Palette.paper
                            : Palette.cream,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(
                          minWidth: 29,
                          minHeight: 29,
                        ),
                        child: Center(
                          child: correct || incorrect
                              ? Icon(
                                  correct
                                      ? Icons.check_rounded
                                      : Icons.close_rounded,
                                  color: ink,
                                  size: 19,
                                )
                              : Text(
                                  letter,
                                  style: TextStyle(
                                    color: ink,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        label,
                        style: TextStyle(
                          color: ink,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Feedback extends StatelessWidget {
  const _Feedback({required this.question, required this.correct});
  final QuizQuestion question;
  final bool correct;

  @override
  Widget build(BuildContext context) {
    final country = question.key.country;
    return Semantics(
      liveRegion: true,
      child: Panel(
        color: correct ? Palette.mint : Palette.blush,
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              correct ? 'أحسنت! إجابة صحيحة' : 'هذه المرة لم تصب',
              style: heading(
                context,
                size: 18,
                color: correct ? Palette.tealInk : Palette.redInk,
              ),
            ),
            Text('الإجابة الصحيحة هي ${question.key.answer}.'),
            const SizedBox(height: 4),
            Text(
              country.fact,
              style: const TextStyle(color: Palette.muted, fontSize: 13),
            ),
            if (question.key.mode == QuizMode.capital &&
                country.capitalNote != null)
              Text(
                country.capitalNote!,
                style: const TextStyle(color: Palette.muted, fontSize: 13),
              ),
          ],
        ),
      ),
    );
  }
}
