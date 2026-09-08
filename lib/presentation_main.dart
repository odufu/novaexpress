import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'presentation/config/theme.dart';
import 'presentation/presentation_root.dart';

/// Standalone entry point for the NovaXpress Interactive 3D Presentation.
///
/// Run independently via:
/// flutter run -t lib/presentation_main.dart -d chrome
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const NovaXpressPresentationApp());
}

class NovaXpressPresentationApp extends StatelessWidget {
  const NovaXpressPresentationApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NovaXpress Logistics • Interactive 3D Presentation',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.light,
      theme: ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: PresentationTheme.lightBackground,
        colorScheme: const ColorScheme.light(
          primary: PresentationTheme.monoAccent,
          secondary: PresentationTheme.brightOrange,
          surface: PresentationTheme.lightSurface,
        ),
        textTheme: GoogleFonts.interTextTheme(ThemeData.light().textTheme),
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: PresentationTheme.backgroundBlack,
        colorScheme: const ColorScheme.dark(
          primary: PresentationTheme.novaOrange,
          secondary: PresentationTheme.brightOrange,
          surface: PresentationTheme.primaryNavy,
        ),
        textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme),
      ),
      home: const PresentationRoot(),
    );
  }
}
