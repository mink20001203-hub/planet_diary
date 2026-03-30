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
import '../providers/quest_provider.dart';
import '../providers/trip_provider.dart';
import '../providers/xp_provider.dart';

/// tripDay 기준 일기 편집 (Hive는 diaryProvider.save로 연결)
class DiaryEditScreen extends ConsumerStatefulWidget {
  const DiaryEditScreen({super.key, required this.tripDay});

  final int tripDay;

  @override
  ConsumerState<DiaryEditScreen> createState() => _DiaryEditScreenState();
}

class _DiaryEditScreenState extends ConsumerState<DiaryEditScreen>
    with TickerProviderStateMixin {
  static const _panelBg = Color(0xFF0E1420);
  static const _moodCardBg = Color(0xFF0A1018);

  // XP 애니메이션
  late final AnimationController _xpAnimController;
  late final Animation<double> _xpOpacity;
  late final Animation<Offset> _xpOffset;
  int _earnedXp = 0;
  bool _showLevelUp = false;

  static final List<_DiaryStarSample> _starSamples = _buildStarSamples();

  static List<_DiaryStarSample> _buildStarSamples() {
    final rng = math.Random(42);
    const sizes = <double>[0.5, 1.0, 1.5];
    return List.generate(300, (_) {
      return _DiaryStarSample(
        nx: rng.nextDouble(),
        ny: rng.nextDouble(),
        radius: sizes[rng.nextInt(3)],
        colorIndex: rng.nextInt(3),
      );
    });
  }

  static final _tripStart = DateTime(2025, 1, 1);
  static const _monthAbbr = [
    'JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN',
    'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC',
  ];

  static const _moods = <({String emoji, String label})>[
    (emoji: '😌', label: '고요함'),
    (emoji: '🤩', label: '경이로움'),
    (emoji: '😔', label: '외로움'),
    (emoji: '💪', label: '에너지'),
    (emoji: '🤔', label: '사색'),
    (emoji: '😴', label: '피곤함'),
    (emoji: '😊', label: '행복함'),
    (emoji: '😨', label: '긴장됨'),
  ];

  late final TextEditingController _textController;
  int _moodIndex = 0;
  final List<String> _photoPaths = [];
  final Map<String, Uint8List> _photoBytesCache = {};
  final ImagePicker _picker = ImagePicker();
  bool _hydrated = false;

  DateTime get _dateForTrip =>
      _tripStart.add(Duration(days: widget.tripDay - 1));

  String get _dateHeaderLine {
    final d = _dateForTrip;
    final m = _monthAbbr[d.month - 1];
    return '${d.year} · $m · ${d.day.toString().padLeft(2, '0')}';
  }

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController();
    _textController.addListener(() => setState(() {}));

    _xpAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _xpOpacity = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 20),
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 30),
    ]).animate(_xpAnimController);
    _xpOffset = Tween<Offset>(
      begin: const Offset(0, 0.2),
      end: const Offset(0, -0.5),
    ).animate(CurvedAnimation(parent: _xpAnimController, curve: Curves.easeOut));
    
    // initState에서 데이터 초기화
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _hydrateFromDiary();
    });
  }

  @override
  void dispose() {
    _textController.dispose();
    _xpAnimController.dispose();
    super.dispose();
  }

  void _hydrateFromDiary() {
    final diaryMap = ref.read(diaryProvider);
    final entry = diaryMap[widget.tripDay];
    if (entry != null) {
      _textController.text = entry.text;
      _moodIndex = entry.moodIndex.clamp(0, _moods.length - 1);
      _photoPaths
        ..clear()
        ..addAll(entry.photoPaths);
      ref.read(questProvider.notifier).setForDay(widget.tripDay, entry.questDone);
    } else {
      // 신규 일기면 퀘스트 상태 초기화
      ref
          .read(questProvider.notifier)
          .setForDay(widget.tripDay, [false, false, false]);
    }
    setState(() {
      _hydrated = true;
    });
  }

  Future<void> _saveToHive({required bool popAfter}) async {
    final quests = ref.read(questProvider.notifier).getQuests(widget.tripDay);
    final entry = DiaryEntry(
      tripDay: widget.tripDay,
      text: _textController.text,
      moodIndex: _moodIndex,
      photoPaths: List<String>.from(_photoPaths),
      questDone: List<bool>.from(quests),
      savedAt: DateTime.now(),
    );
    
    final messenger = ScaffoldMessenger.of(context);
    await ref.read(diaryProvider.notifier).save(entry);

    // XP 정산
    int totalEarned = 0;
    totalEarned += 10; // 일기 작성
    if (_photoPaths.isNotEmpty) totalEarned += 5; // 사진
    final doneCount = quests.where((q) => q).length;
    totalEarned += (doneCount * 15); // 퀘스트

    final leveledUp = ref.read(xpProvider.notifier).addXp(totalEarned);
    ref.read(xpProvider.notifier).checkStreak(widget.tripDay);

    setState(() {
      _earnedXp = totalEarned;
      _showLevelUp = leveledUp;
    });
    _xpAnimController.forward(from: 0);
    
    if (!mounted) return;
    if (popAfter) {
      await Future.delayed(const Duration(milliseconds: 1000));
      if (!mounted) return;
      context.pop();
      messenger.showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF1a1a1a),
          behavior: SnackBarBehavior.floating,
          content: Text(
            'DAY ${widget.tripDay} 기록 완료 (+$totalEarned XP)',
            style: GoogleFonts.spaceMono(
              color: const Color(0xFFFFD246),
              fontSize: 13,
            ),
          ),
        ),
      );
    } else {
      messenger.showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 1),
          backgroundColor: const Color(0xFF1a1a1a),
          behavior: SnackBarBehavior.floating,
          content: Text(
            '임시 저장되었습니다.',
            style: GoogleFonts.spaceMono(
              color: Colors.white70,
              fontSize: 12,
            ),
          ),
        ),
      );
    }
  }

  Future<void> _pickImage() async {
    final x = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (x == null) return;
    setState(() {
      _photoPaths.add(x.path);
    });
  }

  void _removePhoto(int index) {
    setState(() {
      final removedPath = _photoPaths.removeAt(index);
      _photoBytesCache.remove(removedPath);
    });
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

  @override
  Widget build(BuildContext context) {
    if (!_hydrated) {
      return Scaffold(
        backgroundColor: const Color(0xFF020408),
        body: Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: _DiaryStarfieldPainter(_starSamples),
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

    final planet = planetForDay(widget.tripDay);
    final stayDay = widget.tripDay - planet.startDay + 1;
    final remain = planet.days - stayDay;
    final quests = ref.watch(questProvider)[widget.tripDay] ??
        [false, false, false];
    final questDefs = _questsForPlanet(planet.name);
    final doneCount = quests.where((e) => e).length;

    final borderIdle = Colors.white.withValues(alpha: 0.15);
    final borderFocus = Colors.white.withValues(alpha: 0.3);

    return Scaffold(
      backgroundColor: const Color(0xFF020408),
      body: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: _DiaryStarfieldPainter(_starSamples),
            ),
          ),
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 430),
              child: SafeArea(
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(16, 8, 16, 28),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _topBar(),
                      const SizedBox(height: 16),
                      _planetBanner(planet, stayDay, remain),
                      const SizedBox(height: 22),
                      _moodSection(),
                      const SizedBox(height: 20),
                      Stack(
                        children: [
                          TextField(
                            controller: _textController,
                            maxLength: 500,
                            maxLines: null,
                            minLines: 6,
                            style: GoogleFonts.spaceMono(
                              fontSize: 14,
                              height: 1.75,
                              color: Colors.white.withValues(alpha: 0.9),
                            ),
                            cursorColor: const Color(0xFFFFD246),
                            decoration: InputDecoration(
                              counterText: '',
                              filled: true,
                              fillColor: const Color(0xFF0E1420),
                              hintText: '${planet.name}에서의 오늘을 기록하세요...',
                              hintStyle: GoogleFonts.spaceMono(
                                color: Colors.white.withValues(alpha: 0.3),
                                height: 1.75,
                              ),
                              contentPadding: EdgeInsets.all(14),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide(color: borderIdle),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide(color: borderIdle),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide(color: borderFocus, width: 1.2),
                              ),
                            ),
                          ),
                          Positioned(
                            right: 10,
                            bottom: 10,
                            child: Text(
                              '${_textController.text.characters.length} / 500',
                              style: GoogleFonts.spaceMono(
                                fontSize: 9,
                                color: Colors.white.withValues(alpha: 0.3),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Text(
                        '사진 기록',
                        style: GoogleFonts.spaceMono(
                          fontSize: 9,
                          color: Colors.white.withValues(alpha: 0.3),
                          letterSpacing: 2,
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        height: 76,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          children: [
                            ...List.generate(_photoPaths.length, (i) {
                              return Padding(
                                padding: EdgeInsets.only(right: 10),
                                child: _PhotoThumb(
                                  path: _photoPaths[i],
                                  loadBytes: _readPhotoBytes,
                                  onRemove: () => _removePhoto(i),
                                ),
                              );
                            }),
                            _addPhotoButton(),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        '오늘의 퀘스트',
                        style: GoogleFonts.spaceMono(
                          fontSize: 9,
                          color: Colors.white.withValues(alpha: 0.3),
                          letterSpacing: 2,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _questCard(
                        planet: planet,
                        doneCount: doneCount,
                        quests: quests,
                        defs: questDefs,
                      ),
                      const SizedBox(height: 28),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => _saveToHive(popAfter: false),
                              style: OutlinedButton.styleFrom(
                                padding: EdgeInsets.symmetric(vertical: 14),
                                side: BorderSide(
                                  color: Colors.white.withValues(alpha: 0.2),
                                ),
                                backgroundColor: const Color(0xFF0E1420),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              child: Text(
                                '임시저장',
                                style: GoogleFonts.spaceMono(
                                  fontSize: 12,
                                  color: Colors.white.withValues(alpha: 0.9),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => _saveToHive(popAfter: true),
                              style: OutlinedButton.styleFrom(
                                padding: EdgeInsets.symmetric(vertical: 14),
                                side: BorderSide(
                                  color: const Color(0xFFFFD246).withValues(alpha: 0.5),
                                ),
                                backgroundColor: const Color(0xFFFFD246).withValues(alpha: 0.15),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              child: Text(
                                '기록 완료 →',
                                style: GoogleFonts.spaceMono(
                                  fontSize: 12,
                                  color: const Color(0xFFFFD246).withValues(alpha: 0.9),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // XP Popup
          Center(
            child: AnimatedBuilder(
              animation: _xpAnimController,
              builder: (context, child) {
                return Opacity(
                  opacity: _xpOpacity.value,
                  child: SlideTransition(
                    position: _xpOffset,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '+$_earnedXp XP',
                          style: GoogleFonts.spaceMono(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFFFFD246),
                            shadows: [
                              Shadow(blurRadius: 12, color: Colors.black54),
                            ],
                          ),
                        ),
                        if (_showLevelUp)
                          Container(
                            margin: EdgeInsets.only(top: 12),
                            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFD246),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              'LEVEL UP!',
                              style: GoogleFonts.spaceMono(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.black,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
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
              color: Colors.white.withValues(alpha: 0.35),
              letterSpacing: 0.5,
            ),
          ),
        ),
        Expanded(
          child: Column(
            children: [
              Text(
                _dateHeaderLine,
                style: GoogleFonts.spaceMono(
                  fontSize: 11,
                  color: const Color(0xFFFFD246).withValues(alpha: 0.6),
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'DAY ${widget.tripDay}',
                style: GoogleFonts.spaceMono(
                  fontSize: 18,
                  color: Colors.white.withValues(alpha: 0.9),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        InkWell(
          onTap: () async {
            await _saveToHive(popAfter: true);
          },
          child: Text(
            'SAVE ↑',
            style: GoogleFonts.spaceMono(
              fontSize: 11,
              color: const Color(0xFFFFD246).withValues(alpha: 0.7),
              letterSpacing: 0.5,
            ),
          ),
        ),
      ],
    );
  }

  Widget _planetBanner(PlanetInfo planet, int stayDay, int remain) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: _panelBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: planet.color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: planet.color,
              boxShadow: [
                BoxShadow(
                  color: planet.color.withValues(alpha: 0.35),
                  blurRadius: 6,
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${planet.name.toUpperCase()} SECTOR',
                  style: GoogleFonts.spaceMono(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.88),
                    letterSpacing: 0.6,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '체류 $stayDay일차 · $remain일 남음',
                  style: GoogleFonts.spaceMono(
                    fontSize: 10,
                    color: Colors.white.withValues(alpha: 0.35),
                  ),
                ),
              ],
            ),
          ),
          Text(
            'D+${widget.tripDay}',
            style: GoogleFonts.spaceMono(
              fontSize: 11,
              color: const Color(0xFFFFD246).withValues(alpha: 0.65),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _moodSection() {
    return Container(
      padding: EdgeInsets.fromLTRB(12, 12, 12, 14),
      decoration: BoxDecoration(
        color: _moodCardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.06),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '오늘의 감정',
            style: GoogleFonts.spaceMono(
              fontSize: 9,
              color: Colors.white.withValues(alpha: 0.25),
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 40,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _moods.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                final m = _moods[i];
                final sel = i == _moodIndex;
                return Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => setState(() => _moodIndex = i),
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: sel
                            ? Colors.white.withValues(alpha: 0.1)
                            : Colors.white.withValues(alpha: 0.04),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: sel
                              ? Colors.white.withValues(alpha: 0.25)
                              : Colors.white.withValues(alpha: 0.08),
                        ),
                      ),
                      child: Text(
                        '${m.emoji}${m.label}',
                        style: GoogleFonts.spaceMono(
                          fontSize: 11,
                          color: Colors.white.withValues(alpha: 0.85),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _questCard({
    required PlanetInfo planet,
    required int doneCount,
    required List<bool> quests,
    required List<({String title, int xp})> defs,
  }) {
    final mission = '${planet.en.toUpperCase()} MISSION';
    final pc = planet.color;
    return Container(
      decoration: BoxDecoration(
        color: _panelBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: EdgeInsets.fromLTRB(14, 12, 14, 10),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: pc.withValues(alpha: 0.2)),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  mission,
                  style: GoogleFonts.spaceMono(
                    fontSize: 11,
                    color: const Color(0xFFFFD246).withValues(alpha: 0.85),
                    letterSpacing: 1,
                  ),
                ),
                Text(
                  '$doneCount/3 완료',
                  style: GoogleFonts.spaceMono(
                    fontSize: 10,
                    color: Colors.white.withValues(alpha: 0.45),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(10, 10, 10, 12),
            child: Column(
              children: List.generate(3, (i) {
                final done = i < quests.length && quests[i];
                final d = defs[i];
                return Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        ref
                            .read(questProvider.notifier)
                            .toggle(widget.tripDay, i);
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: done ? pc.withValues(alpha: 0.08) : null,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: EdgeInsets.only(top: 2),
                              child: Container(
                                width: 18,
                                height: 18,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(4),
                                  color: done
                                      ? pc.withValues(alpha: 0.2)
                                      : null,
                                  border: Border.all(
                                    color: done
                                        ? pc.withValues(alpha: 0.55)
                                        : Colors.white.withValues(alpha: 0.2),
                                    width: 1.2,
                                  ),
                                ),
                                child: done
                                    ? Icon(
                                        Icons.check,
                                        size: 12,
                                        color: pc.withValues(alpha: 0.95),
                                      )
                                    : null,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                d.title,
                                style: GoogleFonts.spaceMono(
                                  fontSize: 11,
                                  height: 1.35,
                                  color: Colors.white.withValues(
                                    alpha: done ? 0.35 : 0.82,
                                  ),
                                  decoration: done
                                      ? TextDecoration.lineThrough
                                      : null,
                                  decorationColor:
                                      Colors.white.withValues(alpha: 0.35),
                                ),
                              ),
                            ),
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                  color: done
                                      ? pc.withValues(alpha: 0.5)
                                      : Colors.white.withValues(alpha: 0.12),
                                ),
                              ),
                              child: Text(
                                '+${d.xp} XP',
                                style: GoogleFonts.spaceMono(
                                  fontSize: 9,
                                  color: done
                                      ? pc.withValues(alpha: 0.95)
                                      : Colors.white.withValues(alpha: 0.28),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  Widget _addPhotoButton() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _pickImage,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: 72,
          height: 72,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.15),
            ),
            color: _panelBg,
          ),
          child: Icon(
            Icons.add,
            color: Colors.white.withValues(alpha: 0.45),
            size: 28,
          ),
        ),
      ),
    );
  }
}

class _PhotoThumb extends StatelessWidget {
  const _PhotoThumb({
    required this.path,
    required this.loadBytes,
    required this.onRemove,
  });

  final String path;
  final Future<Uint8List> Function(String path) loadBytes;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: const Color(0xFF0E1420),
              border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
            ),
            child: kIsWeb
                ? Image.network(
                    path,
                    fit: BoxFit.cover,
                    width: 72,
                    height: 72,
                    errorBuilder: (_, __, ___) =>
                        const ColoredBox(color: Color(0xFF1a1a1a)),
                  )
                : FutureBuilder<Uint8List>(
                    future: loadBytes(path),
                    builder: (context, snap) {
                      if (snap.hasError || !snap.hasData) {
                        return const ColoredBox(color: Color(0xFF1a1a1a));
                      }
                      return Image.memory(
                        snap.data!,
                        fit: BoxFit.cover,
                        width: 72,
                        height: 72,
                        gaplessPlayback: true,
                        filterQuality: FilterQuality.low,
                      );
                    },
                  ),
          ),
        ),
        Positioned(
          top: -4,
          right: -4,
          child: Material(
            color: Colors.black54,
            shape: const CircleBorder(),
            child: InkWell(
              onTap: onRemove,
              customBorder: const CircleBorder(),
              child: Padding(
                padding: EdgeInsets.all(2),
                child: Icon(Icons.close, size: 14, color: Colors.white70),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _DiaryStarSample {
  const _DiaryStarSample({
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

class _DiaryStarfieldPainter extends CustomPainter {
  _DiaryStarfieldPainter(this.samples);

  final List<_DiaryStarSample> samples;

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
  bool shouldRepaint(covariant _DiaryStarfieldPainter oldDelegate) => false;
}

List<({String title, int xp})> _questsForPlanet(String nameKr) {
  const data = <String, List<({String title, int xp})>>{
    '수성': [
      (title: '속도: 오늘 가장 빠르게 느낀 순간 적기', xp: 15),
      (title: '변화: 작은 전환을 한 가지 시도하기', xp: 20),
      (title: '변화: 그 결과를 한 줄로 기록', xp: 25),
    ],
    '금성': [
      (title: '아름다움: 오늘 본 아름다운 것 한 가지', xp: 15),
      (title: '관계: 누군가에게 건넨 말 한마디', xp: 20),
      (title: '관계: 고마웠던 순간 메모', xp: 25),
    ],
    '지구': [
      (title: '자연: 창밖·산책에서 느낀 자연 한 조각', xp: 15),
      (title: '일상: 오늘의 루틴 중 편안했던 것', xp: 20),
      (title: '일상: 소소한 기쁨 한 줄', xp: 25),
    ],
    '화성': [
      (title: '도전: 오늘의 도전 과제 정의하기', xp: 15),
      (title: '에너지: 힘을 낸 순간 기록', xp: 20),
      (title: '에너지: 다음 행동 한 가지', xp: 25),
    ],
    '목성': [
      (title: '성장: 오늘 배운 것 한 가지', xp: 15),
      (title: '탐구: 궁금해진 질문 적기', xp: 20),
      (title: '탐구: 스스로 찾아본 내용 메모', xp: 25),
    ],
    '토성': [
      (title: '인내: 기다림이 필요했던 순간', xp: 15),
      (title: '규율: 지킨 약속·룰 한 가지', xp: 20),
      (title: '규율: 내일 지킬 한 가지', xp: 25),
    ],
    '천왕성': [
      (title: '창의: 떠올린 아이디어 스케치', xp: 15),
      (title: '혁신: 평소와 다른 시도', xp: 20),
      (title: '혁신: 남기고 싶은 인사이트', xp: 25),
    ],
    '해왕성': [
      (title: '감성: 오늘의 기분을 색으로 표현', xp: 15),
      (title: '꿈: 떠오른 장면·이미지', xp: 20),
      (title: '꿈: 마음에 남은 감정 한 줄', xp: 25),
    ],
  };
  return data[nameKr] ?? data['지구']!;
}
