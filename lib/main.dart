// Starts the app and provides shared authentication and inventory state.
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'data/stock_repository.dart';
import 'providers/auth_provider.dart';
import 'providers/inventory_provider.dart';
import 'screens/auth_gate.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final auth = AuthProvider();
  await auth.initialize();
  final inventory = InventoryProvider();
  try {
    await inventory.repo.ensurePresentationData();
  } catch (error, stackTrace) {
    debugPrint('Presentation data initialization failed: $error\n$stackTrace');
  }
  await inventory.refresh();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: inventory),
        ChangeNotifierProvider.value(value: auth),
      ],
      child: const WaterWorldApp(),
    ),
  );
}

class WaterWorldApp extends StatelessWidget {
  const WaterWorldApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Water World',
      locale: const Locale('th'),
      supportedLocales: const [Locale('th')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme:
            ColorScheme.fromSeed(
              seedColor: const Color(0xFF1687D9),
              surface: const Color(0xFFF3F9FF),
            ).copyWith(
              primary: const Color(0xFF0877C9),
              secondary: const Color(0xFF39A9E8),
              tertiary: const Color(0xFFFF9F43),
              surface: const Color(0xFFF3F9FF),
            ),
        scaffoldBackgroundColor: const Color(0xFFF3F9FF),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFE5F3FF),
          foregroundColor: Color(0xFF123B5D),
          surfaceTintColor: Colors.transparent,
        ),
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 1,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: const BorderSide(color: Color(0xFFDCEEFF)),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFFF5FAFF),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFFC8E4FA)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFFC8E4FA)),
          ),
        ),
        useMaterial3: true,
      ),
      home: const AuthGate(),
    );
  }
}
