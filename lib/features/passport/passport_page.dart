import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../app/widgets.dart';
import '../../core/geography.dart';
import '../../core/progress.dart';

class PassportPage extends StatelessWidget {
  const PassportPage({super.key, required this.progress, required this.goHome});

  final GameProgress progress;
  final VoidCallback goHome;

  @override
  Widget build(BuildContext context) {
    final ids = progress.value.stamps(progress.catalog);
    final countries = progress.catalog.countries;
    final collected = countries.values
        .where((country) => ids.contains(country.id))
        .toList();
    return SafeArea(
      top: false,
      child: ListView.builder(
        key: const PageStorageKey('passport'),
        padding: const EdgeInsetsDirectional.fromSTEB(18, 12, 18, 26),
        itemCount: 1 + (collected.isEmpty ? 1 : collected.length),
        itemBuilder: (context, index) {
          final entry = index == 0
              ? _PassportCover(count: collected.length, total: countries.length)
              : collected.isEmpty
              ? _EmptyPassport(goHome: goHome)
              : _Stamp(country: collected[index - 1]);
          return Center(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 600),
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 12),
              child: entry,
            ),
          );
        },
      ),
    );
  }
}

class _PassportCover extends StatelessWidget {
  const _PassportCover({required this.count, required this.total});
  final int count;
  final int total;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: Palette.navy,
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: const Color(0xffad8436)),
    ),
    child: Column(
      children: [
        const Icon(Icons.language_rounded, color: Palette.gold, size: 43),
        const SizedBox(height: 6),
        Text(
          'جواز رحّالة',
          style: heading(context, size: 25, color: Palette.cream),
        ),
        const SizedBox(height: 7),
        Text(
          '${digits(count)} من ${digits(total)} ختمًا',
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Palette.gold,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 10),
        LinearProgressIndicator(
          value: count / total,
          color: Palette.turquoise,
          backgroundColor: const Color(0xff315972),
          borderRadius: const BorderRadius.all(Radius.circular(8)),
        ),
      ],
    ),
  );
}

class _EmptyPassport extends StatelessWidget {
  const _EmptyPassport({required this.goHome});
  final VoidCallback goHome;

  @override
  Widget build(BuildContext context) => Panel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('ختمك الأول ينتظرك', style: heading(context, size: 19)),
        const SizedBox(height: 7),
        const Text('أجب إجابة صحيحة عن علم دولة أو عاصمتها لتحصل على ختمها.'),
        const SizedBox(height: 12),
        OutlinedButton(onPressed: goHome, child: const Text('اذهب إلى الرحلة')),
      ],
    ),
  );
}

class _Stamp extends StatelessWidget {
  const _Stamp({required this.country});
  final Country country;

  @override
  Widget build(BuildContext context) => Panel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            CountryFlag(country: country, width: 57, height: 42),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(country.name, style: heading(context, size: 19)),
                  Text(
                    'العاصمة · ${country.capital}',
                    style: const TextStyle(color: Palette.tealInk),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.verified_outlined, color: Palette.tealInk),
          ],
        ),
        const Divider(height: 22),
        Text(country.fact),
        if (country.capitalNote != null) ...[
          const SizedBox(height: 5),
          Text(
            country.capitalNote!,
            style: const TextStyle(color: Palette.muted, fontSize: 13),
          ),
        ],
      ],
    ),
  );
}
