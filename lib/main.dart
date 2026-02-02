import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth/auth_gate.dart';
import 'core/booking_rules.dart';
import 'core/supabase_client.dart';
import 'core/theme_provider.dart';

/// Provider global para tema
final themeProvider = ThemeProvider();

/// Armazena erro de inicialização para mostrar na tela
String? _initError;

void main() async {
  // Captura erros não tratados e mostra na tela
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    // Captura erros do Flutter framework
    FlutterError.onError = (details) {
      FlutterError.presentError(details);
      _initError = 'Flutter Error: ${details.exception}\n\n${details.stack}';
    };

    // Carrega .env apenas em debug (em release, usa --dart-define)
    if (kDebugMode) {
      try {
        await dotenv.load(fileName: '.env');
      } catch (e) {
        debugPrint('Aviso: .env não encontrado: $e');
      }
    }

    try {
      await Supabase.initialize(
        url: SupabaseConfig.supabaseUrl,
        anonKey: SupabaseConfig.supabaseAnonKey,
      );

      // Inicializa as regras de negócio dinâmicas
      try {
        await BookingRules.initialize();
      } catch (e) {
        debugPrint('Aviso: Não foi possível carregar configurações: $e');
      }
    } catch (e, stack) {
      _initError = 'Erro Supabase: $e\n\nStack: $stack';
      debugPrint('Erro ao inicializar Supabase: $e');
    }

    runApp(const TrainlyApp());
  }, (error, stack) {
    // Erro não capturado - mostra app com erro
    _initError = 'Erro Fatal: $error\n\nStack: $stack';
    runApp(ErrorApp(error: _initError!));
  });
}

/// App de erro para quando há falha crítica
class ErrorApp extends StatelessWidget {
  final String error;
  
  const ErrorApp({super.key, required this.error});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        backgroundColor: Colors.red.shade50,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                const Icon(Icons.error_outline, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                const Text(
                  'Erro ao iniciar o app',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: SingleChildScrollView(
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red.shade200),
                      ),
                      child: SelectableText(
                        error,
                        style: const TextStyle(
                          fontSize: 12,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Tire um screenshot e envie para o desenvolvedor',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class TrainlyApp extends StatefulWidget {
  const TrainlyApp({super.key});

  @override
  State<TrainlyApp> createState() => _TrainlyAppState();
}

class _TrainlyAppState extends State<TrainlyApp> {
  @override
  void initState() {
    super.initState();
    themeProvider.addListener(_onThemeChanged);
  }

  @override
  void dispose() {
    themeProvider.removeListener(_onThemeChanged);
    super.dispose();
  }

  void _onThemeChanged() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Trainly',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeProvider.themeMode,
      // Localizações para DatePicker, TimePicker, calendário, etc.
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('pt', 'BR'),
        Locale('en', 'US'),
      ],
      locale: const Locale('pt', 'BR'),
      home: const AuthGate(),
    );
  }
}
