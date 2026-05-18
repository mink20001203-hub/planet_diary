import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:table_calendar/table_calendar.dart';

import '../models/diary_entry.dart';
import '../providers/diary_provider.dart';
import '../providers/trip_provider.dart';
import '../providers/xp_provider.dart';

/// TODO(Hive): 일기/사진/퀘스트 집계를 diaryProvider + Hive 동기화 기반으로 정리
/// 아래 mock 문구는 제거 필요

class _DayMeta {
  const _DayMeta({
    required this.hasDiary,
    required this.hasPhoto,
    required this.questClear,
  });

  final bool hasDiary;
  final bool hasPhoto;
  final bool questClear;

  static const empty = _DayMeta(
    hasDiary: false,
    hasPhoto: false,
    questClear: false,
  );
}

class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  static const _panelBg = Color(0xFF0E1420);
  static const _selectedDayBg = Color(0xFF1E2A40);

  static final List<_CalStarSample> _starSamples = _buildStarSamples();

  static List<_CalStarSample> _buildStarSamples() {
    final rng = math.Random(42);
    const sizes = <double>[0.5, 1.0, 1.5];
    return List.generate(300, (_) {
      return _CalStarSample(
        nx: rng.nextDouble(),
        ny: rng.nextDouble(),
        radius: sizes[rng.nextInt(3)],
        colorIndex: rng.nextInt(3),
      );
    });
  }

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
  static const _weekdayEn = [
    'MON',
    'TUE',
    'WED',
    'THU',
    'FRI',
    'SAT',
    'SUN',
  ];

  late DateTime _focusedDay;
  DateTime? _selectedDay;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    // 초기값은 오늘 날짜(매핑된 2025 날짜)로 설정
    final trip = ref.read(tripProvider);
    _focusedDay = _clampToTripCalendar(
      trip.today,
      startDate: trip.startDate,
    );
    _selectedDay = _focusedDay;
    _initialized = true;
  }

  /// [firstDay, lastDay] 밖의 날짜는 clamp
  DateTime _clampToTripCalendar(
    DateTime d, {
    required DateTime startDate,
  }) {
    final firstDay = DateTime(startDate.year, startDate.month, startDate.day);
    final lastDay = firstDay.add(const Duration(days: 364));
    if (d.isBefore(firstDay)) return firstDay;
    if (d.isAfter(lastDay)) return lastDay;
    return d;
  }

  /// lastDay 이후면 lastDay, 이전이면 firstDay
  DateTime _safeFocusedDayFromToday() {
    final trip = ref.read(tripProvider);
    final firstDay = DateTime(
      trip.startDate.year,
      trip.startDate.month,
      trip.startDate.day,
    );
    final lastDay = firstDay.add(const Duration(days: 364));
    final today = trip.today;
    if (today.isAfter(lastDay)) return lastDay;
    if (today.isBefore(firstDay)) return firstDay;
    return today;
  }

  int _tripDayFromDate(DateTime d, DateTime startDate) {
    final firstDay = DateTime(startDate.year, startDate.month, startDate.day);
    return d.difference(firstDay).inDays + 1;
  }

  _DayMeta _effectiveMeta(int tripDay, Map<int, DiaryEntry> diaryMap) {
    final e = diaryMap[tripDay];
    if (e != null) {
      // 하나라도 questDone=true면 퀘스트 완료로 간주
      final anyQuest = e.questDone.any((bool x) => x);
      return _DayMeta(
        hasDiary: true,
        hasPhoto: e.photoPaths.isNotEmpty,
        questClear: anyQuest,
      );
    }
    return _DayMeta.empty;
  }

  String _formatHudDate(DateTime d) {
    final m = _monthAbbr[d.month - 1];
    return '${d.year}년 $m월 ${d.day.toString().padLeft(2, '0')}일';
  }

  String _weekdayShort(DateTime d) {
    return _weekdayEn[(d.weekday - 1) % 7];
  }

  void _jumpToPlanetMonth(PlanetInfo planet, DateTime startDate) {
    final targetDay = DateTime(
      startDate.year,
      startDate.month,
      startDate.day,
    ).add(
      Duration(days: planet.startDay - 1),
    );
    setState(() {
      final safe = _clampToTripCalendar(
        targetDay,
        startDate: startDate,
      );
      _focusedDay = safe;
      _selectedDay = safe;
    });
  }

  ({int recorded, int questsCleared}) _stats(
    Map<int, DiaryEntry> diaryMap,
  ) {
    var recorded = 0;
    var questsCleared = 0;
    for (final entry in diaryMap.values) {
      recorded++;
      if (entry.questDone.any((x) => x)) questsCleared++;
    }
    return (recorded: recorded, questsCleared: questsCleared);
  }

  String? _previewText(int tripDay, Map<int, DiaryEntry> diaryMap) {
    final e = diaryMap[tripDay];
    if (e != null && e.text.trim().isNotEmpty) {
      // 선택한 날짜에 일기가 있으면 첫 줄 표시
      final firstLine = e.text.trim().split('\n').first;
      return firstLine.length > 80 ? '${firstLine.substring(0, 80)}...' : firstLine;
    }
    return null;
  }

  bool _isFutureDate(DateTime day, DateTime now) {
    final selected = DateUtils.dateOnly(day);
    final today = DateUtils.dateOnly(now);
    return selected.isAfter(today);
  }

  @override
  Widget build(BuildContext context) {
    final trip = ref.watch(tripProvider);
    final diaryMap = ref.watch(diaryProvider);

    if (!_initialized) {
      _initialized = true;
      final safe = _safeFocusedDayFromToday();
      _focusedDay = safe;
      _selectedDay = safe;
    }

    // 데이터 로딩 체크
    if (!_initialized) {
      return Scaffold(
        backgroundColor: const Color(0xFF020408),
        body: Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: _CalendarStarfieldPainter(_starSamples),
              ),
            ),
            const Center(
              child: CircularProgressIndicator(
                color: Colors.white54,
                strokeWidth: 1.0,
              ),
            ),
          ],
        ),
      );
    }

    final stats = _stats(diaryMap);
    final headerTextStyle = GoogleFonts.spaceMono(
      color: Colors.white.withOpacity(0.6),
      fontSize: 13,
      fontWeight: FontWeight.w500,
    );
    final dowStyle = GoogleFonts.spaceMono(
      color: Colors.white.withOpacity(0.3),
      fontSize: 9,
    );

    return Scaffold(
      backgroundColor: const Color(0xFF020408),
      body: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: _CalendarStarfieldPainter(_starSamples),
            ),
          ),
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 430),
              child: SafeArea(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildHud(trip),
                      const SizedBox(height: 20),
                      _buildPlanetStrip(trip),
                      const SizedBox(height: 16),
                      Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF0E1420),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.08),
                            width: 1,
                          ),
                        ),
                        padding: const EdgeInsets.fromLTRB(8, 10, 8, 12),
                        child: _buildCalendar(
                          trip: trip,
                          diaryMap: diaryMap,
                          headerTextStyle: headerTextStyle,
                          dowStyle: dowStyle,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildMonthlyRecapButton(_focusedDay),
                      const SizedBox(height: 12),
                      _buildSelectionPreview(trip, diaryMap),
                      const SizedBox(height: 20),
                      _buildStatsRow(trip, stats),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHud(TripState trip) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  InkWell(
                    onTap: () => context.go('/'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.2),
                        ),
                      ),
                      child: Text(
                        'MAP',
                        style: GoogleFonts.spaceMono(
                          fontSize: 9,
                          color: Colors.white.withOpacity(0.6),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'TODAY',
                    style: GoogleFonts.spaceMono(
                      fontSize: 10,
                      color: const Color(0xFFFFD246).withOpacity(0.6),
                      letterSpacing: 2,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                _formatHudDate(trip.today),
                style: GoogleFonts.spaceMono(
                  fontSize: 20,
                  color: Colors.white.withOpacity(0.9),
                  fontWeight: FontWeight.w600,
                  height: 1.15,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                _weekdayShort(trip.today),
                style: GoogleFonts.spaceMono(
                  fontSize: 11,
                  color: Colors.white.withOpacity(0.3),
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    'MISSION LOG',
                    style: GoogleFonts.spaceMono(
                      fontSize: 10,
                      color: const Color(0xFFFFD246).withOpacity(0.6),
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(width: 12),
                  InkWell(
                    onTap: () => context.push('/recap'),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFFFFD246).withOpacity(0.3)),
                      ),
                      child: const Icon(
                        Icons.analytics_outlined,
                        size: 14,
                        color: Color(0xFFFFD246),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'DAY ${trip.tripDay.toString().padLeft(3, '0')} / 365',
                style: GoogleFonts.spaceMono(
                  fontSize: 17,
                  color: Colors.white.withOpacity(0.9),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${trip.planet.name.toUpperCase()} SECTOR',
                style: GoogleFonts.spaceMono(
                  fontSize: 12,
                  color: const Color(0xFFFFD246).withOpacity(0.8),
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '체류 ${trip.stayDay}일째 · ${trip.remainDays}일 남음',
                style: GoogleFonts.spaceMono(
                  fontSize: 10,
                  color: Colors.white.withOpacity(0.3),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPlanetStrip(TripState trip) {
    return SizedBox(
      height: 88,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: kPlanets.map((p) {
            final current = p.name == trip.planet.name;
            return Padding(
              padding: const EdgeInsets.only(right: 10),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => _jumpToPlanetMonth(p, trip.startDate),
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    width: 108,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: current
                          ? Colors.white.withOpacity(0.09)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: current
                            ? Colors.white.withOpacity(0.14)
                            : Colors.white.withOpacity(0.06),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: p.color,
                            boxShadow: [
                              BoxShadow(
                                color: p.color.withOpacity(0.35),
                                blurRadius: 8,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          p.name,
                          style: GoogleFonts.spaceMono(
                            fontSize: 11,
                            color: Colors.white.withOpacity(0.85),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${p.days}일 체류',
                          style: GoogleFonts.spaceMono(
                            fontSize: 9,
                            color: Colors.white.withOpacity(0.35),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildCalendar({
    required TripState trip,
    required Map<int, DiaryEntry> diaryMap,
    required TextStyle headerTextStyle,
    required TextStyle dowStyle,
  }) {
    final firstDay = DateTime(
      trip.startDate.year,
      trip.startDate.month,
      trip.startDate.day,
    );
    final lastDay = firstDay.add(const Duration(days: 364));

    return SizedBox(
      height: 400,
      child: TableCalendar<void>(
        firstDay: firstDay,
        lastDay: lastDay,
        focusedDay: _clampToTripCalendar(
          _focusedDay,
          startDate: trip.startDate,
        ),
        rowHeight: 52,
        calendarFormat: CalendarFormat.month,
        availableCalendarFormats: const {CalendarFormat.month: 'Month'},
        startingDayOfWeek: StartingDayOfWeek.sunday,
        daysOfWeekVisible: true,
        selectedDayPredicate: (d) =>
            _selectedDay != null && isSameDay(_selectedDay, d),
        onDaySelected: (selected, focused) {
          setState(() {
            _selectedDay = selected;
            _focusedDay = _clampToTripCalendar(
              focused,
              startDate: trip.startDate,
            );
          });
        },
        onPageChanged: (focused) {
          setState(() {
            _focusedDay = _clampToTripCalendar(
              focused,
              startDate: trip.startDate,
            );
          });
        },
        headerStyle: HeaderStyle(
          titleCentered: true,
          formatButtonVisible: false,
          titleTextFormatter: (d, _) {
            final m = _monthAbbr[d.month - 1];
            return '$m ${d.year}';
          },
          titleTextStyle: headerTextStyle,
          leftChevronIcon: Icon(
            Icons.chevron_left,
            color: Colors.white.withOpacity(0.45),
            size: 26,
          ),
          rightChevronIcon: Icon(
            Icons.chevron_right,
            color: Colors.white.withOpacity(0.45),
            size: 26,
          ),
        ),
        daysOfWeekStyle: DaysOfWeekStyle(
          weekdayStyle: dowStyle,
          weekendStyle: dowStyle,
        ),
        calendarStyle: const CalendarStyle(
          outsideDaysVisible: true,
          markersMaxCount: 0,
          cellMargin: EdgeInsets.zero,
          defaultDecoration: BoxDecoration(),
          weekendDecoration: BoxDecoration(),
          holidayDecoration: BoxDecoration(),
          selectedDecoration: BoxDecoration(),
          todayDecoration: BoxDecoration(),
          outsideDecoration: BoxDecoration(),
        ),
        calendarBuilders: CalendarBuilders<void>(
          defaultBuilder: (context, day, focusedDay) {
            final outside =
                day.month != focusedDay.month || day.year != focusedDay.year;
            final today = isSameDay(day, DateTime.now());
            final selected =
                _selectedDay != null && isSameDay(_selectedDay, day);
            return _dayCell(
              day,
              focusedDay,
              trip.startDate,
              diaryMap,
              isToday: today,
              isSelected: selected,
              isOutside: outside,
            );
          },
        ),
      ),
    );
  }

  Widget _dayCell(
    DateTime day,
    DateTime focusedDay,
    DateTime startDate,
    Map<int, DiaryEntry> diaryMap, {
    bool isToday = false,
    bool isSelected = false,
    bool isOutside = false,
  }) {
    final tripDay = _tripDayFromDate(day, startDate);
    if (tripDay < 1 || tripDay > 365) {
      return const SizedBox.shrink();
    }
    final planet = planetForDay(tripDay);
    final meta = _effectiveMeta(tripDay, diaryMap);

    Widget inner = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
      child: Column(
        children: [
          Expanded(
            child: Center(
              child: isToday
                  ? Container(
                      width: 28,
                      height: 28,
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '${day.day}',
                        style: GoogleFonts.spaceMono(
                          fontSize: 13,
                          color: Colors.black,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    )
                  : Text(
                      '${day.day}',
                      style: GoogleFonts.spaceMono(
                        fontSize: 13,
                        color: Colors.white.withOpacity(0.85),
                        fontWeight:
                            isSelected ? FontWeight.w600 : FontWeight.w400,
                      ),
                    ),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _dot(
                Colors.white,
                meta.hasDiary,
              ),
              const SizedBox(width: 3),
              _dot(
                const Color(0xFF6BA8FF),
                meta.hasPhoto,
              ),
              const SizedBox(width: 3),
              _dot(
                const Color(0xFFFFD246),
                meta.questClear,
              ),
            ],
          ),
          const SizedBox(height: 2),
          Container(
            height: 1.5,
            width: double.infinity,
            decoration: BoxDecoration(
              color: planet.color.withOpacity(0.7),
              borderRadius: BorderRadius.circular(1),
            ),
          ),
        ],
      ),
    );

    inner = Container(
      decoration: BoxDecoration(
        color: isToday
            ? null
            : (isSelected ? _selectedDayBg : null),
        borderRadius: BorderRadius.circular(8),
      ),
      child: inner,
    );

    if (isOutside) {
      inner = Opacity(opacity: 0.1, child: inner);
    }

    return inner;
  }

  Widget _dot(Color color, bool on) {
    return Container(
      width: 4,
      height: 4,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: on ? color : color.withOpacity(0.12),
      ),
    );
  }

  Widget _buildSelectionPreview(
    TripState trip,
    Map<int, DiaryEntry> diaryMap,
  ) {
    final sel = _selectedDay;
    final open = sel != null;
    final isFuture = sel != null && _isFutureDate(sel, trip.today);
    final tripDay =
        sel == null ? trip.tripDay : _tripDayFromDate(sel, trip.startDate);
    final planet = planetForDay(tripDay);
    final meta = _effectiveMeta(tripDay, diaryMap);
    final preview = _previewText(tripDay, diaryMap);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
      height: open ? 200 : 0,
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
      ),
      child: open
          ? Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: isFuture
                    ? () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            duration: const Duration(seconds: 1),
                            behavior: SnackBarBehavior.floating,
                            backgroundColor: const Color(0xFF1A1A1A),
                            content: Text(
                              '미래 날짜의 일기는 아직 작성할 수 없어요.',
                              style: GoogleFonts.notoSansKr(fontSize: 12),
                            ),
                          ),
                        );
                      }
                    : () => context.push('/diary/$tripDay'),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: _panelBg,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: planet.color,
                      width: 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Expanded(
                            child: Text(
                              _formatHudDate(sel),
                              style: GoogleFonts.spaceMono(
                                fontSize: 14,
                                color: Colors.white.withOpacity(0.9),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          Text(
                            'DAY $tripDay',
                            style: GoogleFonts.spaceMono(
                              fontSize: 11,
                              color: Colors.white.withOpacity(0.55),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Container(
                            width: 14,
                            height: 14,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: planet.color,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            planet.name,
                            style: GoogleFonts.spaceMono(
                              fontSize: 13,
                              color: Colors.white.withOpacity(0.9),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: Text(
                          preview ??
                              (isFuture
                                  ? '아직 지나지 않은 날짜예요.'
                                  : '아직 기록이 없는 날이에요.'),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.spaceMono(
                            fontSize: 11,
                            height: 1.35,
                            fontStyle: preview == null
                                ? FontStyle.italic
                                : FontStyle.normal,
                            color: preview == null
                                ? Colors.white.withOpacity(0.2)
                                : Colors.white.withOpacity(0.9),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          _badge('일기', meta.hasDiary),
                          const SizedBox(width: 8),
                          _badge('사진', meta.hasPhoto),
                          const SizedBox(width: 8),
                          _badge('QUEST', meta.questClear),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            )
          : const SizedBox.shrink(),
    );
  }

  Widget _badge(String label, bool done) {
    const amber = Color(0xFFFFD246);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: done ? amber.withOpacity(0.85) : Colors.white.withOpacity(0.12),
        ),
      ),
      child: Text(
        label,
        style: GoogleFonts.spaceMono(
          fontSize: 9,
          color: done ? amber.withOpacity(0.95) : Colors.white.withOpacity(0.25),
        ),
      ),
    );
  }

  Widget _buildMonthlyRecapButton(DateTime focusedDay) {
    final monthText = '${focusedDay.year} ${_monthAbbr[focusedDay.month - 1]}';
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => context.push(
          '/monthly-recap/${focusedDay.year}/${focusedDay.month}',
        ),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFFFD246).withOpacity(0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: const Color(0xFFFFD246).withOpacity(0.22),
            ),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.insights_outlined,
                color: Color(0xFFFFD246),
                size: 17,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '$monthText MONTHLY RECAP',
                  style: GoogleFonts.spaceMono(
                    fontSize: 11,
                    color: const Color(0xFFFFD246).withOpacity(0.82),
                    letterSpacing: 0.8,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: Colors.white.withOpacity(0.35),
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatsRow(
    TripState trip,
    ({int recorded, int questsCleared}) stats,
  ) {
    Widget cell(String title, String value) {
      return Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.035),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: Colors.white.withOpacity(0.07),
            ),
          ),
          child: Column(
            children: [
              Text(
                title,
                textAlign: TextAlign.center,
                style: GoogleFonts.spaceMono(
                  fontSize: 9,
                  color: Colors.white.withOpacity(0.35),
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                value,
                style: GoogleFonts.spaceMono(
                  fontSize: 16,
                  color: Colors.white.withOpacity(0.9),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final xpState = ref.watch(xpProvider);

    return Column(
      children: [
        Row(
          children: [
            cell('기록 완료일수', '${stats.recorded}'),
            const SizedBox(width: 8),
            cell('Quest Cleared', '${stats.questsCleared}'),
            const SizedBox(width: 8),
            cell('Days Left', '${trip.remainDays}'),
          ],
        ),
        if (xpState.streak > 0) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
            decoration: BoxDecoration(
              color: const Color(0xFFFFD246).withOpacity(0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: const Color(0xFFFFD246).withOpacity(0.2),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('🔥', style: TextStyle(fontSize: 14)),
                const SizedBox(width: 8),
                Text(
                  '${xpState.streak} day streak',
                  style: GoogleFonts.spaceMono(
                    fontSize: 12,
                    color: const Color(0xFFFFD246),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _CalStarSample {
  const _CalStarSample({
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

class _CalendarStarfieldPainter extends CustomPainter {
  _CalendarStarfieldPainter(this.samples);

  final List<_CalStarSample> samples;

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
    for (final s in samples) {
      canvas.drawCircle(
        Offset(s.nx * size.width, s.ny * size.height),
        s.radius,
        Paint()..color = _colors[s.colorIndex],
      );
    }
  }

  @override
  bool shouldRepaint(covariant _CalendarStarfieldPainter oldDelegate) => false;
}

