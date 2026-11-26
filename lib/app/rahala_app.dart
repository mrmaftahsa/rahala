import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../core/geography.dart';
import '../core/progress.dart';
import '../features/home/chapter_page.dart';
import '../features/home/home_page.dart';
import '../features/passport/passport_page.dart';
import '../features/quiz/quiz_page.dart';
import '../features/settings/settings_page.dart';
import 'theme.dart';

class RahalaApp extends StatefulWidget {
  const RahalaApp({super.key, this.catalog, this.backend, this.random});

  final GeographyCatalog? catalog;
  final ProgressBackend? backend;
  final Random? random;

  @override
  State<RahalaApp> createState() => _RahalaAppState();
}

class _RahalaAppState extends State<RahalaApp> {
  GameProgress? _progress;
  late Future<GameProgress> _loading = _load();

  Future<GameProgress> _load() async {
    final catalog =
        widget.catalog ??
        GeographyCatalog.decode(
          await rootBundle.loadString('assets/data/geography.v1.json'),
        );
    final progress = await GameProgress.open(
      catalog,
      widget.backend ?? DeviceProgressBackend(),
    );
    if (mounted) {
      _progress = progress;
    } else {
      progress.dispose();
    }
    return progress;
  }

  @override
  void dispose() {
    _progress?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder(
    future: _loading,
    builder: (context, snapshot) {
      final progress = snapshot.data;
      return MaterialApp(
        title: 'رحّالة',
        debugShowCheckedModeBanner: false,
        locale: const Locale('ar'),
        supportedLocales: const [Locale('ar')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        theme: rahalaTheme(),
        builder: progress == null
            ? null
            : (context, child) => ListenableBuilder(
                listenable: progress,
                child: child,
                builder: (context, child) {
                  final media = MediaQuery.of(context);
                  return MediaQuery(
                    data: media.copyWith(
                      disableAnimations:
                          media.disableAnimations ||
                          progress.value.reducedMotion,
                    ),
                    child: child!,
                  );
                },
              ),
        home: progress == null
            ? _LoadingPage(
                failed:
                    snapshot.connectionState == ConnectionState.done &&
                    snapshot.hasError,
                retry: () => setState(() => _loading = _load()),
              )
            : _JourneyShell(progress: progress, random: widget.random),
      );
    },
  );
}

class _LoadingPage extends StatelessWidget {
  const _LoadingPage({required this.failed, required this.retry});
  final bool failed;
  final VoidCallback retry;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('رحّالة')),
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: failed
            ? Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'تعذّر فتح الرحلة. أعد المحاولة.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: retry,
                    child: const Text('أعد المحاولة'),
                  ),
                ],
              )
            : const CircularProgressIndicator(
                semanticsLabel: 'جارٍ فتح الرحلة',
              ),
      ),
    ),
  );
}

class _JourneyShell extends StatefulWidget {
  const _JourneyShell({required this.progress, this.random});

  final GameProgress progress;
  final Random? random;

  @override
  State<_JourneyShell> createState() => _JourneyShellState();
}

class _JourneyShellState extends State<_JourneyShell> {
  int _tab = 0;
  late final _builder = QuizBuilder(
    widget.progress.catalog,
    random: widget.random,
  );

  Route<void> _route(Widget page) {
    final reduce = MediaQuery.disableAnimationsOf(context);
    final duration = reduce ? Duration.zero : const Duration(milliseconds: 200);
    return PageRouteBuilder<void>(
      pageBuilder: (context, animation, secondary) => page,
      transitionDuration: duration,
      reverseTransitionDuration: duration,
      transitionsBuilder: (context, animation, secondary, child) =>
          reduce ? child : FadeTransition(opacity: animation, child: child),
    );
  }

  void _openChapter(Chapter chapter) {
    Navigator.of(context).push(
      _route(
        ChapterPage(
          chapter: chapter,
          progress: widget.progress,
          play: _playMission,
        ),
      ),
    );
  }

  void _playMission(Mission mission, {bool replace = false}) {
    if (!widget.progress.isUnlocked(mission)) return;
    final route = _route(
      QuizPage(
        title: mission.title,
        progress: widget.progress,
        makeDeck: () => _builder.mission(mission),
        mission: mission,
        openNext: (next) => _playMission(next, replace: true),
      ),
    );
    if (replace) {
      Navigator.of(context).pushReplacement(route);
    } else {
      Navigator.of(context).push(route);
    }
  }

  void _practice() {
    Navigator.of(context).push(
      _route(
        PracticePage(
          play: (chapter, mode) => Navigator.of(context).push(
            _route(
              QuizPage(
                title: 'تدريب سريع',
                progress: widget.progress,
                makeDeck: () => _builder.practice(chapter, mode),
                openNext: _playMission,
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _review() {
    final ids = widget.progress.reviewIds;
    if (ids.isEmpty) return;
    Navigator.of(context).push(
      _route(
        QuizPage(
          title: 'مراجعة الأخطاء',
          progress: widget.progress,
          makeDeck: () => _builder.review(ids),
          review: true,
          openNext: _playMission,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.progress,
    builder: (context, child) => Scaffold(
      appBar: AppBar(
        title: _tab == 0
            ? Row(
                children: [
                  const Icon(
                    Icons.explore_rounded,
                    color: Palette.tealInk,
                    size: 30,
                  ),
                  const SizedBox(width: 8),
                  Text('رحّالة', style: heading(context, size: 24)),
                ],
              )
            : Text(_tab == 1 ? 'جواز السفر' : 'الإعدادات'),
      ),
      body: switch (_tab) {
        0 => HomePage(
          progress: widget.progress,
          play: _playMission,
          openChapter: _openChapter,
          openPractice: _practice,
          review: _review,
        ),
        1 => PassportPage(
          progress: widget.progress,
          goHome: () => setState(() => _tab = 0),
        ),
        _ => SettingsPage(progress: widget.progress),
      },
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (tab) => setState(() => _tab = tab),
        animationDuration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : null,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.explore_outlined),
            label: 'الرحلة',
          ),
          NavigationDestination(
            icon: Icon(Icons.menu_book_outlined),
            label: 'الجواز',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            label: 'الإعدادات',
          ),
        ],
      ),
    ),
  );
}
