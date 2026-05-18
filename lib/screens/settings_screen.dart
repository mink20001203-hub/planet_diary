import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../models/diary_entry.dart';
import '../providers/diary_provider.dart';
import '../providers/trip_provider.dart';
import '../services/backup_file_service.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

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

  String _formatStartDate(DateTime date) {
    final month = _monthAbbr[date.month - 1];
    return '${date.year} · $month · ${date.day.toString().padLeft(2, '0')}';
  }

  String _backupFileName() {
    final now = DateTime.now();
    final y = now.year.toString();
    final m = now.month.toString().padLeft(2, '0');
    final d = now.day.toString().padLeft(2, '0');
    return 'planet_diary_backup_$y$m$d.json';
  }

  void _showSnack(
    BuildContext context,
    String message, {
    bool isError = false,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: GoogleFonts.notoSansKr(fontSize: 12),
        ),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        backgroundColor:
            isError ? const Color(0xFF4A1A1A) : const Color(0xFF1A1A1A),
      ),
    );
  }

  Future<void> _exportBackup(BuildContext context, WidgetRef ref) async {
    try {
      final diaryMap = ref.read(diaryProvider);
      final settingsBox = await Hive.openBox('settings');
      final payload = {
        'schemaVersion': 1,
        'app': 'Planet Diary',
        'exportedAt': DateTime.now().toIso8601String(),
        'tripStartDate': settingsBox.get('tripStartDate'),
        'entries': diaryMap.values
            .map((entry) => entry.toBackupJson())
            .toList()
          ..sort((a, b) {
            return (a['tripDay'] as int).compareTo(b['tripDay'] as int);
          }),
      };
      const encoder = JsonEncoder.withIndent('  ');
      await BackupFileService.downloadJson(
        fileName: _backupFileName(),
        content: encoder.convert(payload),
      );
      if (!context.mounted) return;
      _showSnack(context, '백업 파일을 내보냈어요.');
    } catch (_) {
      if (!context.mounted) return;
      _showSnack(context, '백업 내보내기에 실패했어요.', isError: true);
    }
  }

  Future<void> _restoreBackup(BuildContext context, WidgetRef ref) async {
    try {
      final content = await BackupFileService.pickJsonFile();
      if (content == null) return;
      if (!context.mounted) return;

      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            backgroundColor: const Color(0xFF0E1420),
            title: Text(
              '백업 복원',
              style: GoogleFonts.notoSansKr(color: Colors.white),
            ),
            content: Text(
              '현재 저장된 일기 데이터가 백업 파일 내용으로 교체됩니다. 계속할까요?',
              style: GoogleFonts.notoSansKr(
                color: Colors.white70,
                fontSize: 13,
                height: 1.5,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: Text(
                  '취소',
                  style: GoogleFonts.notoSansKr(color: Colors.white54),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: Text(
                  '복원',
                  style: GoogleFonts.notoSansKr(
                    color: const Color(0xFFFFD246),
                  ),
                ),
              ),
            ],
          );
        },
      );
      if (confirmed != true) return;

      final decoded = jsonDecode(content);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('Invalid backup root');
      }
      final rawEntries = decoded['entries'];
      if (rawEntries is! List) {
        throw const FormatException('Invalid backup entries');
      }
      final entries = rawEntries.map((raw) {
        if (raw is! Map<String, dynamic>) {
          throw const FormatException('Invalid diary entry');
        }
        return DiaryEntry.fromBackupJson(raw);
      }).toList()
        ..sort((a, b) => a.tripDay.compareTo(b.tripDay));

      await ref.read(diaryProvider.notifier).replaceAll(entries);
      final startMillis = decoded['tripStartDate'];
      if (startMillis is int) {
        await ref
            .read(tripProvider.notifier)
            .setStartDate(DateTime.fromMillisecondsSinceEpoch(startMillis));
      }

      if (!context.mounted) return;
      _showSnack(context, '백업을 복원했어요. (${entries.length}개 기록)');
    } catch (_) {
      if (!context.mounted) return;
      _showSnack(context, '백업 복원에 실패했어요.', isError: true);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trip = ref.watch(tripProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF020408),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  InkWell(
                    onTap: () => context.pop(),
                    child: Text(
                      '\u2190 BACK',
                      style: GoogleFonts.spaceMono(
                        fontSize: 11,
                        color: Colors.white.withOpacity(0.5),
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Center(
                      child: Text(
                        'SETTINGS',
                        style: GoogleFonts.spaceMono(
                          fontSize: 14,
                          color: Colors.white.withOpacity(0.7),
                          letterSpacing: 1.5,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
              const SizedBox(height: 28),
              Text(
                '\uC5EC\uD589 \uC2DC\uC791\uC77C',
                style: GoogleFonts.spaceMono(
                  fontSize: 9,
                  color: Colors.white.withOpacity(0.25),
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF0E1420),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withOpacity(0.08)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _formatStartDate(trip.startDate),
                        style: GoogleFonts.spaceMono(
                          fontSize: 16,
                          color: Colors.white.withOpacity(0.9),
                        ),
                      ),
                    ),
                    OutlinedButton(
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: trip.startDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now(),
                          builder: (context, child) => Theme(
                            data: ThemeData.dark().copyWith(
                              colorScheme: const ColorScheme.dark(
                                primary: Color(0xFFFFD246),
                                surface: Color(0xFF0E1420),
                              ),
                            ),
                            child: child!,
                          ),
                        );

                        if (picked == null) return;

                        await ref.read(tripProvider.notifier).setStartDate(picked);
                        if (!context.mounted) return;

                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              '\uC5EC\uD589 \uC2DC\uC791\uC77C\uC774 \uBCC0\uACBD\uB410\uC5B4\uC694',
                            ),
                            behavior: SnackBarBehavior.floating,
                            duration: Duration(seconds: 1),
                            backgroundColor: Color(0xFF1A1A1A),
                          ),
                        );
                      },
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: Colors.white.withOpacity(0.2)),
                      ),
                      child: Text(
                        '\uB0A0\uC9DC \uBCC0\uACBD',
                        style: GoogleFonts.spaceMono(
                          fontSize: 11,
                          color: Colors.white.withOpacity(0.85),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Text(
                '\uBC31\uC5C5 / \uBCF5\uC6D0',
                style: GoogleFonts.spaceMono(
                  fontSize: 9,
                  color: Colors.white.withOpacity(0.25),
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF0E1420),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withOpacity(0.08)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      '일기 데이터를 JSON 파일로 저장하고, 다른 브라우저나 기기에서 다시 복원할 수 있어요.',
                      style: GoogleFonts.notoSansKr(
                        fontSize: 12,
                        height: 1.5,
                        color: Colors.white.withOpacity(0.38),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => _exportBackup(context, ref),
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(
                                color: const Color(0xFFFFD246).withOpacity(0.35),
                              ),
                            ),
                            child: Text(
                              '백업 내보내기',
                              style: GoogleFonts.notoSansKr(
                                fontSize: 12,
                                color: const Color(0xFFFFD246),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => _restoreBackup(context, ref),
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(
                                color: Colors.white.withOpacity(0.2),
                              ),
                            ),
                            child: Text(
                              '복원하기',
                              style: GoogleFonts.notoSansKr(
                                fontSize: 12,
                                color: Colors.white.withOpacity(0.85),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Text(
                '\uC571 \uC815\uBCF4',
                style: GoogleFonts.spaceMono(
                  fontSize: 9,
                  color: Colors.white.withOpacity(0.25),
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF0E1420),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withOpacity(0.08)),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Planet Diary v1.0.0',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color.fromRGBO(255, 255, 255, 0.3),
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      '365\uC77C \uD0DC\uC591\uACC4 \uC5EC\uD589 \uC77C\uAE30',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color.fromRGBO(255, 255, 255, 0.3),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
