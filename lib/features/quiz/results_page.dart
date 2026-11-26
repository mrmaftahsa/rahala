import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../app/widgets.dart';
import '../../core/geography.dart';

class ResultsPage extends StatelessWidget {
  const ResultsPage({
    super.key,
    required this.score,
    required this.earned,
    required this.stamps,
    required this.mission,
    required this.bestStars,
    required this.remainingMistakes,
    required this.retry,
    required this.next,
  });

  final QuizScore score;
  final int earned;
  final int stamps;
  final Mission? mission;
  final int bestStars;
  final int? remainingMistakes;
  final VoidCallback retry;
  final VoidCallback? next;

  @override
  Widget build(BuildContext context) {
    final inMission = mission != null;
    final passed = score.stars > 0;
    return Scaffold(
      appBar: AppBar(title: const Text('نتيجة الجولة')),
      body: PageBody(
        children: [
          Panel(
            color: inMission && !passed ? Palette.blush : Palette.mint,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 23),
            child: Column(
              children: [
                Icon(
                  inMission && !passed
                      ? Icons.explore_outlined
                      : Icons.workspace_premium_outlined,
                  size: 53,
                  color: inMission && !passed
                      ? Palette.redInk
                      : Palette.tealInk,
                ),
                const SizedBox(height: 8),
                Text(
                  inMission
                      ? passed
                            ? 'أتممت المحطة!'
                            : 'جرّب المحطة من جديد'
                      : 'أنهيت الجولة!',
                  textAlign: TextAlign.center,
                  style: heading(context, size: 25),
                ),
                const SizedBox(height: 8),
                if (inMission)
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: .78, end: 1),
                    duration: MediaQuery.disableAnimationsOf(context)
                        ? Duration.zero
                        : const Duration(milliseconds: 265),
                    curve: Curves.easeOutBack,
                    builder: (context, scale, child) =>
                        Transform.scale(scale: scale, child: child),
                    child: Stars(score.stars, size: 31),
                  ),
                const SizedBox(height: 6),
                Text(
                  '${digits(score.correct)} من ${digits(score.total)} إجابات صحيحة',
                  textAlign: TextAlign.center,
                  style: heading(context, size: 17),
                ),
                if (inMission && !passed)
                  Text(
                    'للعبور، أجب عن ${digits((score.total * 4 + 4) ~/ 5)} أسئلة على الأقل.',
                    textAlign: TextAlign.center,
                  ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('نقاط الخبرة المكتسبة · ${digits(earned)}'),
                if (stamps > 0)
                  Text(
                    'أختام جديدة في جوازك · ${digits(stamps)}',
                    style: const TextStyle(
                      color: Palette.tealInk,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                if (inMission)
                  Text('أفضل نتيجة · ${digits(bestStars)} من ٣ نجوم'),
                if (remainingMistakes case final count?)
                  Text(
                    count == 0
                        ? 'راجعت كل أخطائك.'
                        : 'أسئلة تحتاج إلى مراجعة · ${digits(count)}',
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (next != null) ...[
            FilledButton(onPressed: next, child: const Text('المحطة التالية')),
            const SizedBox(height: 8),
          ],
          OutlinedButton(
            onPressed: retry,
            child: Text(inMission ? 'أعد المحطة' : 'أعد الجولة'),
          ),
          const SizedBox(height: 5),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('إنهاء الجولة'),
          ),
        ],
      ),
    );
  }
}
