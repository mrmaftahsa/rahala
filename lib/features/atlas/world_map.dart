import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../core/world_atlas.dart';

class AtlasContent extends StatefulWidget {
  const AtlasContent({super.key, required this.source, required this.builder});

  final AtlasSource source;
  final Widget Function(WorldAtlas atlas) builder;

  @override
  State<AtlasContent> createState() => _AtlasContentState();
}

class _AtlasContentState extends State<AtlasContent> {
  late Future<WorldAtlas> _future = widget.source.load();

  @override
  Widget build(BuildContext context) => FutureBuilder<WorldAtlas>(
    future: _future,
    builder: (context, snapshot) {
      if (snapshot.data case final atlas?) return widget.builder(atlas);
      return SizedBox(
        height: 225,
        child: Center(
          child:
              snapshot.connectionState == ConnectionState.done &&
                  snapshot.hasError
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('تعذّر فتح الخريطة.'),
                    TextButton(
                      onPressed: () =>
                          setState(() => _future = widget.source.load()),
                      child: const Text('أعد المحاولة'),
                    ),
                  ],
                )
              : const CircularProgressIndicator(
                  semanticsLabel: 'جارٍ فتح الخريطة',
                ),
        ),
      );
    },
  );
}

class WorldMap extends StatefulWidget {
  const WorldMap({
    super.key,
    required this.atlas,
    this.allowed,
    this.highlight,
    this.incorrect,
    this.initialExtent = WorldAtlas.extent,
    this.focus,
    this.onCountry,
    this.height = 240,
  });

  final WorldAtlas atlas;
  final Set<String>? allowed;
  final String? highlight;
  final String? incorrect;
  final Rect initialExtent;
  final String? focus;
  final ValueChanged<String>? onCountry;
  final double height;

  @override
  State<WorldMap> createState() => _WorldMapState();
}

class _WorldMapState extends State<WorldMap> {
  final _camera = TransformationController();
  Size _size = Size.zero;

  _Projection get _projection => _Projection(_size);

  Rect get _frame {
    final feature = widget.atlas.countries[widget.focus];
    if (feature == null) return widget.initialExtent;
    final bounds = feature.bounds;
    // An antimeridian split can make a small island group's map bounds span
    // the earth. Its on-land anchor gives the camera a useful starting point.
    if (bounds.width > 185) {
      return Rect.fromCenter(center: feature.anchor, width: 80, height: 70);
    }
    return bounds.inflate(math.max(1.6, bounds.longestSide * .14));
  }

  void _placeCamera() {
    if (_size.isEmpty) return;
    final frame = _frame;
    final projection = _projection;
    final scale = math
        .min(
          _size.width / (frame.width * projection.unit),
          _size.height / (frame.height * projection.unit),
        )
        .clamp(1.0, 56.0);
    _centerOn(projection.project(frame.center), scale);
  }

  void _centerOn(Offset scene, double scale) {
    final center = _size.center(Offset.zero);
    _camera.value = Matrix4.diagonal3Values(scale, scale, 1)
      ..setTranslationRaw(
        center.dx - scene.dx * scale,
        center.dy - scene.dy * scale,
        0,
      );
  }

  void _zoom(double factor) {
    final scene = _camera.toScene(_size.center(Offset.zero));
    final target = (_camera.value.getMaxScaleOnAxis() * factor).clamp(
      1.0,
      56.0,
    );
    _centerOn(scene, target);
  }

  @override
  void didUpdateWidget(WorldMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.focus != oldWidget.focus ||
        widget.initialExtent != oldWidget.initialExtent) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _placeCamera();
      });
    }
  }

  @override
  void dispose() {
    _camera.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox(
    height: widget.height,
    child: ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = constraints.biggest;
          if (_size != size) {
            _size = size;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) _placeCamera();
            });
          }
          return ColoredBox(
            color: _sea,
            child: Stack(
              children: [
                Semantics(
                  label:
                      'خريطة العالم. حرّك الخريطة بإصبعك أو استخدم أزرار التكبير.',
                  child: GestureDetector(
                    onTapUp: widget.onCountry == null
                        ? null
                        : (event) {
                            final position = _projection.unproject(
                              _camera.toScene(event.localPosition),
                            );
                            final id = widget.atlas.hitTest(
                              position,
                              allowed: widget.allowed,
                              markerRadius: .66,
                            );
                            if (id != null) widget.onCountry!(id);
                          },
                    child: InteractiveViewer(
                      transformationController: _camera,
                      boundaryMargin: EdgeInsets.all(size.longestSide),
                      minScale: 1,
                      maxScale: 56,
                      child: RepaintBoundary(
                        child: CustomPaint(
                          size: size,
                          painter: _AtlasPainter(
                            widget.atlas,
                            widget.allowed,
                            widget.highlight,
                            widget.incorrect,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                PositionedDirectional(
                  bottom: 4,
                  end: 4,
                  child: Material(
                    color: Palette.paper,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          onPressed: () => _zoom(1.55),
                          tooltip: 'تكبير الخريطة',
                          icon: const Icon(Icons.add),
                        ),
                        IconButton(
                          onPressed: () => _zoom(1 / 1.55),
                          tooltip: 'تصغير الخريطة',
                          icon: const Icon(Icons.remove),
                        ),
                        IconButton(
                          onPressed: _placeCamera,
                          tooltip: 'إعادة توسيط الخريطة',
                          icon: const Icon(Icons.center_focus_strong),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    ),
  );
}

const _sea = Color(0xffdcefee);

class _Projection {
  _Projection(Size size)
    : unit = math.min(size.width / 360, size.height / 180),
      center = size.center(Offset.zero);

  final double unit;
  final Offset center;

  Offset project(Offset world) =>
      center + (world - const Offset(180, 90)) * unit;
  Offset unproject(Offset scene) =>
      (scene - center) / unit + const Offset(180, 90);

  void apply(Canvas canvas) {
    final origin = project(Offset.zero);
    canvas.translate(origin.dx, origin.dy);
    canvas.scale(unit);
  }
}

class _AtlasPainter extends CustomPainter {
  const _AtlasPainter(this.atlas, this.allowed, this.highlight, this.incorrect);

  final WorldAtlas atlas;
  final Set<String>? allowed;
  final String? highlight;
  final String? incorrect;

  @override
  void paint(Canvas canvas, Size size) {
    _Projection(size).apply(canvas);
    final grid = Paint()
      ..color = const Color(0xffbbdcd8)
      ..strokeWidth = .16;
    for (var x = 30.0; x < 360; x += 30) {
      canvas.drawLine(Offset(x, 0), Offset(x, 180), grid);
    }
    for (var y = 30.0; y < 180; y += 30) {
      canvas.drawLine(Offset(0, y), Offset(360, y), grid);
    }

    final fill = Paint();
    final border = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = .22
      ..color = const Color(0xff968875);
    for (final feature in atlas.features) {
      final id = feature.id;
      fill.color = id == null || (allowed != null && !allowed!.contains(id))
          ? const Color(0xffd5d8cf)
          : const Color(0xffeddfb9);
      canvas.drawPath(feature.path, fill);
      canvas.drawPath(feature.path, border);
    }
    for (final feature in atlas.countries.values) {
      final id = feature.id;
      if (id == highlight || id == incorrect) {
        fill.color = id == highlight ? Palette.turquoise : Palette.coral;
        canvas.drawPath(feature.path, fill);
        canvas.drawPath(feature.path, border);
        canvas.drawCircle(feature.anchor, .76, fill);
      } else if (feature.tiny && (allowed == null || allowed!.contains(id))) {
        fill.color = Palette.tealInk;
        canvas.drawCircle(feature.anchor, .50, fill);
      }
    }
  }

  @override
  bool shouldRepaint(_AtlasPainter oldDelegate) =>
      atlas != oldDelegate.atlas ||
      allowed != oldDelegate.allowed ||
      highlight != oldDelegate.highlight ||
      incorrect != oldDelegate.incorrect;
}

class CountryOutline extends StatelessWidget {
  const CountryOutline({super.key, required this.feature, this.revealLabel});

  final MapFeature feature;
  final String? revealLabel;

  @override
  Widget build(BuildContext context) => Semantics(
    label: revealLabel ?? 'رسم حدود الدولة في السؤال',
    image: true,
    child: SizedBox(
      width: 205,
      height: 125,
      child: CustomPaint(painter: _OutlinePainter(feature)),
    ),
  );
}

class _OutlinePainter extends CustomPainter {
  const _OutlinePainter(this.feature);
  final MapFeature feature;

  @override
  void paint(Canvas canvas, Size size) {
    final bounds = feature.outlineBounds;
    final scale = math.min(
      (size.width - 18) / bounds.width,
      (size.height - 18) / bounds.height,
    );
    final middle = size.center(Offset.zero);
    canvas.translate(
      middle.dx - bounds.center.dx * scale,
      middle.dy - bounds.center.dy * scale,
    );
    canvas.scale(scale);
    canvas.drawPath(feature.outline, Paint()..color = Palette.tealInk);
    canvas.drawPath(
      feature.outline,
      Paint()
        ..color = Palette.navy
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.1 / scale,
    );
  }

  @override
  bool shouldRepaint(_OutlinePainter oldDelegate) =>
      feature != oldDelegate.feature;
}
