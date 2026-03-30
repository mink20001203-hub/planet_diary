import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'models/diary_entry.dart';
import 'router.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  debugPrint('--- APP STARTING ---');
  
  try {
    debugPrint('Initializing Hive...');
    await Hive.initFlutter();
    
    debugPrint('Registering Adapter...');
    Hive.registerAdapter(DiaryEntryAdapter());
    
    debugPrint('Opening Diary Box...');
    await Hive.openBox<DiaryEntry>('diary');
    
    debugPrint('--- HIVE READY, STARTING UI ---');
    runApp(const ProviderScope(child: PlanetDiaryApp()));
  } catch (e) {
    debugPrint('FATAL ERROR DURING INIT: $e');
  }
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
