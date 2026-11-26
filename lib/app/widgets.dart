import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/geography.dart';
import 'theme.dart';

class Panel extends StatelessWidget {
  const Panel({
    super.key,
    required this.child,
    this.color = Palette.paper,
    this.padding = const EdgeInsets.all(16),
  });

  final Widget child;
  final Color color;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: color,
      border: Border.all(color: Palette.line),
      borderRadius: BorderRadius.circular(20),
      boxShadow: const [
        BoxShadow(
          color: Color(0x0a102f49),
          blurRadius: 12,
          offset: Offset(0, 4),
        ),
      ],
    ),
    child: Padding(padding: padding, child: child),
  );
}

class PageBody extends StatelessWidget {
  const PageBody({super.key, required this.children, this.scrollKey});

  final List<Widget> children;
  final PageStorageKey<String>? scrollKey;

  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: ListView(
      key: scrollKey,
      padding: const EdgeInsetsDirectional.fromSTEB(18, 12, 18, 26),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: children,
            ),
          ),
        ),
      ],
    ),
  );
}

class Stars extends StatelessWidget {
  const Stars(this.count, {super.key, this.size = 20});

  final int count;
  final double size;

  @override
  Widget build(BuildContext context) => Semantics(
    label: '${digits(count)} من ٣ نجوم',
    child: ExcludeSemantics(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(
          3,
          (index) => Icon(
            index < count ? Icons.star_rounded : Icons.star_border_rounded,
            color: index < count ? const Color(0xffa46900) : Palette.muted,
            size: size,
          ),
        ),
      ),
    ),
  );
}

class CountryFlag extends StatelessWidget {
  const CountryFlag({
    super.key,
    required this.country,
    required this.width,
    required this.height,
    this.reveal = true,
  });

  final Country country;
  final double width;
  final double height;
  final bool reveal;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: width,
    height: height,
    child: Image.asset(
      country.flag,
      fit: BoxFit.contain,
      matchTextDirection: false,
      filterQuality: FilterQuality.medium,
      cacheWidth: (width * MediaQuery.devicePixelRatioOf(context)).round(),
      semanticLabel: reveal ? 'علم ${country.name}' : 'علم السؤال',
      errorBuilder: (context, error, trace) => Semantics(
        label: 'تعذّر عرض العلم',
        child: const Icon(Icons.broken_image_outlined, color: Palette.redInk),
      ),
    ),
  );
}

class ChapterMedallion extends StatelessWidget {
  const ChapterMedallion(this.chapter, {super.key, this.size = 49});

  final Chapter chapter;
  final double size;

  @override
  Widget build(BuildContext context) {
    final (icon, color, ink) = switch (chapter) {
      Chapter.arab => (
        Icons.explore_outlined,
        const Color(0xffffe5ad),
        const Color(0xff794600),
      ),
      Chapter.africa => (
        Icons.terrain_rounded,
        const Color(0xffffe3d5),
        const Color(0xff8a3527),
      ),
      Chapter.asia => (
        Icons.landscape_outlined,
        const Color(0xffe9e3fc),
        const Color(0xff564888),
      ),
      Chapter.europe => (
        Icons.location_city_rounded,
        const Color(0xffdcefe9),
        Palette.tealInk,
      ),
      Chapter.northAmerica => (
        Icons.forest_outlined,
        const Color(0xffe7edda),
        const Color(0xff39552d),
      ),
      Chapter.southAmerica => (
        Icons.waves_rounded,
        const Color(0xffdceefa),
        const Color(0xff275b81),
      ),
      Chapter.oceania => (
        Icons.sailing_outlined,
        const Color(0xffdcf4f1),
        Palette.tealInk,
      ),
      Chapter.world => (
        Icons.public_rounded,
        const Color(0xfff7e7ba),
        Palette.navy,
      ),
    };
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(size * .29),
      ),
      child: Icon(icon, size: size * .53, color: ink),
    );
  }
}

class JourneyGlobe extends StatelessWidget {
  const JourneyGlobe({super.key});

  @override
  Widget build(BuildContext context) => const ExcludeSemantics(
    child: SizedBox.expand(child: CustomPaint(painter: _GlobePainter())),
  );
}

class _GlobePainter extends CustomPainter {
  const _GlobePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width * .53, size.height * .5);
    final radius = math.min(size.width, size.height) * .34;
    final globe = Rect.fromCircle(center: center, radius: radius);
    canvas.drawCircle(
      center,
      radius * 1.23,
      Paint()..color = const Color(0xff173d55),
    );
    canvas.drawCircle(
      center,
      radius * 1.1,
      Paint()..color = const Color(0xff19465d),
    );
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(-.35, -.4),
          colors: [Color(0xff218f8e), Color(0xff174f65)],
        ).createShader(globe),
    );
    final grid = Paint()
      ..color = const Color(0xff68cabb)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(-.27);
    canvas.drawCircle(Offset.zero, radius, grid);
    for (final width in [radius * .72, radius * 1.43]) {
      canvas.drawOval(
        Rect.fromCenter(center: Offset.zero, width: width, height: radius * 2),
        grid,
      );
    }
    final equator = radius * .42;
    final halfChord = math.sqrt(radius * radius - equator * equator);
    canvas.drawLine(Offset(-radius, 0), Offset(radius, 0), grid);
    canvas.drawLine(
      Offset(-halfChord, -equator),
      Offset(halfChord, -equator),
      grid,
    );
    canvas.drawLine(
      Offset(-halfChord, equator),
      Offset(halfChord, equator),
      grid,
    );
    final orbit = Path()
      ..addOval(
        Rect.fromCenter(
          center: Offset.zero,
          width: radius * 2.77,
          height: radius * 1.03,
        ),
      );
    final trail = Paint()
      ..color = Palette.gold
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.25;
    for (final metric in orbit.computeMetrics()) {
      for (var offset = 0.0; offset < metric.length; offset += 7) {
        canvas.drawPath(metric.extractPath(offset, offset + 3), trail);
      }
    }
    final pin = Offset(radius * .94, -radius * .4);
    canvas.drawCircle(pin, 8, Paint()..color = Palette.navy);
    canvas.drawCircle(pin, 4.5, Paint()..color = Palette.gold);
    canvas.restore();
    for (final point in [
      center + Offset(-radius * 1.02, -radius * 1.07),
      center + Offset(radius * 1.1, radius * .95),
      center + Offset(-radius * 1.25, radius * .78),
    ]) {
      canvas.drawLine(point.translate(-3, 0), point.translate(3, 0), grid);
      canvas.drawLine(point.translate(0, -3), point.translate(0, 3), grid);
    }
  }

  @override
  bool shouldRepaint(_GlobePainter oldDelegate) => false;
}
