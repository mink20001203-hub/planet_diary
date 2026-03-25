import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../providers/trip_provider.dart';

class SpaceMapScreen extends ConsumerStatefulWidget {
  const SpaceMapScreen({super.key});

  @override
  ConsumerState<SpaceMapScreen> createState() => _SpaceMapScreenState();
}

class _SpaceMapScreenState extends ConsumerState<SpaceMapScreen>
    with TickerProviderStateMixin {
  // 우주인 애니메이션
  late final AnimationController _driftController;
  late final Animation<double> _driftY;

  late final AnimationController _pulseController;
  late final Animation<double> _pulseOpacity;

  late final AnimationController _trailController;

  // 탭 전환 애니메이션
  late final AnimationController _expandController; // 700ms
  late final AnimationController _fadeController; // 300ms
  late final Animation<double> _fadeOpacity;

  int? _tappedPlanetIndex;
  bool _navigating = false;
  bool _navigateTriggered = false;

  static const _sunRadius = 18.0;
  static const _astronautW = 28.0;
  static const _astronautH = 42.0;

  // 행성 반지름(px)
  static const _planetRadii = <double>[
    12, // 수성
    16, // 금성
    17, // 지구
    14, // 화성
    32, // 목성
    28, // 토성
    22, // 천왕성
    22, // 해왕성
  ];

  // 12시부터 시계방향 고정 각(표준 좌표계 기준: 0rad=3시, 증가=반시계인데 여기서만 y↓라 화면에서는 시계처럼 움직임)
  static double _planetFixedAngleRad(int planetIndex) {
    return -math.pi / 2 + planetIndex * (math.pi / 4);
  }

  // 별 배경(고정 시드 42)
  static final List<_Star> _stars = _buildStars();

  static List<_Star> _buildStars() {
    final rng = math.Random(42);
    const sizes = <double>[0.4, 0.8, 1.2];

    const colors = <Color>[
      Color(0xFFF6F8FF), // 흰색
      Color(0xFFFFF3DF), // 아이보리
      Color(0xFFD8E8FF), // 청백
    ];

    final stars = <_Star>[];
    while (stars.length < 250) {
      final nx = rng.nextDouble();
      final ny = rng.nextDouble();

      // top-left -> bottom-right 대각선 근처에 밀도(1.4배)
      final distToDiagonal = (nx - ny).abs();
      final weight = 1.0 + 0.4 * math.max(0.0, (0.22 - distToDiagonal) / 0.22);
      final acceptProb = weight / 1.4; // ~[0.71..1.0]
      if (rng.nextDouble() > acceptProb) continue;

      stars.add(
        _Star(
          nx: nx,
          ny: ny,
          radius: sizes[rng.nextInt(sizes.length)],
          color: colors[rng.nextInt(colors.length)],
        ),
      );
    }
    return stars;
  }

  @override
  void initState() {
    super.initState();

    _driftController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat(reverse: true);
    _driftY = Tween<double>(begin: -3, end: 3).animate(
      CurvedAnimation(parent: _driftController, curve: Curves.easeInOutSine),
    );

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _pulseOpacity = Tween<double>(begin: 0.1, end: 0.4).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOutSine),
    );

    _trailController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();

    _expandController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
      value: 1,
    );
    _fadeOpacity = Tween<double>(begin: 1, end: 0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeOut),
    );

    // 0.6초(≈0.857) 시점에 이동 트리거
    _expandController.addListener(() {
      if (_navigateTriggered) return;
      if (_expandController.value >= 0.857 && mounted) {
        _navigateTriggered = true;
        context.go('/calendar');
      }
    });
  }

  @override
  void dispose() {
    _driftController.dispose();
    _pulseController.dispose();
    _trailController.dispose();
    _expandController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  int _effectiveTripDay(int rawTripDay) {
    // 스펙: 365일 초과 시 mod 365
    return ((rawTripDay - 1) % 365) + 1;
  }

  double _astronautAngleRad(int tripDayN) {
    // angle = ((tripDay - 1) / 365) * 2 * pi - (pi / 2)
    final t = (tripDayN - 1) / 365.0;
    return t * 2 * math.pi - math.pi / 2;
  }

  void _onPlanetTap(int planetIndex) {
    if (_navigating) return;
    _navigating = true;
    _tappedPlanetIndex = planetIndex;
    _navigateTriggered = false;

    _fadeController.reverse(from: 1);
    _expandController.forward(from: 0);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final trip = ref.watch(tripProvider);
    final tripDayN = _effectiveTripDay(trip.tripDay);
    final currentPlanetIndex0 =
        kPlanets.indexWhere((p) => p.name == trip.planet.name);
    final currentPlanetIndex = currentPlanetIndex0 >= 0 ? currentPlanetIndex0 : 0;

    return Scaffold(
      backgroundColor: const Color(0xFF020408),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final size = Size(constraints.maxWidth, constraints.maxHeight);
          final shortSide = math.min(size.width, size.height);

          final cx = size.width / 2;
          final cy = size.height / 2;
          final orbitRadius = shortSide * 0.38;

          final merged = Listenable.merge([
            _driftController,
            _pulseController,
            _trailController,
            _fadeController,
            _expandController,
          ]);

          return AnimatedBuilder(
            animation: merged,
            builder: (context, _) {
              final astroAngle = _astronautAngleRad(tripDayN);
              final astroBasePos = Offset(
                cx + orbitRadius * math.cos(astroAngle),
                cy + orbitRadius * math.sin(astroAngle),
              );

              final driftPos =
                  Offset(astroBasePos.dx, astroBasePos.dy + _driftY.value);

              final inward = Offset(
                (cx - driftPos.dx) / orbitRadius,
                (cy - driftPos.dy) / orbitRadius,
              );
              final lightAlignment = Alignment(
                inward.dx.clamp(-1.0, 1.0),
                inward.dy.clamp(-1.0, 1.0),
              );

              final targetAngle = _planetFixedAngleRad(currentPlanetIndex);
              final delta = _normalizeAngle(targetAngle - astroAngle);
              final tiltRad = delta * 0.25;

              final dashOffsetPx = _trailController.value * 10;
              final expandedT =
                  Curves.easeInCubic.transform(_expandController.value);
              final colorAlpha = expandedT * 0.8;

              return Stack(
                clipBehavior: Clip.none,
                children: [
                  // base layer fade-out (나머지 요소)
                  Positioned.fill(
                    child: Opacity(
                      opacity: _fadeOpacity.value,
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: CustomPaint(
                              painter: _StarfieldPainter(_stars),
                            ),
                          ),
                          Positioned.fill(
                            child: CustomPaint(
                              painter: _SolarSystemPainter(
                                cx: cx,
                                cy: cy,
                                orbitRadius: orbitRadius,
                                sunRadius: _sunRadius,
                                tripDayN: tripDayN,
                                astroAngleRad: astroAngle,
                                driftPos: driftPos,
                                tiltRad: tiltRad,
                                lightAlignment: lightAlignment,
                                planetRadii: _planetRadii,
                                planetColors:
                                    kPlanets.map((e) => e.color).toList(),
                                currentPlanetIndex: currentPlanetIndex,
                                currentPlanetPulseOpacity:
                                    _pulseOpacity.value,
                                dashOffset: dashOffsetPx,
                              ),
                            ),
                          ),
                          _buildHud(context, trip, size, cx, cy, shortSide),
                          ..._buildPlanetHitAndLabels(size, orbitRadius, cx, cy),
                        ],
                      ),
                    ),
                  ),

                  // expansion overlay
                  if (_tappedPlanetIndex != null)
                    _buildExpansionOverlay(
                      size: size,
                      orbitRadius: orbitRadius,
                      cx: cx,
                      cy: cy,
                      planetIndex: _tappedPlanetIndex!,
                      expandedT: expandedT,
                      colorAlpha: colorAlpha,
                      expandedScale: _calcExpandedScale(
                        size,
                        _planetRadii[_tappedPlanetIndex!],
                      ),
                    ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  double _calcExpandedScale(Size size, double planetR) {
    // 행성 반지름 대비 화면 최대 변을 덮도록
    final maxDim = math.max(size.width, size.height);
    return (maxDim * 1.15) / (2 * planetR);
  }

  List<Widget> _buildPlanetHitAndLabels(
    Size size,
    double orbitRadius,
    double cx,
    double cy,
  ) {
    // hit size: planet painter와 동일 radius
    final labelStyle = GoogleFonts.spaceMono(
      fontSize: 8,
      color: Colors.white.withValues(alpha: 0.4),
    );

    final widgets = <Widget>[];
    for (var i = 0; i < kPlanets.length; i++) {
      final r = _planetRadii[i];
      final angle = _planetFixedAngleRad(i);
      final planetCenter = Offset(
        cx + orbitRadius * math.cos(angle),
        cy + orbitRadius * math.sin(angle),
      );

      widgets.add(
        Positioned(
          left: planetCenter.dx - r,
          top: planetCenter.dy - r,
          width: r * 2,
          height: r * 2,
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: () => _onPlanetTap(i),
          ),
        ),
      );

      widgets.add(
        Positioned(
          left: planetCenter.dx - 36,
          top: planetCenter.dy + r + 6,
          width: 72,
          child: Text(
            kPlanets[i].name,
            textAlign: TextAlign.center,
            style: labelStyle,
          ),
        ),
      );
    }
    return widgets;
  }

  Widget _buildExpansionOverlay({
    required Size size,
    required double orbitRadius,
    required double cx,
    required double cy,
    required int planetIndex,
    required double expandedT,
    required double colorAlpha,
    required double expandedScale,
  }) {
    final planet = kPlanets[planetIndex];
    final r = _planetRadii[planetIndex];
    final angle = _planetFixedAngleRad(planetIndex);
    final planetCenter = Offset(
      cx + orbitRadius * math.cos(angle),
      cy + orbitRadius * math.sin(angle),
    );

    return Stack(
      children: [
        // 화면 전체 행성색 덮기(전환)
        Positioned.fill(
          child: IgnorePointer(
            child: ColoredBox(
              color: planet.color.withOpacity(colorAlpha),
            ),
          ),
        ),
        Positioned(
          left: planetCenter.dx - r,
          top: planetCenter.dy - r,
          child: Transform.scale(
            alignment: Alignment.center,
            scale: 1 + (expandedScale - 1) * expandedT,
            child: ClipOval(
              child: SizedBox(
                width: r * 2,
                height: r * 2,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CustomPaint(
                      painter: _PlanetBodyPainter(
                        baseColor: planet.color,
                        radius: r,
                        drawSaturnRings: planetIndex == 5,
                      ),
                    ),
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: planet.color.withOpacity(colorAlpha),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHud(
    BuildContext context,
    TripState trip,
    Size size,
    double cx,
    double cy,
    double shortSide,
  ) {
    final pad = shortSide * 0.05;
    final topPad = shortSide * 0.06;
    final bottomPad = shortSide * 0.05;
    final sunBelowTop = cy + _sunRadius + shortSide * 0.04;
    return Stack(
      children: [
        Positioned(
          left: pad,
          top: topPad,
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
          children: [
              Text(
                'MISSION LOG',
                style: GoogleFonts.spaceMono(
                  fontSize: 9,
                  color: const Color(0xFFFFD246).withValues(alpha: 0.5),
                  letterSpacing: 2.5,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'DAY ${trip.tripDay} / 365',
                style: GoogleFonts.spaceMono(
                fontSize: 20,
                  color: Colors.white.withValues(alpha: 0.88),
                ),
              ),
            ],
          ),
        ),
        Positioned(
          right: pad,
          top: topPad,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${trip.planet.name.toUpperCase()} SECTOR',
                style: GoogleFonts.spaceMono(
                  fontSize: 11,
                  color: const Color(0xFFC8A97A).withValues(alpha: 0.8),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '체류 ${trip.stayDay}일차 · ${trip.remainDays}일 남음',
                style: GoogleFonts.spaceMono(
                  fontSize: 10,
                  color: Colors.white.withValues(alpha: 0.3),
                ),
              ),
            ],
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          top: sunBelowTop,
          child: Center(
            child: Text(
              '2025.01.01 → 2025.12.31',
              style: GoogleFonts.spaceMono(
                fontSize: 8,
                color: Colors.white.withValues(alpha: 0.2),
              ),
            ),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: bottomPad,
          child: Center(
            child: Text(
              'tap a planet',
              style: GoogleFonts.spaceMono(
                fontSize: 10,
                color: Colors.white.withValues(alpha: 0.2),
                letterSpacing: 2,
              ),
            ),
          ),
        ),
      ],
    );
  }

  double _normalizeAngle(double rad) {
    final twopi = 2 * math.pi;
    var x = rad % twopi;
    if (x > math.pi) x -= twopi;
    if (x < -math.pi) x += twopi;
    return x;
  }
}

class _Star {
  const _Star({
    required this.nx,
    required this.ny,
    required this.radius,
    required this.color,
  });

  final double nx;
  final double ny;
  final double radius;
  final Color color;
}

class _StarfieldPainter extends CustomPainter {
  _StarfieldPainter(this.stars);

  final List<_Star> stars;

  @override
  void paint(Canvas canvas, Size size) {
    for (final s in stars) {
      canvas.drawCircle(
        Offset(s.nx * size.width, s.ny * size.height),
        s.radius,
        Paint()..color = s.color,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _StarfieldPainter oldDelegate) => false;
}

class _SolarSystemPainter extends CustomPainter {
  _SolarSystemPainter({
    required this.cx,
    required this.cy,
    required this.orbitRadius,
    required this.sunRadius,
    required this.tripDayN,
    required this.astroAngleRad,
    required this.driftPos,
    required this.tiltRad,
    required this.lightAlignment,
    required this.planetRadii,
    required this.planetColors,
    required this.currentPlanetIndex,
    required this.currentPlanetPulseOpacity,
    required this.dashOffset,
  });

  final double cx;
  final double cy;
  final double orbitRadius;
  final double sunRadius;

  final int tripDayN;
  final double astroAngleRad;

  final Offset driftPos;
  final double tiltRad;
  final Alignment lightAlignment;

  final List<double> planetRadii;
  final List<Color> planetColors;
  final int currentPlanetIndex;
  final double currentPlanetPulseOpacity;
  final double dashOffset;

  static double _planetFixedAngleRad(int planetIndex) {
    return -math.pi / 2 + planetIndex * (math.pi / 4);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(cx, cy);

    // 궤도 원
    final orbitPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5
      ..color = Colors.white.withValues(alpha: 0.06);
    canvas.drawCircle(center, orbitRadius, orbitPaint);

    // 점선 흐름 애니메이션: dashOffset 기반
    final day1Angle = -math.pi / 2;
    final day365Angle =
        ((365 - 1) / 365.0) * 2 * math.pi - math.pi / 2;

    final pastSweep = (astroAngleRad - day1Angle)
        .clamp(0.0, (day365Angle - day1Angle).abs());
    final futureSweep =
        (day365Angle - astroAngleRad).clamp(0.0, (day365Angle - day1Angle).abs());

    if (pastSweep > 0.0001) {
      _drawDashedArc(
        canvas: canvas,
        center: center,
        radius: orbitRadius,
        startAngle: day1Angle,
        sweepAngle: pastSweep,
        color: Colors.white.withValues(alpha: 0.35),
        strokeWidth: 1.5,
        dashArray: const [6.0, 4.0],
        dashOffset: dashOffset,
      );
    }
    if (futureSweep > 0.0001) {
      _drawDashedArc(
        canvas: canvas,
        center: center,
        radius: orbitRadius,
        startAngle: astroAngleRad,
        sweepAngle: futureSweep,
        color: Colors.white.withValues(alpha: 0.08),
        strokeWidth: 0.8,
        dashArray: const [3.0, 6.0],
        dashOffset: dashOffset,
      );
    }

    // 태양
    final sunRect = Rect.fromCircle(center: center, radius: sunRadius);
    final sunPaint = Paint()
      ..shader = RadialGradient(
        center: Alignment.center,
        radius: 1,
        colors: [
          Colors.white.withOpacity(0.95),
          const Color(0xFFF1D18A).withOpacity(0.85),
          Colors.transparent,
        ],
        stops: const [0.0, 0.55, 1.0],
      ).createShader(sunRect);
    canvas.drawCircle(center, sunRadius, sunPaint);

    // 행성 + 토성 고리
    for (var i = 0; i < 8; i++) {
      final angle = _planetFixedAngleRad(i);
      final r = planetRadii[i];
      final planetCenter = Offset(
        cx + orbitRadius * math.cos(angle),
        cy + orbitRadius * math.sin(angle),
      );
      _drawPlanet(canvas, planetCenter, r, planetColors[i], i == 5);
    }

    // 현재 행성 펄스 링
    final currentAngle = _planetFixedAngleRad(currentPlanetIndex);
    final currentCenter = Offset(
      cx + orbitRadius * math.cos(currentAngle),
      cy + orbitRadius * math.sin(currentAngle),
    );
    final pulsePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = planetColors[currentPlanetIndex]
          .withOpacity(currentPlanetPulseOpacity);
    canvas.drawCircle(currentCenter, planetRadii[currentPlanetIndex] + 4, pulsePaint);

    // 우주인
    _drawAstronaut(
      canvas: canvas,
      center: driftPos,
      tiltRad: tiltRad,
      lightAlignment: lightAlignment,
    );
  }

  void _drawPlanet(
    Canvas canvas,
    Offset center,
    double radius,
    Color baseColor,
    bool drawSaturnRings,
  ) {
    final bounds = Rect.fromCircle(center: center, radius: radius);

    final bodyPaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.4, -0.4),
        radius: 1.05,
        colors: [
          Color.lerp(baseColor, Colors.white, 0.38)!,
          baseColor,
          const Color(0xFF050710),
        ],
        stops: const [0.0, 0.48, 1.0],
      ).createShader(bounds);
    canvas.drawCircle(center, radius, bodyPaint);

    final terminatorPaint = Paint()
      ..shader = LinearGradient(
        begin: const Alignment(-0.55, -0.55),
        end: const Alignment(0.75, 0.75),
        colors: [
          Colors.transparent,
          const Color(0x66050710),
          const Color(0xFF050710),
        ],
        stops: const [0.32, 0.58, 1.0],
      ).createShader(bounds);
    canvas.drawCircle(center, radius, terminatorPaint);

    if (drawSaturnRings) {
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.scale(1, 0.25);
      final ringPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1.2, radius * 0.06)
        ..color = const Color(0xFFE8C86A).withOpacity(0.4);
      final ringW = radius * 3.0;
      canvas.drawOval(
        Rect.fromCenter(center: Offset.zero, width: ringW, height: ringW),
        ringPaint,
      );
      canvas.restore();
    }
  }

  void _drawAstronaut({
    required Canvas canvas,
    required Offset center,
    required double tiltRad,
    required Alignment lightAlignment,
  }) {
    final w = _SpaceMapScreenState._astronautW;
    final h = _SpaceMapScreenState._astronautH;

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(tiltRad);

    // 광원: 태양 방향 기준 => 중심(태양) 쪽으로 하이라이트
    final suitPaint = Paint()
      ..shader = RadialGradient(
        center: lightAlignment,
        radius: 1,
        colors: [
          Colors.white.withOpacity(1),
          Colors.white.withOpacity(0.7),
          const Color(0xFFECECEC).withOpacity(0.85),
        ],
        stops: const [0.0, 0.55, 1.0],
      ).createShader(
        Rect.fromCenter(center: Offset.zero, width: w, height: h),
      );

    final helmetR = w * 0.22;
    final helmetCenter = Offset(0, -h * 0.12);
    canvas.drawCircle(helmetCenter, helmetR, suitPaint);

    // 바이저(황색 반사 → 어두운 내부)
    final visorRect = Rect.fromCenter(
      center: helmetCenter.translate(0, -h * 0.03),
      width: w * 0.42,
      height: h * 0.22,
    );
    final visorPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          const Color(0xFFFFD280).withOpacity(0.6),
          const Color(0xFF1A1000).withOpacity(0.92),
        ],
      ).createShader(visorRect);
    canvas.drawOval(visorRect, visorPaint);

    final bodyRect = Rect.fromCenter(
      center: Offset(0, h * 0.10),
      width: w * 0.64,
      height: h * 0.44,
    );
    final bodyR = w * 0.12;
    canvas.drawRRect(
      RRect.fromRectAndRadius(bodyRect, Radius.circular(bodyR)),
      suitPaint,
    );

    // 팔 2개
    final armY = h * 0.02;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(-w * 0.38, armY),
          width: w * 0.18,
          height: h * 0.22,
        ),
        Radius.circular(w * 0.06),
      ),
      suitPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(w * 0.38, armY),
          width: w * 0.18,
          height: h * 0.22,
        ),
        Radius.circular(w * 0.06),
      ),
      suitPaint,
    );

    canvas.restore();
  }

  void _drawDashedArc({
    required Canvas canvas,
    required Offset center,
    required double radius,
    required double startAngle,
    required double sweepAngle,
    required Color color,
    required double strokeWidth,
    required List<double> dashArray, // [on, off]
    required double dashOffset,
  }) {
    final on = dashArray[0];
    final off = dashArray[1];
    final cycle = on + off;

    final rect = Rect.fromCircle(center: center, radius: radius);
    final path = Path()..addArc(rect, startAngle, sweepAngle);

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = strokeWidth
      ..color = color;

    for (final metric in path.computeMetrics()) {
      final total = metric.length;
      if (total <= 0) continue;

      final phase = (dashOffset % cycle + cycle) % cycle;
      double dist = 0;
      bool drawOn = true;

      if (phase < on) {
        // 첫 on 구간 중 phase만큼 스킵
        final firstLen = on - phase;
        final end = math.min(total, dist + firstLen);
        if (end > dist) {
          canvas.drawPath(metric.extractPath(dist, end), paint);
        }
        dist = end;
        drawOn = false;
      } else {
        // phase가 off 안에 있는 경우: off 나머지 스킵 후 on부터 시작
        final offPhase = phase - on;
        dist = off - offPhase;
        drawOn = true;
      }

      while (dist < total) {
        if (drawOn) {
          final end = math.min(total, dist + on);
          if (end > dist) {
            canvas.drawPath(metric.extractPath(dist, end), paint);
          }
          dist = end;
          drawOn = false;
        } else {
          dist = math.min(total, dist + off);
          drawOn = true;
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _SolarSystemPainter oldDelegate) {
    // 애니메이션 값이 바뀔 때만 repaint
    return oldDelegate.driftPos != driftPos ||
        oldDelegate.tiltRad != tiltRad ||
        oldDelegate.currentPlanetPulseOpacity != currentPlanetPulseOpacity ||
        oldDelegate.dashOffset != dashOffset;
  }
}

class _PlanetBodyPainter extends CustomPainter {
  const _PlanetBodyPainter({
    required this.baseColor,
    required this.radius,
    required this.drawSaturnRings,
  });

  final Color baseColor;
  final double radius;
  final bool drawSaturnRings;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(radius, radius);
    final bounds = Rect.fromCircle(center: center, radius: radius);

    final bodyPaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.4, -0.4),
        radius: 1.05,
        colors: [
          Color.lerp(baseColor, Colors.white, 0.38)!,
          baseColor,
          const Color(0xFF050710),
        ],
        stops: const [0.0, 0.48, 1.0],
      ).createShader(bounds);
    canvas.drawCircle(center, radius, bodyPaint);

    final terminatorPaint = Paint()
      ..shader = LinearGradient(
        begin: const Alignment(-0.55, -0.55),
        end: const Alignment(0.75, 0.75),
        colors: [
          Colors.transparent,
          const Color(0x66050710),
          const Color(0xFF050710),
        ],
        stops: const [0.32, 0.58, 1.0],
      ).createShader(bounds);
    canvas.drawCircle(center, radius, terminatorPaint);

    if (drawSaturnRings) {
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.scale(1, 0.25);
      final ringPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1.2, radius * 0.06)
        ..color = const Color(0xFFE8C86A).withOpacity(0.4);
      final ringW = radius * 3.0;
      canvas.drawOval(
        Rect.fromCenter(center: Offset.zero, width: ringW, height: ringW),
        ringPaint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _PlanetBodyPainter oldDelegate) {
    return oldDelegate.baseColor != baseColor ||
        oldDelegate.radius != radius ||
        oldDelegate.drawSaturnRings != drawSaturnRings;
  }
}

