import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import '../models/diary_entry.dart';
import '../providers/diary_provider.dart';
import '../providers/trip_provider.dart';

class RecapScreen extends ConsumerStatefulWidget {
  const RecapScreen({super.key});

  @override
  ConsumerState<RecapScreen> createState() => _RecapScreenState();
}

class _RecapScreenState extends ConsumerState<RecapScreen>
    with TickerProviderStateMixin {
  late final AnimationController _fadeInController;
  final Map<String, Uint8List> _photoBytesCache = {};

  static const _moods = <({String emoji, String label})>[
    (emoji: '😌', label: 'Calm'),
    (emoji: '🤩', label: 'Excited'),
    (emoji: '😴', label: 'Tired'),
    (emoji: '⚡', label: 'Energetic'),
    (emoji: '🌌', label: 'Mystic'),
    (emoji: '🧠', label: 'Focused'),
    (emoji: '😊', label: 'Happy'),
    (emoji: '😮', label: 'Amazed'),
  ];

  @override
  void initState() {
    super.initState();
    _fadeInController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..forward();
  }

  @override
  void dispose() {
    _fadeInController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final diaryMap = ref.watch(diaryProvider);
    final trip = ref.watch(tripProvider);
    final recordedCount = diaryMap.length;

    return Scaffold(
      backgroundColor: const Color(0xFF020408),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white70),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'ANNUAL RECAP',
          style: GoogleFonts.spaceMono(
            fontSize: 13,
            color: Colors.white.withOpacity(0.5),
            letterSpacing: 2,
          ),
        ),
        centerTitle: true,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 430),
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(recordedCount, trip.planet.color),
                const SizedBox(height: 40),
                _buildPlanetStats(diaryMap),
                const SizedBox(height: 40),
                _buildMoodDistribution(diaryMap),
                const SizedBox(height: 40),
                _buildQuestStats(diaryMap),
                const SizedBox(height: 40),
                _buildMoments(diaryMap),
                const SizedBox(height: 60),
                _buildSummary(recordedCount, diaryMap),
                const SizedBox(height: 80),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(int recorded, Color accentColor) {
    final progress = (recorded / 365).clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'MISSION COMPLETE',
          style: GoogleFonts.spaceMono(
            fontSize: 12,
            color: const Color(0xFFFFD246).withOpacity(0.6),
            letterSpacing: 3,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '2025 Planet Journey Recap',
          style: GoogleFonts.spaceMono(
            fontSize: 22,
            color: Colors.white.withOpacity(0.9),
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '珥?湲곕줉 ?쇱닔',
              style: GoogleFonts.spaceMono(color: Colors.white54, fontSize: 12),
            ),
            Text(
              '$recorded / 365 DAY',
              style: GoogleFonts.spaceMono(
                color: const Color(0xFFFFD246),
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 8,
            backgroundColor: Colors.white.withOpacity(0.08),
            valueColor: AlwaysStoppedAnimation<Color>(accentColor),
          ),
        ),
      ],
    );
  }

  Widget _buildPlanetStats(Map<int, DiaryEntry> diaryMap) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('?됱꽦蹂?湲곕줉 ?듦퀎'),
        const SizedBox(height: 16),
        ...kPlanets.map((p) {
          final entries = diaryMap.values.where((e) {
            return e.tripDay >= p.startDay && e.tripDay < p.startDay + p.days;
          }).toList();
          
          final recCount = entries.length;
          final progress = (recCount / p.days).clamp(0.0, 1.0);
          
          // ???媛먯젙 怨꾩궛
          String topEmoji = '-';
          if (entries.isNotEmpty) {
            final moodCounts = <int, int>{};
            for (final e in entries) {
              moodCounts[e.moodIndex] = (moodCounts[e.moodIndex] ?? 0) + 1;
            }
            final topMoodIndex = moodCounts.entries
                .reduce((a, b) => a.value > b.value ? a : b)
                .key;
            topEmoji = _moods[topMoodIndex.clamp(0, 7)].emoji;
          }

          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: p.color),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(p.name, style: GoogleFonts.spaceMono(fontSize: 13, color: Colors.white70)),
                          Text('$recCount / ${p.days}d', style: GoogleFonts.spaceMono(fontSize: 11, color: Colors.white38)),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(2),
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 3,
                          backgroundColor: Colors.white.withOpacity(0.05),
                          valueColor: AlwaysStoppedAnimation<Color>(p.color.withOpacity(0.6)),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 20),
                Text(topEmoji, style: const TextStyle(fontSize: 18)),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildMoodDistribution(Map<int, DiaryEntry> diaryMap) {
    final counts = List.generate(8, (index) => 0);
    for (final e in diaryMap.values) {
      if (e.moodIndex >= 0 && e.moodIndex < 8) {
        counts[e.moodIndex]++;
      }
    }
    final maxVal = counts.reduce(math.max);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('媛먯젙 遺꾪룷'),
        const SizedBox(height: 20),
        SizedBox(
          height: 200,
          child: CustomPaint(
            size: Size.infinite,
            painter: _MoodBarPainter(counts: counts, maxVal: maxVal, moods: _moods),
          ),
        ),
      ],
    );
  }

  Widget _buildQuestStats(Map<int, DiaryEntry> diaryMap) {
    int totalQuests = 0;
    int completedQuests = 0;
    
    final planetCompletion = <String, double>{};

    for (final p in kPlanets) {
      int pTotal = p.days * 3;
      int pDone = 0;
      final entries = diaryMap.values.where((e) => e.tripDay >= p.startDay && e.tripDay < p.startDay + p.days);
      for (final e in entries) {
        pDone += e.questDone.where((q) => q).length;
      }
      totalQuests += pTotal;
      completedQuests += pDone;
      planetCompletion[p.name] = (pDone / pTotal).clamp(0.0, 1.0);
    }

    final totalRate = totalQuests > 0 ? (completedQuests / totalQuests) : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('?섏뒪???듦퀎'),
        const SizedBox(height: 24),
        Row(
          children: [
            SizedBox(
              width: 100,
              height: 100,
              child: CustomPaint(
                painter: _CircleChartPainter(progress: totalRate),
                child: Center(
                  child: Text(
                    '${(totalRate * 100).toInt()}%',
                    style: GoogleFonts.spaceMono(
                      color: const Color(0xFFFFD246),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 30),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Overall Quest Completion', style: GoogleFonts.spaceMono(color: Colors.white70, fontSize: 13)),
                  const SizedBox(height: 4),
                  Text('$completedQuests missions completed', style: GoogleFonts.spaceMono(color: Colors.white38, fontSize: 11)),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMoments(Map<int, DiaryEntry> diaryMap) {
    final photoEntries = diaryMap.values
        .where((e) => e.photoPaths.isNotEmpty)
        .toList()
      ..sort((a, b) => b.tripDay.compareTo(a.tripDay));
    
    final recent6 = photoEntries.take(6).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('湲곗뼲???⑤뒗 ?쒓컙'),
        const SizedBox(height: 16),
        if (recent6.isEmpty)
          Container(
            height: 120,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.03),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                '?꾩쭅 ?ъ쭊 湲곕줉???놁뒿?덈떎.',
                style: GoogleFonts.spaceMono(color: Colors.white24, fontSize: 12),
              ),
            ),
          )
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: recent6.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
            ),
            itemBuilder: (context, index) {
              final e = recent6[index];
              return GestureDetector(
                onTap: () => context.push('/diary/${e.tripDay}'),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: _buildRecapImage(e.photoPaths.first),
                ),
              );
            },
          ),
      ],
    );
  }

  Future<Uint8List> _readPhotoBytes(String path) async {
    final cached = _photoBytesCache[path];
    if (cached != null) {
      return cached;
    }
    final bytes = await XFile(path).readAsBytes();
    _photoBytesCache[path] = bytes;
    return bytes;
  }

  Widget _buildRecapImage(String path) {
    if (kIsWeb) {
      return Image.network(
        path,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) =>
            const ColoredBox(color: Color(0xFF1a1a1a)),
      );
    }

    return FutureBuilder<Uint8List>(
      future: _readPhotoBytes(path),
      builder: (context, snap) {
        if (snap.hasError || !snap.hasData) {
          return const ColoredBox(color: Color(0xFF1a1a1a));
        }
        return Image.memory(
          snap.data!,
          fit: BoxFit.cover,
          gaplessPlayback: true,
          filterQuality: FilterQuality.low,
        );
      },
    );
  }

  Widget _buildSummary(int recorded, Map<int, DiaryEntry> diaryMap) {
    String topPlanet = '紐⑹꽦';
    if (diaryMap.isNotEmpty) {
      final pCounts = <String, int>{};
      for (final e in diaryMap.values) {
        final p = planetForDay(e.tripDay);
        pCounts[p.name] = (pCounts[p.name] ?? 0) + 1;
      }
      topPlanet = pCounts.entries.reduce((a, b) => a.value > b.value ? a : b).key;
    }

    int totalQ = 0;
    for (final e in diaryMap.values) {
      totalQ += e.questDone.where((q) => q).length;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _fadingText('?뱀떊? $recorded???숈븞 ?곗＜瑜??ы뻾?덉뒿?덈떎.', 0),
        const SizedBox(height: 12),
        _fadingText('媛???ㅻ옒 癒몃Ц ?됱꽦? $topPlanet?댁뿀?댁슂.', 1),
        const SizedBox(height: 12),
        _fadingText('珥?$totalQ媛쒖쓽 ?섏뒪?몃? ?꾨즺?덉뒿?덈떎.', 2),
      ],
    );
  }

  Widget _fadingText(String text, int index) {
    final start = 0.4 + (index * 0.2);
    final end = (start + 0.3).clamp(0.0, 1.0);
    
    return AnimatedBuilder(
      animation: _fadeInController,
      builder: (context, child) {
        final opacity = CurvedAnimation(
          parent: _fadeInController,
          curve: Interval(start, end, curve: Curves.easeIn),
        ).value;
        return Opacity(
          opacity: opacity,
          child: Transform.translate(
            offset: Offset(0, 10 * (1 - opacity)),
            child: child,
          ),
        );
      },
      child: Text(
        text,
        style: GoogleFonts.spaceMono(
          fontSize: 15,
          color: Colors.white.withOpacity(0.8),
          height: 1.5,
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: GoogleFonts.spaceMono(
        fontSize: 10,
        color: Colors.white.withOpacity(0.3),
        letterSpacing: 2,
      ),
    );
  }
}

class _MoodBarPainter extends CustomPainter {
  _MoodBarPainter({required this.counts, required this.maxVal, required this.moods});
  final List<int> counts;
  final int maxVal;
  final List<({String emoji, String label})> moods;

  @override
  void paint(Canvas canvas, Size size) {
    const barHeight = 12.0;
    final spacing = (size.height - (barHeight * 8)) / 7;
    final maxBarWidth = size.width - 80;

    for (int i = 0; i < 8; i++) {
      final y = i * (barHeight + spacing);
      final val = counts[i];
      final barWidth = maxVal > 0 ? (val / maxVal) * maxBarWidth : 0.0;
      final isMax = maxVal > 0 && val == maxVal;

      final paint = Paint()
        ..color = isMax ? const Color(0xFFFFD246) : Colors.white.withOpacity(0.15)
        ..style = PaintingStyle.fill;

      // 諛?洹몃━湲?
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(40, y, barWidth.toDouble(), barHeight),
          const Radius.circular(2),
        ),
        paint,
      );

      // ?대え吏 ?띿뒪???섏씤??(媛꾨왂??
      final tp = TextPainter(
        text: TextSpan(text: moods[i].emoji, style: const TextStyle(fontSize: 14)),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(10, y - 2));

      // ?섏튂
      final valTp = TextPainter(
        text: TextSpan(
          text: '$val',
          style: GoogleFonts.spaceMono(color: Colors.white38, fontSize: 10),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      valTp.paint(canvas, Offset(45 + barWidth, y - 1));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _CircleChartPainter extends CustomPainter {
  _CircleChartPainter({required this.progress});
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    const strokeWidth = 6.0;

    final bgPaint = Paint()
      ..color = Colors.white.withOpacity(0.05)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    final fgPaint = Paint()
      ..color = const Color(0xFFFFD246)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius - strokeWidth / 2, bgPaint);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius - strokeWidth / 2),
      -math.pi / 2,
      2 * math.pi * progress,
      false,
      fgPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

