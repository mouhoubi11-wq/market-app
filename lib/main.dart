import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config.dart';
import 'repository.dart';
import 'screens/home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final configured =
      !kSupabaseUrl.contains('VOTRE') && !kSupabaseAnonKey.contains('VOTRE');
  if (!configured) {
    runApp(const _ConfigErrorApp(
        'Remplis kSupabaseUrl et kSupabaseAnonKey dans lib/config.dart.'));
    return;
  }

  try {
    await Supabase.initialize(url: kSupabaseUrl, anonKey: kSupabaseAnonKey);
  } catch (e) {
    runApp(_ConfigErrorApp('Initialisation impossible : $e'));
    return;
  }

  AnnouncementRepository.ensureSignedIn().catchError((_) {});

  runApp(const MarketApp());
}

class _ConfigErrorApp extends StatelessWidget {
  final String message;
  const _ConfigErrorApp(this.message);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('Configuration manquante\n\n$message',
                textAlign: TextAlign.center, style: const TextStyle(fontSize: 16)),
          ),
        ),
      ),
    );
  }
}

class MarketApp extends StatelessWidget {
  const MarketApp({super.key});

  static const Color coral = Color(0xFFFF6B35);
  static const Color pink = Color(0xFFFF3D71);
  static const Color mint = Color(0xFF26D0CE);
  static const Color sun = Color(0xFFFFD93D);
  static const Color cream = Color(0xFFFFF8F0);

  @override
  Widget build(BuildContext context) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: coral,
      brightness: Brightness.light,
    ).copyWith(
      primary: coral,
      onPrimary: Colors.white,
      secondary: mint,
      onSecondary: Colors.white,
      tertiary: sun,
      surface: Colors.white,
      surfaceTint: Colors.transparent,
    );

    return MaterialApp(
      title: 'VENDORA', // <-- NOM CHANGÉ ICI
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: colorScheme,
        scaffoldBackgroundColor: cream,
        appBarTheme: const AppBarTheme(
          backgroundColor: coral,
          foregroundColor: Colors.white,
          elevation: 0,
          centerTitle: false,
          titleTextStyle: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
          iconTheme: IconThemeData(color: Colors.white),
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: pink,
          foregroundColor: Colors.white,
          elevation: 4,
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: coral,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
        cardTheme: CardThemeData(
          elevation: 2,
          shadowColor: coral.withOpacity(0.15),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          color: Colors.white,
        ),
        chipTheme: ChipThemeData(
          backgroundColor: Colors.white,
          selectedColor: coral,
          side: BorderSide(color: Colors.grey.shade300),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          labelStyle: const TextStyle(fontWeight: FontWeight.w600),
          secondaryLabelStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.grey.shade300)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.grey.shade300)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: coral, width: 2)),
        ),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: Colors.white,
          indicatorColor: coral.withOpacity(0.18),
          labelTextStyle: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return const TextStyle(color: coral, fontWeight: FontWeight.bold, fontSize: 12);
            }
            return const TextStyle(color: Colors.black54, fontSize: 12);
          }),
          iconTheme: WidgetStateProperty.resolveWith((states) {
            return IconThemeData(color: states.contains(WidgetState.selected) ? coral : Colors.black54);
          }),
        ),
        snackBarTheme: SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          backgroundColor: const Color(0xFF2D2D2D),
        ),
      ),
      home: const HomeScreen(),
    );
  }
}
