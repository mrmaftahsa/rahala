import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../app/widgets.dart';
import '../../core/geography.dart';
import '../../core/world_atlas.dart';
import '../atlas/world_map.dart';

class MapQuestion extends StatefulWidget {
  const MapQuestion({
    super.key,
    required this.question,
    required this.source,
    required this.catalog,
    required this.chapter,
    required this.hinted,
    required this.selected,
    required this.onAnswer,
  });

  final QuizQuestion question;
  final AtlasSource source;
  final GeographyCatalog catalog;
  final Chapter chapter;
  final bool hinted;
  final Country? selected;
  final ValueChanged<Country>? onAnswer;

  @override
  State<MapQuestion> createState() => _MapQuestionState();
}

class _MapQuestionState extends State<MapQuestion> {
  bool _showList = false;
  late final _eligible = widget.catalog.countries.values
      .where((country) => country.mapQuiz)
      .map((country) => country.id)
      .toSet();

  @override
  Widget build(BuildContext context) {
    final country = widget.question.key.country;
    final selected = widget.selected;
    return Panel(
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'أين تقع ${country.name}؟',
            style: heading(context, size: 21),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          AtlasContent(
            source: widget.source,
            builder: (atlas) {
              final options = widget.question.options;
              final firstOther = options.firstWhere(
                (option) => option != country,
              );
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (!_showList)
                    WorldMap(
                      atlas: atlas,
                      allowed: _eligible,
                      height: 234,
                      initialExtent: WorldAtlas.extentFor(widget.chapter),
                      highlight: selected == null ? null : country.id,
                      incorrect: selected == country ? null : selected?.id,
                      focus: selected == null ? null : country.id,
                      onCountry: widget.onAnswer == null
                          ? null
                          : (id) =>
                                widget.onAnswer!(widget.catalog.countries[id]!),
                    )
                  else
                    for (final option in options)
                      if (!widget.hinted ||
                          option == firstOther ||
                          option == country)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: OutlinedButton(
                            key: ValueKey('location-choice-${option.id}'),
                            onPressed: widget.onAnswer == null
                                ? null
                                : () => widget.onAnswer!(option),
                            child: Text(
                              selected == null
                                  ? _coordinates(
                                      option,
                                      atlas.countries[option.id]!,
                                    )
                                  : option.name,
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                  if (selected == null)
                    TextButton.icon(
                      onPressed: () => setState(() => _showList = !_showList),
                      icon: Icon(
                        _showList
                            ? Icons.public_outlined
                            : Icons.list_alt_rounded,
                      ),
                      label: Text(
                        _showList
                            ? 'الاختيار من الخريطة'
                            : 'اختيار موقع من القائمة',
                      ),
                    ),
                  if (selected == null && !_showList)
                    const Text(
                      'كبّر الخريطة واضغط على الدولة.',
                      textAlign: TextAlign.center,
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  String _coordinates(Country country, MapFeature feature) {
    String direction(double value, String positive, String negative) {
      final tenths = (value.abs() * 10).round();
      return '${digits(tenths ~/ 10)}٫${digits(tenths % 10)}° ${value < 0 ? negative : positive}';
    }

    final lat = direction(feature.latitude, 'شمالًا', 'جنوبًا');
    final lon = direction(feature.longitude, 'شرقًا', 'غربًا');
    return '${country.region}\n$lat، $lon';
  }
}
