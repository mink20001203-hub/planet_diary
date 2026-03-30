import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../providers/trip_provider.dart';

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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trip = ref.watch(tripProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF020408),
      body: SafeArea(
        child: Padding(
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
