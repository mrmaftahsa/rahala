import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../app/widgets.dart';
import '../../core/progress.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key, required this.progress});
  final GameProgress progress;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _saving = false;

  Future<void> _change(Future<void> Function() save, {String? notice}) async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await save();
      if (!mounted || notice == null) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(notice)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذّر الحفظ. حاول مرة أخرى.')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _confirmReset() async {
    final confirmed = await showDialog<bool>(
      context: context,
      animationStyle: MediaQuery.disableAnimationsOf(context)
          ? AnimationStyle.noAnimation
          : null,
      builder: (context) => AlertDialog(
        title: const Text('إعادة ضبط التقدّم؟'),
        content: const Text(
          'سيُحذف تقدّم رحلتك، بما فيه النجوم ونقاط الخبرة والأختام والأخطاء المحفوظة.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Palette.redInk),
            child: const Text('احذف التقدّم'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await _change(widget.progress.reset, notice: 'أُعيد ضبط التقدّم.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final progress = widget.progress;
    final player = progress.value;
    return PageBody(
      scrollKey: const PageStorageKey('settings'),
      children: [
        Text('تفضيلات اللعب', style: heading(context)),
        const SizedBox(height: 9),
        Panel(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              SwitchListTile(
                secondary: const Icon(Icons.volume_up_outlined),
                title: const Text('المؤثرات الصوتية'),
                subtitle: const Text('صوت قصير عند الإجابة'),
                value: player.sound,
                onChanged: _saving
                    ? null
                    : (value) =>
                          _change(() => progress.setPreferences(sound: value)),
              ),
              const Divider(height: 1),
              SwitchListTile(
                secondary: const Icon(Icons.motion_photos_off_outlined),
                title: const Text('تقليل الحركة'),
                subtitle: const Text('عرض الشاشات دون انتقالات متحركة'),
                value: player.reducedMotion,
                onChanged: _saving
                    ? null
                    : (value) => _change(
                        () => progress.setPreferences(reducedMotion: value),
                      ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Text('التقدّم', style: heading(context)),
        const SizedBox(height: 9),
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'يُحفظ تقدّمك على هذا الجهاز وتستطيع اللعب دون اتصال.',
              ),
              const SizedBox(height: 9),
              OutlinedButton.icon(
                onPressed: _saving ? null : _confirmReset,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Palette.redInk,
                ),
                icon: const Icon(Icons.restart_alt_rounded),
                label: const Text('إعادة ضبط التقدّم'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Text('حول رحّالة', style: heading(context)),
        const SizedBox(height: 9),
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'تضم هذه النسخة ${digits(progress.catalog.countries.length)} دولة في أسئلة الأعلام والعواصم.',
              ),
              const SizedBox(height: 9),
              OutlinedButton.icon(
                onPressed: () => showDialog<void>(
                  context: context,
                  animationStyle: MediaQuery.disableAnimationsOf(context)
                      ? AnimationStyle.noAnimation
                      : null,
                  builder: (context) => AlertDialog(
                    title: const Text('المصادر والتراخيص'),
                    content: const SingleChildScrollView(
                      child: Text(
                        'العواصم والحقائق من أرشيف كتاب حقائق العالم. الرسوم الأصلية للأعلام من ويكيميديا كومنز عبر مشروع أعلام الدول. الخط: نوتو سانس عربي، بترخيص الخطوط المفتوحة.',
                      ),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('إغلاق'),
                      ),
                    ],
                  ),
                ),
                icon: const Icon(Icons.info_outline_rounded),
                label: const Text('المصادر والتراخيص'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
