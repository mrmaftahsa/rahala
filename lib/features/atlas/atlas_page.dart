import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../app/widgets.dart';
import '../../core/geography.dart';
import '../../core/world_atlas.dart';
import 'world_map.dart';

const mapConvention =
    'تعرض الخريطة الحدود الفعلية بحسب مصدرها الجغرافي، وقد تختلف عن المطالبات الرسمية.';

class ContinentPicker extends StatelessWidget {
  const ContinentPicker({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final Chapter value;
  final ValueChanged<Chapter> onChanged;

  @override
  Widget build(BuildContext context) => DropdownButtonFormField<Chapter>(
    initialValue: value,
    isExpanded: true,
    decoration: const InputDecoration(labelText: 'القارّة'),
    items: [
      const DropdownMenuItem(value: Chapter.world, child: Text('جميع القارات')),
      for (final continent in Chapter.continents)
        DropdownMenuItem(value: continent, child: Text(continent.label)),
    ],
    onChanged: (value) {
      if (value != null) onChanged(value);
    },
  );
}

class AtlasPage extends StatefulWidget {
  const AtlasPage({
    super.key,
    required this.catalog,
    required this.source,
    required this.openCountry,
  });

  final GeographyCatalog catalog;
  final AtlasSource source;
  final ValueChanged<Country> openCountry;

  @override
  State<AtlasPage> createState() => _AtlasPageState();
}

class _AtlasPageState extends State<AtlasPage> {
  Chapter _continent = Chapter.world;
  String _query = '';
  Country? _selected;

  late final _alphabetical = widget.catalog.countries.values.toList()
    ..sort(
      (a, b) => arabicSearchKey(a.name).compareTo(arabicSearchKey(b.name)),
    );

  bool _inRegion(Country country) =>
      _continent == Chapter.world || country.continents.contains(_continent.id);

  bool _matches(Country country) {
    final query = arabicSearchKey(_query);
    return [
      country.name,
      country.capital,
      ...country.aliases,
    ].any((term) => arabicSearchKey(term).contains(query));
  }

  @override
  Widget build(BuildContext context) {
    final regional = _alphabetical.where(_inRegion).toList();
    final results = regional.where(_matches).toList();
    final visible = _continent == Chapter.world
        ? null
        : regional.map((country) => country.id).toSet();
    final selected = _selected;
    return SafeArea(
      top: false,
      child: CustomScrollView(
        key: const PageStorageKey('atlas'),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        slivers: [
          SliverPadding(
            padding: const EdgeInsetsDirectional.fromSTEB(16, 9, 16, 12),
            sliver: SliverToBoxAdapter(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 680),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ContinentPicker(
                        value: _continent,
                        onChanged: (continent) => setState(() {
                          _continent = continent;
                          _selected = null;
                        }),
                      ),
                      const SizedBox(height: 9),
                      AtlasContent(
                        source: widget.source,
                        builder: (atlas) => WorldMap(
                          atlas: atlas,
                          initialExtent: WorldAtlas.extentFor(_continent),
                          allowed: visible,
                          highlight: selected?.id,
                          onCountry: (id) => setState(
                            () => _selected = widget.catalog.countries[id],
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        mapConvention,
                        style: TextStyle(color: Palette.muted, fontSize: 11),
                      ),
                      if (selected != null) ...[
                        const SizedBox(height: 8),
                        _CountryTile(
                          country: selected,
                          open: widget.openCountry,
                        ),
                      ],
                      const SizedBox(height: 15),
                      TextField(
                        onChanged: (value) => setState(() => _query = value),
                        decoration: const InputDecoration(
                          labelText: 'ابحث عن دولة أو عاصمة',
                          prefixIcon: Icon(Icons.search_rounded),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'دول الأطلس · ${digits(results.length)}',
                        style: heading(context, size: 19),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (results.isEmpty)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Text('لم نعثر على دولة بهذا الاسم. جرّب كلمة أخرى.'),
              ),
            ),
          SliverPadding(
            padding: const EdgeInsetsDirectional.fromSTEB(16, 0, 16, 24),
            sliver: SliverList.builder(
              itemCount: results.length,
              itemBuilder: (context, index) => Center(
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 680),
                  margin: const EdgeInsets.only(bottom: 7),
                  child: _CountryTile(
                    country: results[index],
                    open: widget.openCountry,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CountryTile extends StatelessWidget {
  const _CountryTile({required this.country, required this.open});
  final Country country;
  final ValueChanged<Country> open;

  @override
  Widget build(BuildContext context) => Material(
    color: Palette.paper,
    shape: RoundedRectangleBorder(
      side: const BorderSide(color: Palette.line),
      borderRadius: BorderRadius.circular(15),
    ),
    child: ListTile(
      onTap: () => open(country),
      leading: CountryFlag(country: country, width: 48, height: 36),
      title: Text(
        country.name,
        style: const TextStyle(fontWeight: FontWeight.w800),
      ),
      subtitle: Text(country.capital),
      trailing: const Icon(Icons.chevron_right_rounded),
    ),
  );
}

class CountryPage extends StatelessWidget {
  const CountryPage({
    super.key,
    required this.country,
    required this.source,
    required this.stamped,
  });

  final Country country;
  final AtlasSource source;
  final bool stamped;

  @override
  Widget build(BuildContext context) {
    final continents = Chapter.continents
        .where((continent) => country.continents.contains(continent.id))
        .map((continent) => continent.label)
        .join(' · ');
    return Scaffold(
      appBar: AppBar(title: Text(country.name)),
      body: PageBody(
        children: [
          Panel(
            color: Palette.mint,
            child: Column(
              children: [
                CountryFlag(country: country, width: 168, height: 105),
                const SizedBox(height: 10),
                Text(
                  country.name,
                  style: heading(context, size: 25),
                  textAlign: TextAlign.center,
                ),
                Text(continents, textAlign: TextAlign.center),
                if (stamped)
                  const Text(
                    'ختم في جوازك',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: Palette.tealInk,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  country.id == 'nr' ? 'مقرّ الحكومة' : 'العاصمة',
                  style: heading(context, size: 18),
                ),
                Text(country.capital),
                if (country.capitalNote case final note?)
                  Text(
                    note,
                    style: const TextStyle(color: Palette.muted, fontSize: 13),
                  ),
                const Divider(height: 24),
                Text('من جغرافيا الدولة', style: heading(context, size: 18)),
                Text(country.fact),
                if (country.aliases.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text('أسماء أخرى · ${country.aliases.join('، ')}'),
                ],
              ],
            ),
          ),
          const SizedBox(height: 14),
          Text('الموقع على الخريطة', style: heading(context, size: 20)),
          const SizedBox(height: 8),
          AtlasContent(
            source: source,
            builder: (atlas) => WorldMap(
              atlas: atlas,
              focus: country.id,
              highlight: country.id,
            ),
          ),
          const SizedBox(height: 5),
          const Text(
            mapConvention,
            style: TextStyle(color: Palette.muted, fontSize: 11),
          ),
        ],
      ),
    );
  }
}
