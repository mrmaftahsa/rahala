import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../app/widgets.dart';
import '../../core/geography.dart';
import '../../core/progress.dart';
import '../atlas/atlas_page.dart';

class PassportPage extends StatefulWidget {
  const PassportPage({
    super.key,
    required this.progress,
    required this.goHome,
    required this.openCountry,
  });

  final GameProgress progress;
  final VoidCallback goHome;
  final ValueChanged<Country> openCountry;

  @override
  State<PassportPage> createState() => _PassportPageState();
}

class _PassportPageState extends State<PassportPage> {
  bool _missing = false;
  Chapter _continent = Chapter.world;

  @override
  Widget build(BuildContext context) {
    final progress = widget.progress;
    final catalog = progress.catalog;
    final ids = progress.value.stamps(catalog);
    final hasFilters = catalog.schemaVersion == 2;
    final entries = catalog.countries.values
        .where(
          (country) =>
              ids.contains(country.id) != _missing &&
              (_continent == Chapter.world ||
                  country.continents.contains(_continent.id)),
        )
        .toList();
    final headerCount = hasFilters ? 2 : 1;
    return SafeArea(
      top: false,
      child: ListView.builder(
        key: const PageStorageKey('passport'),
        padding: const EdgeInsetsDirectional.fromSTEB(18, 12, 18, 26),
        itemCount: headerCount + (entries.isEmpty ? 1 : entries.length),
        itemBuilder: (context, index) {
          final Widget entry;
          if (index == 0) {
            entry = _PassportCover(
              count: ids.length,
              total: catalog.countries.length,
            );
          } else if (hasFilters && index == 1) {
            entry = Panel(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ContinentPicker(
                    value: _continent,
                    onChanged: (chapter) =>
                        setState(() => _continent = chapter),
                  ),
                  const SizedBox(height: 5),
                  Wrap(
                    spacing: 8,
                    children: [
                      ChoiceChip(
                        label: const Text('أختامي'),
                        selected: !_missing,
                        onSelected: (_) => setState(() => _missing = false),
                      ),
                      ChoiceChip(
                        label: const Text('أختام متبقّية'),
                        selected: _missing,
                        onSelected: (_) => setState(() => _missing = true),
                      ),
                    ],
                  ),
                ],
              ),
            );
          } else if (entries.isEmpty) {
            entry = ids.isEmpty && !_missing && _continent == Chapter.world
                ? _EmptyPassport(goHome: widget.goHome)
                : Panel(
                    child: Text(
                      _missing
                          ? 'اكتملت أختام هذه الوجهة.'
                          : 'لا أختام في هذه الوجهة بعد.',
                    ),
                  );
          } else {
            final country = entries[index - headerCount];
            entry = _Stamp(
              country: country,
              collected: ids.contains(country.id),
              open: hasFilters ? () => widget.openCountry(country) : null,
            );
          }
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
        const Text('أجب إجابة صحيحة عن إحدى الدول لتحصل على ختمها.'),
        const SizedBox(height: 12),
        OutlinedButton(onPressed: goHome, child: const Text('اذهب إلى الرحلة')),
      ],
    ),
  );
}

class _Stamp extends StatelessWidget {
  const _Stamp({
    required this.country,
    required this.collected,
    required this.open,
  });
  final Country country;
  final bool collected;
  final VoidCallback? open;

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
                    collected
                        ? 'العاصمة · ${country.capital}'
                        : 'بانتظار الختم',
                    style: const TextStyle(color: Palette.tealInk),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              collected ? Icons.verified_outlined : Icons.bookmark_border,
              color: Palette.tealInk,
            ),
          ],
        ),
        if (collected) ...[
          const Divider(height: 22),
          Text(country.fact),
          if (country.capitalNote case final note?)
            Text(
              note,
              style: const TextStyle(color: Palette.muted, fontSize: 13),
            ),
        ],
        if (open != null)
          TextButton.icon(
            onPressed: open,
            icon: const Icon(Icons.public_outlined),
            label: const Text('افتح في الأطلس'),
          ),
      ],
    ),
  );
}
