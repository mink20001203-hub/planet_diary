import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'models/diary_entry.dart';
import 'router.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  Hive.registerAdapter(DiaryEntryAdapter());
  await Hive.openBox<DiaryEntry>('diary');
  runApp(const ProviderScope(child: PlanetDiaryApp()));
}

class PlanetDiaryApp extends StatelessWidget {
  const PlanetDiaryApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Planet Diary',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF020408),
        textTheme: GoogleFonts.spaceMonoTextTheme(
          ThemeData.dark().textTheme,
        ),
      ),
      routerConfig: appRouter,
    );
  }
}
