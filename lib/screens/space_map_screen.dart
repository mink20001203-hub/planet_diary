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
  // 애니메이션 컨트롤러
  late final AnimationController _driftController;
  late final Animation<double> _driftY;

  late final AnimationController _pulseController;
  late final Animation<double> _pulseOpacity;

  late final AnimationController _trailController;

  // 느린 공전 애니메이션 (120초)
  late final AnimationController _orbitController;

  // 탭 전환 애니메이션
  late final AnimationController _expandController; 
  late final AnimationController _fadeController; 
  late final Animation<double> _fadeOpacity;

  int? _tappedPlanetIndex;
  bool _navigating = false;
  bool _navigateTriggered = false;

  static const _sunRadius = 24.0;
  static const _astronautW = 28.0;
  static const _astronautH = 42.0;

  // 행성 기본 반지름(px)
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

  static double _planetFixedAngleRad(int planetIndex) {
    // 기본 배치 각도
    return -math.pi / 2 + planetIndex * (math.pi / 4);
  }

  static final List<_Star> _stars = _buildStars();

  static List<_Star> _buildStars() {
    final rng = math.Random(42);
    const sizes = <double>[0.4, 0.8, 1.2];
    const colors = <Color>[
      Color(0xFFF6F8FF),
      Color(0xFFFFF3DF),
      Color(0xFFD8E8FF),
    ];

    final stars = <_Star>[];
    while (stars.length < 300) {
      stars.add(
        _Star(
          nx: rng.nextDouble(),
          ny: rng.nextDouble(),
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

    // 120초 느린 공전
    _orbitController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 120),
    )..repeat();

    _expandController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
      value: 0, // 0에서 시작해야 Tween(1, 0)에 의해 1(완전 불투명)이 됨
    );
    _fadeOpacity = Tween<double>(begin: 1, end: 0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeOut),
    );

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
    _orbitController.dispose();
    _expandController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  int _effectiveTripDay(int rawTripDay) {
    return ((rawTripDay - 1) % 365) + 1;
  }

  double _astronautAngleRad(int tripDayN) {
    final t = (tripDayN - 1) / 365.0;
    return t * 2 * math.pi - math.pi / 2;
  }

  void _onPlanetTap(int planetIndex) {
    if (_navigating) return;
    _navigating = true;
    _tappedPlanetIndex = planetIndex;
    _navigateTriggered = false;

    _fadeController.forward(from: 0); // 페이드 아웃 시작
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

    final merged = Listenable.merge([
      _driftController,
      _pulseController,
      _trailController,
      _orbitController,
      _fadeController,
      _expandController,
    ]);

    return Scaffold(
      backgroundColor: const Color(0xFF020408),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final size = Size(constraints.maxWidth, constraints.maxHeight);
          final cx = size.width / 2;
          final cy = size.height / 2;
          final shortSide = math.min(size.width, size.height);
          final orbitRadius = shortSide * 0.42;

          return AnimatedBuilder(
            animation: merged,
            builder: (context, _) {
              final expandedT = Curves.easeInCubic.transform(_expandController.value);
              final colorAlpha = expandedT * 0.8;

              return Stack(
                clipBehavior: Clip.none,
                children: [
                  // Base Layer: Map and Stars
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
                                tripDayN: tripDayN,
                                astroAngleRad: _astronautAngleRad(tripDayN),
                                driftY: _driftY.value,
                                orbitOffsetRad: _orbitController.value * 2 * math.pi,
                                currentPlanetIndex: currentPlanetIndex,
                                currentPlanetPulseOpacity: _pulseOpacity.value,
                                dashOffset: _trailController.value * 10,
                                planetColors: kPlanets.map((e) => e.color).toList(),
                                planetRadii: _planetRadii,
                                sunRadius: _sunRadius,
                              ),
                            ),
                          ),
                          _buildHud(context, trip, size, cx, cy, shortSide),
                          ..._buildPlanetHitAndLabels(size, orbitRadius, cx, cy),
                        ],
                      ),
                    ),
                  ),

                  // Expansion Overlay (When planet is tapped)
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
    final maxDim = math.max(size.width, size.height);
    return (maxDim * 1.25) / (2 * planetR);
  }

  List<Widget> _buildPlanetHitAndLabels(
    Size size,
    double orbitRadius,
    double cx,
    double cy,
  ) {
    final orbitOffset = _orbitController.value * 2 * math.pi;
    final labelStyle = GoogleFonts.spaceMono(
      fontSize: 8,
      color: Colors.white.withValues(alpha: 0.4),
    );

    final widgets = <Widget>[];
    for (var i = 0; i < kPlanets.length; i++) {
      final baseAngle = _planetFixedAngleRad(i);
      final angle = baseAngle + orbitOffset;
      final depth = math.sin(angle);
      final r = _planetRadii[i] * (0.7 + depth * 0.3);
      
      final planetCenter = Offset(
        cx + orbitRadius * math.cos(angle),
        cy + orbitRadius * math.sin(angle) * 0.35,
      );

      // Hit area
      widgets.add(
        Positioned(
          left: planetCenter.dx - r - 12,
          top: planetCenter.dy - r - 12,
          width: r * 2 + 24,
          height: r * 2 + 24,
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: () => _onPlanetTap(i),
          ),
        ),
      );

      // Label
      widgets.add(
        Positioned(
          left: planetCenter.dx - 36,
          top: planetCenter.dy + r + 8,
          width: 72,
          child: Opacity(
            opacity: (0.5 + depth * 0.5).clamp(0.2, 1.0),
            child: Text(
              kPlanets[i].name,
              textAlign: TextAlign.center,
              style: labelStyle,
            ),
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
    // 확장 시에는 타원 궤도를 고려하지 않고 중앙으로 이동하는 느낌 유도를 위해 현재 위치 계산
    final orbitOffset = _orbitController.value * 2 * math.pi;
    final angle = _planetFixedAngleRad(planetIndex) + orbitOffset;
    final planetCenter = Offset(
      cx + orbitRadius * math.cos(angle),
      cy + orbitRadius * math.sin(angle) * 0.35,
    );

    return Stack(
      children: [
        Positioned.fill(
          child: IgnorePointer(
            child: ColoredBox(
              color: planet.color.withValues(alpha: colorAlpha),
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
                          color: planet.color.withValues(alpha: colorAlpha),
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
                  color: const Color(0xFFFFD246).withValues(alpha: 0.6),
                  letterSpacing: 2.5,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'DAY ${trip.tripDay} / 365',
                style: GoogleFonts.spaceMono(
                  fontSize: 20,
                  color: Colors.white.withValues(alpha: 0.9),
                  fontWeight: FontWeight.w600,
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
                  color: const Color(0xFFFFD246).withValues(alpha: 0.9),
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
                color: Colors.white.withValues(alpha: 0.3),
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
                color: Colors.white.withValues(alpha: 0.3),
                letterSpacing: 2,
              ),
            ),
          ),
        ),
      ],
    );
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
    required this.tripDayN,
    required this.astroAngleRad,
    required this.driftY,
    required this.orbitOffsetRad,
    required this.currentPlanetIndex,
    required this.currentPlanetPulseOpacity,
    required this.dashOffset,
    required this.planetColors,
    required this.planetRadii,
    required this.sunRadius,
  });

  final int tripDayN;
  final double astroAngleRad;
  final double driftY;
  final double orbitOffsetRad;
  final int currentPlanetIndex;
  final double currentPlanetPulseOpacity;
  final double dashOffset;
  final List<Color> planetColors;
  final List<double> planetRadii;
  final double sunRadius;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final center = Offset(cx, cy);
    final shortSide = math.min(size.width, size.height);
    final orbitRadius = shortSide * 0.42;

    // 1. 궤도 타원 그리기
    final orbitPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8
      ..color = Colors.white.withValues(alpha: 0.08);
    
    canvas.drawOval(
      Rect.fromCenter(
        center: center,
        width: orbitRadius * 2,
        height: orbitRadius * 2 * 0.35,
      ),
      orbitPaint,
    );

    // 2. 궤적(Arc) 그리기 (tripDay 기반)
    const day1Angle = -math.pi / 2;
    final sweepAngle = astroAngleRad - day1Angle;
    if (sweepAngle.abs() > 0.01) {
      final trailPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = Colors.white.withValues(alpha: 0.25);
      
      canvas.drawArc(
        Rect.fromCenter(
          center: center,
          width: orbitRadius * 2,
          height: orbitRadius * 2 * 0.35,
        ),
        day1Angle,
        sweepAngle,
        false,
        trailPaint,
      );
    }

    // 3. 렌더링 순서 계산 (Z-sorting: depth 작은 것부터)
    final renderList = <_RenderObject>[];

    // 태양 (center, z=0)
    renderList.add(_RenderObject(
      z: 0,
      type: _RenderType.sun,
      pos: center,
    ));

    // 행성들
    for (var i = 0; i < 8; i++) {
      final baseAngle = -math.pi / 2 + i * (math.pi / 4);
      final angle = baseAngle + orbitOffsetRad;
      final depth = math.sin(angle);
      
      final planetPos = Offset(
        cx + orbitRadius * math.cos(angle),
        cy + orbitRadius * math.sin(angle) * 0.35,
      );
      
      renderList.add(_RenderObject(
        z: depth,
        type: _RenderType.planet,
        pos: planetPos,
        index: i,
      ));
    }

    // 우주인
    final aDepth = math.sin(astroAngleRad);
    final aPos = Offset(
      cx + orbitRadius * math.cos(astroAngleRad),
      cy + orbitRadius * math.sin(astroAngleRad) * 0.35 + driftY,
    );
    renderList.add(_RenderObject(
      z: aDepth,
      type: _RenderType.astronaut,
      pos: aPos,
    ));

    // 정렬 (뒤 -> 앞)
    renderList.sort((a, b) => a.z.compareTo(b.z));

    // 4. 순서대로 그리기
    for (final obj in renderList) {
      switch (obj.type) {
        case _RenderType.sun:
          _drawSun(canvas, center);
          break;
        case _RenderType.planet:
          _drawPlanet3D(canvas, obj.pos, obj.z, obj.index!);
          break;
        case _RenderType.astronaut:
          _drawAstronaut3D(canvas, obj.pos, obj.z);
          break;
      }
    }
  }

  void _drawSun(Canvas canvas, Offset center) {
    final sunRect = Rect.fromCircle(center: center, radius: sunRadius);
    final sunPaint = Paint()
      ..shader = RadialGradient(
        center: Alignment.center,
        radius: 1,
        colors: [
          Colors.white.withValues(alpha: 0.95),
          const Color(0xFFF1D18A).withValues(alpha: 0.85),
          Colors.transparent,
        ],
        stops: const [0.0, 0.6, 1.0],
      ).createShader(sunRect);
    canvas.drawCircle(center, sunRadius, sunPaint);
  }

  void _drawPlanet3D(Canvas canvas, Offset pos, double depth, int index) {
    final baseR = planetRadii[index];
    final color = planetColors[index];
    
    // Depth 기반 스케일 및 투명도
    final r = baseR * (0.7 + depth * 0.3);
    final opacity = (0.5 + depth * 0.5).clamp(0.4, 1.0);
    
    // 셰이딩 강화: 앞쪽(Depth > 0)은 밝게, 뒤쪽(Depth < 0)은 어둡게
    Color renderColor;
    if (depth > 0) {
      renderColor = Color.lerp(color, Colors.white, depth * 0.3)!;
    } else {
      renderColor = Color.lerp(color, Colors.black, depth.abs() * 0.4)!;
    }

    final bounds = Rect.fromCircle(center: pos, radius: r);
    final bodyPaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.4, -0.4),
        radius: 1.05,
        colors: [
          Color.lerp(renderColor, Colors.white, 0.4)!,
          renderColor,
          const Color(0xFF050710),
        ],
        stops: const [0.0, 0.45, 1.0],
      ).createShader(bounds)
      ..color = Colors.white.withValues(alpha: opacity);
    
    canvas.drawCircle(pos, r, bodyPaint);

    // 토성 고리
    if (index == 5) {
      canvas.save();
      canvas.translate(pos.dx, pos.dy);
      // Depth에 따라 고리의 scaleY 변형 (앞쪽일수록 타원이 커짐)
      final ringScaleY = 0.25 + (depth + 1.0) * 0.05;
      canvas.scale(1.0, ringScaleY);
      
      final ringPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1.5, r * 0.08)
        ..color = const Color(0xFFE8C86A).withValues(alpha: 0.4 * opacity);
      
      final ringW = r * 3.2;
      canvas.drawOval(
        Rect.fromCenter(center: Offset.zero, width: ringW, height: ringW),
        ringPaint,
      );
      canvas.restore();
    }

    // 현재 선택된 행성 펄스
    if (index == currentPlanetIndex) {
      final pulsePaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0
        ..color = color.withValues(alpha: currentPlanetPulseOpacity * opacity);
      canvas.drawCircle(pos, r + 5, pulsePaint);
    }
  }

  void _drawAstronaut3D(Canvas canvas, Offset pos, double depth) {
    // 우주인 원근감 적용
    final scale = 0.6 + depth * 0.4;
    final opacity = (0.6 + depth * 0.4).clamp(0.3, 1.0);
    
    final w = _SpaceMapScreenState._astronautW * scale;
    final h = _SpaceMapScreenState._astronautH * scale;

    canvas.save();
    canvas.translate(pos.dx, pos.dy);
    
    // 광원: 중앙 태양 방향 (depth와 연동)
    final lightAlign = Alignment(0, depth > 0 ? -1 : 1);

    final suitPaint = Paint()
      ..shader = RadialGradient(
        center: lightAlign,
        radius: 1,
        colors: [
          Colors.white,
          const Color(0xFFECECEC).withValues(alpha: 0.8),
        ],
      ).createShader(Rect.fromCenter(center: Offset.zero, width: w, height: h));

    final paintWithAlpha = suitPaint..color = Colors.white.withValues(alpha: opacity);

    // 헬멧
    final helmetR = w * 0.22;
    final helmetCenter = Offset(0, -h * 0.12);
    canvas.drawCircle(helmetCenter, helmetR, paintWithAlpha);

    // 바이저
    final visorRect = Rect.fromCenter(
      center: helmetCenter.translate(0, -h * 0.03),
      width: w * 0.42,
      height: h * 0.22,
    );
    canvas.drawOval(visorRect, Paint()..color = const Color(0xFF1A1000).withValues(alpha: opacity * 0.9));

    // 몸체
    final bodyRect = Rect.fromCenter(center: Offset(0, h * 0.10), width: w * 0.64, height: h * 0.44);
    canvas.drawRRect(RRect.fromRectAndRadius(bodyRect, Radius.circular(w * 0.12)), paintWithAlpha);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _SolarSystemPainter oldDelegate) => true;
}

enum _RenderType { sun, planet, astronaut }

class _RenderObject {
  _RenderObject({required this.z, required this.type, required this.pos, this.index});
  final double z;
  final _RenderType type;
  final Offset pos;
  final int? index;
}

class _PlanetBodyPainter extends CustomPainter {
  const _PlanetBodyPainter({required this.baseColor, required this.radius, required this.drawSaturnRings});
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
        colors: [Color.lerp(baseColor, Colors.white, 0.38)!, baseColor, const Color(0xFF050710)],
        stops: const [0.0, 0.48, 1.0],
      ).createShader(bounds);
    canvas.drawCircle(center, radius, bodyPaint);
  }
  @override
  bool shouldRepaint(covariant _PlanetBodyPainter oldDelegate) => false;
}
