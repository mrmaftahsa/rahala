import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../app/widgets.dart';
import '../../core/geography.dart';
import '../../core/progress.dart';

class ChapterPage extends StatelessWidget {
  const ChapterPage({
    super.key,
    required this.chapter,
    required this.progress,
    required this.play,
  });

  final Chapter chapter;
  final GameProgress progress;
  final ValueChanged<Mission> play;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: progress,
    builder: (context, child) {
      final missions = progress.catalog.missionsIn(chapter);
      return Scaffold(
        appBar: AppBar(title: const Text('مسار الرحلة')),
        body: PageBody(
          children: [
            Panel(
              color: Palette.mint,
              child: Row(
                children: [
                  ChapterMedallion(chapter, size: 61),
                  const SizedBox(width: 13),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(chapter.label, style: heading(context)),
                        const SizedBox(height: 3),
                        Text(chapter.description),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            for (final (index, mission) in missions.indexed)
              _MissionTile(
                mission: mission,
                index: index,
                stars: progress.value.starsFor(mission),
                unlocked: progress.isUnlocked(mission),
                isLast: index == missions.length - 1,
                onTap: () => play(mission),
              ),
          ],
        ),
      );
    },
  );
}

class _MissionTile extends StatelessWidget {
  const _MissionTile({
    required this.mission,
    required this.index,
    required this.stars,
    required this.unlocked,
    required this.isLast,
    required this.onTap,
  });

  final Mission mission;
  final int index;
  final int stars;
  final bool unlocked;
  final bool isLast;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final caption = switch ((unlocked, stars, mission.chapter)) {
      (_, > 0, _) => 'مكتملة · يمكنك إعادتها',
      (true, _, _) => '${digits(mission.questions.length)} أسئلة · جاهزة للعب',
      (false, _, Chapter.world) => 'أكمل محطات الفصول الأخرى',
      (false, _, _) when index == 0 => 'أكمل أول محطة في العالم العربي',
      _ => 'أكمل المحطة السابقة',
    };
    return Stack(
      children: [
        if (!isLast)
          const PositionedDirectional(
            start: 21,
            top: 20,
            bottom: 0,
            child: ColoredBox(color: Palette.line, child: SizedBox(width: 2)),
          ),
        Padding(
          padding: const EdgeInsets.only(bottom: 13),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 43,
                height: 43,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: unlocked ? Palette.navy : Palette.paper,
                  border: Border.all(color: Palette.line),
                ),
                child: Icon(
                  stars > 0
                      ? Icons.check_rounded
                      : unlocked
                      ? Icons.place_outlined
                      : Icons.lock_outline_rounded,
                  color: unlocked ? Palette.cream : Palette.muted,
                  size: 21,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Material(
                  color: Palette.paper,
                  shape: RoundedRectangleBorder(
                    side: const BorderSide(color: Palette.line),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: InkWell(
                    onTap: unlocked ? onTap : null,
                    borderRadius: BorderRadius.circular(18),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'المحطة ${digits(index + 1)}',
                            style: const TextStyle(
                              color: Palette.tealInk,
                              fontSize: 12,
                            ),
                          ),
                          Text(
                            mission.title,
                            style: heading(context, size: 19),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            caption,
                            style: const TextStyle(
                              color: Palette.muted,
                              fontSize: 13,
                            ),
                          ),
                          if (stars > 0) ...[
                            const SizedBox(height: 6),
                            Stars(stars),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class PracticePage extends StatefulWidget {
  const PracticePage({super.key, required this.play});
  final void Function(Chapter, QuizMode) play;

  @override
  State<PracticePage> createState() => _PracticePageState();
}

class _PracticePageState extends State<PracticePage> {
  Chapter _chapter = Chapter.arab;
  QuizMode _mode = QuizMode.flag;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('تدريب سريع')),
    body: PageBody(
      children: [
        Text('اختر وجهتك', style: heading(context)),
        const SizedBox(height: 12),
        DropdownButtonFormField<Chapter>(
          initialValue: _chapter,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'الفصل'),
          items: [
            for (final chapter in Chapter.values)
              DropdownMenuItem(
                value: chapter,
                child: Text(
                  chapter == Chapter.world ? 'جميع الفصول' : chapter.label,
                ),
              ),
          ],
          onChanged: (value) => setState(() => _chapter = value!),
        ),
        const SizedBox(height: 18),
        Text('نوع الأسئلة', style: heading(context, size: 18)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 5,
          children: [
            for (final mode in QuizMode.values)
              ChoiceChip(
                label: Text(mode.label),
                selected: mode == _mode,
                onSelected: (_) => setState(() => _mode = mode),
              ),
          ],
        ),
        const SizedBox(height: 20),
        FilledButton(
          onPressed: () => widget.play(_chapter, _mode),
          child: const Text('ابدأ التدريب'),
        ),
      ],
    ),
  );
}
