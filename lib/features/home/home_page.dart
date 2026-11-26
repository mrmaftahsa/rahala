import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../app/widgets.dart';
import '../../core/geography.dart';
import '../../core/progress.dart';

class HomePage extends StatelessWidget {
  const HomePage({
    super.key,
    required this.progress,
    required this.play,
    required this.openChapter,
    required this.openPractice,
    required this.review,
    required this.spacedReview,
  });

  final GameProgress progress;
  final ValueChanged<Mission> play;
  final ValueChanged<Chapter> openChapter;
  final VoidCallback openPractice;
  final VoidCallback review;
  final VoidCallback spacedReview;

  @override
  Widget build(BuildContext context) {
    final next = progress.nextMission;
    final mission = next ?? progress.catalog.missions.last;
    final journeyStarted = progress.value.bestStars.isNotEmpty;
    final reviewCount = progress.reviewIds.length;
    final dueCount = progress.dueReviewIds.length;
    return PageBody(
      scrollKey: const PageStorageKey('adventure'),
      children: [
        _DepartureCard(
          mission: mission,
          action: next == null
              ? 'أعد تحدي العالم'
              : journeyStarted
              ? 'تابع الرحلة'
              : 'ابدأ الرحلة',
          onPressed: () => play(mission),
        ),
        const SizedBox(height: 14),
        Panel(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Stat(
                Icons.bolt_rounded,
                progress.value.xp,
                'نقطة خبرة',
                Palette.tealInk,
              ),
              _Stat(
                Icons.star_rounded,
                progress.value.stars,
                'نجمة',
                const Color(0xff956000),
              ),
              _Stat(
                Icons.bookmark_added_outlined,
                progress.value.stamps(progress.catalog).length,
                'ختم',
                Palette.redInk,
              ),
            ],
          ),
        ),
        const SizedBox(height: 17),
        Panel(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (progress.practiceUnlocked)
                OutlinedButton.icon(
                  onPressed: openPractice,
                  icon: const Icon(Icons.route_outlined),
                  label: const Text('تدريب سريع'),
                )
              else
                const Text('أكمل المحطة الأولى لفتح التدريب السريع.'),
              if (reviewCount > 0) ...[
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: review,
                  icon: const Icon(Icons.replay_rounded),
                  label: Text('مراجعة الأخطاء (${digits(reviewCount)})'),
                ),
              ],
              if (dueCount > 0) ...[
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: spacedReview,
                  icon: const Icon(Icons.schedule_rounded),
                  label: Text('مراجعة الذاكرة (${digits(dueCount)})'),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 23),
        Text('محطات الرحلة', style: heading(context)),
        const SizedBox(height: 9),
        for (final chapter in Chapter.values) ...[
          _ChapterTile(
            chapter: chapter,
            progress: progress,
            onTap: () => openChapter(chapter),
          ),
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}

class _DepartureCard extends StatelessWidget {
  const _DepartureCard({
    required this.mission,
    required this.action,
    required this.onPressed,
  });

  final Mission mission;
  final String action;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.textScalerOf(context).scale(16) > 21;
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: ColoredBox(
        color: Palette.navy,
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(17, 20, 13, 20),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'رحلة حول العالم',
                      style: heading(context, size: 25, color: Palette.cream),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      '${mission.chapter.label} · ${mission.title}',
                      style: const TextStyle(
                        color: Color(0xff9fe0d4),
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 15),
                    FilledButton(
                      onPressed: onPressed,
                      style: FilledButton.styleFrom(
                        backgroundColor: Palette.gold,
                        foregroundColor: Palette.navy,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 9,
                        ),
                      ),
                      child: Text(
                        action,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ],
                ),
              ),
              if (!compact)
                const SizedBox(width: 120, height: 148, child: JourneyGlobe()),
            ],
          ),
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat(this.icon, this.value, this.label, this.color);
  final IconData icon;
  final int value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Semantics(
      label: '${digits(value)} $label',
      child: ExcludeSemantics(
        child: Column(
          children: [
            Icon(icon, color: color, size: 22),
            Text(digits(value), style: heading(context, size: 21)),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
      ),
    ),
  );
}

class _ChapterTile extends StatelessWidget {
  const _ChapterTile({
    required this.chapter,
    required this.progress,
    required this.onTap,
  });

  final Chapter chapter;
  final GameProgress progress;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final missions = progress.catalog.missionsIn(chapter);
    final completed = missions
        .where((mission) => progress.value.starsFor(mission) > 0)
        .length;
    final locked = !progress.isUnlocked(missions.first);
    return Material(
      color: Palette.paper,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: Palette.line),
      ),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 11, vertical: 4),
        minLeadingWidth: 0,
        leading: ChapterMedallion(chapter),
        title: Text(
          chapter.label,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        subtitle: Text(
          locked
              ? 'محطة مقفلة'
              : '${digits(completed)} من ${digits(missions.length)} مكتملة',
          style: const TextStyle(color: Palette.muted, fontSize: 12),
        ),
        trailing: Icon(
          locked ? Icons.lock_outline_rounded : Icons.chevron_right_rounded,
        ),
      ),
    );
  }
}
