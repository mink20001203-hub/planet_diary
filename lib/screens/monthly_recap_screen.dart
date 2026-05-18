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

class MonthlyRecapScreen extends ConsumerStatefulWidget {
  const MonthlyRecapScreen({
    super.key,
    required this.year,
    required this.month,
  });

  final int year;
  final int month;

  @override
  ConsumerState<MonthlyRecapScreen> createState() {
    return _MonthlyRecapScreenState();
  }
}

class _MonthlyRecapScreenState extends ConsumerState<MonthlyRecapScreen>
    with SingleTickerProviderStateMixin {
  static const _panelBg = Color(0xFF0E1420);
  static const _accent = Color(0xFFFFD246);

  late final AnimationController _fadeController;
  final Map<String, Uint8List> _photoBytesCache = {};

  static final List<_MonthlyStarSample> _starSamples = _buildStarSamples();

  static const _monthAbbr = [
    'JAN',
    'FEB',
    'MAR',
    'APR',
    'MAY',
    'JUN',
    'JUL',
    'AUG',
    'SEP',
    'OCT',
    'NOV',
    'DEC',
  ];

  static const _moods = <({String emoji, String label})>[
    (emoji: '\u{1F60C}', label: 'Calm'),
    (emoji: '\u{1F929}', label: 'Excited'),
    (emoji: '\u{1F634}', label: 'Tired'),
    (emoji: '\u26A1', label: 'Energetic'),
    (emoji: '\u{1F30C}', label: 'Mystic'),
    (emoji: '\u{1F9E0}', label: 'Focused'),
    (emoji: '\u{1F60A}', label: 'Happy'),
    (emoji: '\u{1F62E}', label: 'Amazed'),
  ];

  static List<_MonthlyStarSample> _buildStarSamples() {
    final rng = math.Random(72);
    const sizes = <double>[0.5, 1.0, 1.5];
    return List.generate(260, (_) {
      return _MonthlyStarSample(
        nx: rng.nextDouble(),
        ny: rng.nextDouble(),
        radius: sizes[rng.nextInt(sizes.length)],
        colorIndex: rng.nextInt(3),
      );
    });
  }

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final trip = ref.watch(tripProvider);
    final diaryMap = ref.watch(diaryProvider);
    final monthEntries = _entriesForMonth(diaryMap, trip.startDate);
    final monthTripDays = _tripDaysInMonth(trip.startDate);
    final stats = _buildStats(monthEntries, monthTripDays.length);
    final monthLabel = '${_monthAbbr[widget.month - 1]} ${widget.year}';

    return Scaffold(
      backgroundColor: const Color(0xFF020408),
      body: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: _MonthlyStarfieldPainter(_starSamples),
            ),
          ),
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 430),
              child: SafeArea(
                child: FadeTransition(
                  opacity: CurvedAnimation(
                    parent: _fadeController,
                    curve: Curves.easeOut,
                  ),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(18, 12, 18, 36),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _topBar(),
                        const SizedBox(height: 22),
                        _header(monthLabel, stats),
                        const SizedBox(height: 24),
                        _statGrid(stats),
                        const SizedBox(height: 24),
                        _moodSection(stats.moodCounts),
                        const SizedBox(height: 24),
                        _planetSection(monthEntries),
                        const SizedBox(height: 24),
                        _photoSection(monthEntries),
                        const SizedBox(height: 24),
                        _entryList(monthEntries, trip.startDate),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<DiaryEntry> _entriesForMonth(
    Map<int, DiaryEntry> diaryMap,
    DateTime startDate,
  ) {
    final entries = diaryMap.values.where((entry) {
      final date = _dateForTripDay(startDate, entry.tripDay);
      return date.year == widget.year && date.month == widget.month;
    }).toList();
    entries.sort((a, b) => a.tripDay.compareTo(b.tripDay));
    return entries;
  }

  List<int> _tripDaysInMonth(DateTime startDate) {
    final firstTripDate = DateTime(
      startDate.year,
      startDate.month,
      startDate.day,
    );
    final lastTripDate = firstTripDate.add(const Duration(days: 364));
    final monthStart = DateTime(widget.year, widget.month);
    final monthEnd = DateTime(
      widget.year,
      widget.month,
      DateUtils.getDaysInMonth(widget.year, widget.month),
    );
    final start =
        monthStart.isBefore(firstTripDate) ? firstTripDate : monthStart;
    final end = monthEnd.isAfter(lastTripDate) ? lastTripDate : monthEnd;
    if (end.isBefore(start)) return [];
    final days = end.difference(start).inDays + 1;
    return List.generate(days, (index) {
      final date = start.add(Duration(days: index));
      return date.difference(firstTripDate).inDays + 1;
    });
  }

  DateTime _dateForTripDay(DateTime startDate, int tripDay) {
    final first = DateTime(startDate.year, startDate.month, startDate.day);
    return first.add(Duration(days: tripDay - 1));
  }

  _MonthlyStats _buildStats(List<DiaryEntry> entries, int availableDays) {
    var photos = 0;
    var questDone = 0;
    final moodCounts = List.generate(_moods.length, (_) => 0);
    for (final entry in entries) {
      photos += entry.photoPaths.length;
      questDone += entry.questDone.where((done) => done).length;
      if (entry.moodIndex >= 0 && entry.moodIndex < moodCounts.length) {
        moodCounts[entry.moodIndex]++;
      }
    }
    return _MonthlyStats(
      availableDays: availableDays,
      recordedDays: entries.length,
      photoCount: photos,
      questDone: questDone,
      moodCounts: moodCounts,
    );
  }

  Widget _topBar() {
    return Row(
      children: [
        InkWell(
          onTap: () => context.pop(),
          child: Text(
            '← CALENDAR',
            style: GoogleFonts.spaceMono(
              fontSize: 11,
              color: Colors.white.withOpacity(0.45),
              letterSpacing: 0.5,
            ),
          ),
        ),
        const Spacer(),
        Text(
          'MONTHLY RECAP',
          style: GoogleFonts.spaceMono(
            fontSize: 12,
            color: Colors.white.withOpacity(0.55),
            letterSpacing: 2,
          ),
        ),
      ],
    );
  }

  Widget _header(String monthLabel, _MonthlyStats stats) {
    final progress = stats.availableDays == 0
        ? 0.0
        : (stats.recordedDays / stats.availableDays).clamp(0.0, 1.0);
    final topMood =
        stats.topMoodIndex == null ? '-' : _moods[stats.topMoodIndex!].emoji;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _accent.withOpacity(0.16),
            const Color(0xFF102040).withOpacity(0.72),
            _panelBg,
          ],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _accent.withOpacity(0.24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            monthLabel,
            style: GoogleFonts.spaceMono(
              fontSize: 24,
              color: Colors.white.withOpacity(0.92),
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '이번 달 우주 여행 기록',
            style: GoogleFonts.notoSansKr(
              fontSize: 13,
              color: Colors.white.withOpacity(0.55),
            ),
          ),
          const SizedBox(height: 22),
          Row(
            children: [
              Text(
                '${(progress * 100).round()}%',
                style: GoogleFonts.spaceMono(
                  fontSize: 32,
                  color: _accent,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(99),
                      child: LinearProgressIndicator(
                        minHeight: 8,
                        value: progress,
                        backgroundColor: Colors.white.withOpacity(0.08),
                        valueColor: const AlwaysStoppedAnimation(_accent),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${stats.recordedDays} / ${stats.availableDays}일 기록 · 대표 감정 $topMood',
                      style: GoogleFonts.notoSansKr(
                        fontSize: 11,
                        color: Colors.white.withOpacity(0.48),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statGrid(_MonthlyStats stats) {
    return Row(
      children: [
        _statCard('기록', '${stats.recordedDays}', 'DAYS'),
        const SizedBox(width: 8),
        _statCard('사진', '${stats.photoCount}', 'SHOTS'),
        const SizedBox(width: 8),
        _statCard('퀘스트', '${stats.questDone}', 'CLEAR'),
      ],
    );
  }

  Widget _statCard(String title, String value, String caption) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
        decoration: BoxDecoration(
          color: _panelBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withOpacity(0.08)),
        ),
        child: Column(
          children: [
            Text(
              title,
              style: GoogleFonts.notoSansKr(
                fontSize: 11,
                color: Colors.white.withOpacity(0.42),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: GoogleFonts.spaceMono(
                fontSize: 22,
                color: Colors.white.withOpacity(0.92),
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              caption,
              style: GoogleFonts.spaceMono(
                fontSize: 9,
                color: _accent.withOpacity(0.6),
                letterSpacing: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _moodSection(List<int> counts) {
    final maxCount = counts.isEmpty ? 0 : counts.reduce(math.max);
    return _section(
      title: '감정 분포',
      child: Column(
        children: List.generate(_moods.length, (index) {
          final count = counts[index];
          final widthFactor = maxCount == 0 ? 0.0 : count / maxCount;
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                SizedBox(
                  width: 76,
                  child: Text(
                    '${_moods[index].emoji} ${_moods[index].label}',
                    style: GoogleFonts.spaceMono(
                      fontSize: 10,
                      color: Colors.white.withOpacity(0.72),
                    ),
                  ),
                ),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(99),
                    child: LinearProgressIndicator(
                      minHeight: 7,
                      value: widthFactor,
                      backgroundColor: Colors.white.withOpacity(0.06),
                      valueColor: AlwaysStoppedAnimation(
                        _accent.withOpacity(count == 0 ? 0.25 : 0.76),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  '$count',
                  style: GoogleFonts.spaceMono(
                    fontSize: 11,
                    color: Colors.white.withOpacity(0.45),
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _planetSection(List<DiaryEntry> entries) {
    final counts = <String, int>{};
    for (final entry in entries) {
      final planet = planetForDay(entry.tripDay);
      counts[planet.name] = (counts[planet.name] ?? 0) + 1;
    }
    final visiblePlanets = kPlanets.where((planet) {
      return counts.containsKey(planet.name);
    }).toList();

    return _section(
      title: '행성별 기록',
      child: visiblePlanets.isEmpty
          ? _emptyText('이번 달 행성 기록이 아직 없어요.')
          : Column(
              children: visiblePlanets.map((planet) {
                final count = counts[planet.name] ?? 0;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: planet.color,
                          boxShadow: [
                            BoxShadow(
                              color: planet.color.withOpacity(0.35),
                              blurRadius: 6,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          planet.name,
                          style: GoogleFonts.notoSansKr(
                            fontSize: 12,
                            color: Colors.white.withOpacity(0.78),
                          ),
                        ),
                      ),
                      Text(
                        '$count DAYS',
                        style: GoogleFonts.spaceMono(
                          fontSize: 11,
                          color: _accent.withOpacity(0.72),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
    );
  }

  Widget _photoSection(List<DiaryEntry> entries) {
    final paths = entries
        .expand((entry) => entry.photoPaths)
        .take(6)
        .toList();
    return _section(
      title: '사진 하이라이트',
      child: paths.isEmpty
          ? _emptyText('이번 달 저장된 사진이 없어요.')
          : GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: paths.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemBuilder: (context, index) {
                return ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: _recapImage(paths[index]),
                );
              },
            ),
    );
  }

  Widget _entryList(List<DiaryEntry> entries, DateTime startDate) {
    return _section(
      title: '기록 목록',
      child: entries.isEmpty
          ? _emptyText('이번 달 작성된 일기가 없어요.')
          : Column(
              children: entries.map((entry) {
                final date = _dateForTripDay(startDate, entry.tripDay);
                final planet = planetForDay(entry.tripDay);
                final preview = entry.text.trim().isEmpty
                    ? '내용 없이 저장된 기록이에요.'
                    : entry.text.trim().split('\n').first;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => context.push('/diary/${entry.tripDay}'),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.035),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: planet.color.withOpacity(0.28),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 38,
                              height: 38,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: planet.color.withOpacity(0.18),
                                border: Border.all(
                                  color: planet.color.withOpacity(0.44),
                                ),
                              ),
                              child: Text(
                                '${date.day}',
                                style: GoogleFonts.spaceMono(
                                  fontSize: 13,
                                  color: Colors.white.withOpacity(0.9),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'DAY ${entry.tripDay} · ${planet.name}',
                                    style: GoogleFonts.spaceMono(
                                      fontSize: 10,
                                      color: _accent.withOpacity(0.7),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    preview,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.notoSansKr(
                                      fontSize: 12,
                                      color: Colors.white.withOpacity(0.72),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              Icons.chevron_right,
                              size: 18,
                              color: Colors.white.withOpacity(0.24),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
    );
  }

  Widget _section({
    required String title,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _panelBg.withOpacity(0.92),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.notoSansKr(
              fontSize: 11,
              color: Colors.white.withOpacity(0.42),
              letterSpacing: 1.4,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  Widget _emptyText(String text) {
    return Text(
      text,
      style: GoogleFonts.notoSansKr(
        fontSize: 12,
        color: Colors.white.withOpacity(0.3),
      ),
    );
  }

  Widget _recapImage(String path) {
    if (kIsWeb) {
      return Image.network(
        path,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) =>
            const ColoredBox(color: Color(0xFF1A1A1A)),
      );
    }

    return FutureBuilder<Uint8List>(
      future: _readPhotoBytes(path),
      builder: (context, snap) {
        if (snap.hasError || !snap.hasData) {
          return const ColoredBox(color: Color(0xFF1A1A1A));
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

  Future<Uint8List> _readPhotoBytes(String path) async {
    final cached = _photoBytesCache[path];
    if (cached != null) return cached;
    final bytes = await XFile(path).readAsBytes();
    _photoBytesCache[path] = bytes;
    return bytes;
  }
}

class _MonthlyStats {
  const _MonthlyStats({
    required this.availableDays,
    required this.recordedDays,
    required this.photoCount,
    required this.questDone,
    required this.moodCounts,
  });

  final int availableDays;
  final int recordedDays;
  final int photoCount;
  final int questDone;
  final List<int> moodCounts;

  int? get topMoodIndex {
    if (moodCounts.every((count) => count == 0)) return null;
    var index = 0;
    for (var i = 1; i < moodCounts.length; i++) {
      if (moodCounts[i] > moodCounts[index]) index = i;
    }
    return index;
  }
}

class _MonthlyStarSample {
  const _MonthlyStarSample({
    required this.nx,
    required this.ny,
    required this.radius,
    required this.colorIndex,
  });

  final double nx;
  final double ny;
  final double radius;
  final int colorIndex;
}

class _MonthlyStarfieldPainter extends CustomPainter {
  _MonthlyStarfieldPainter(this.samples);

  final List<_MonthlyStarSample> samples;

  static const _colors = <Color>[
    Color(0xFFF6F8FF),
    Color(0xFFFFF3DF),
    Color(0xFFD8E8FF),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFF020408),
    );
    for (final sample in samples) {
      canvas.drawCircle(
        Offset(sample.nx * size.width, sample.ny * size.height),
        sample.radius,
        Paint()..color = _colors[sample.colorIndex],
      );
    }
  }

  @override
  bool shouldRepaint(covariant _MonthlyStarfieldPainter oldDelegate) => false;
}
