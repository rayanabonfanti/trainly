import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Provider para gerenciar tema claro/escuro
class ThemeProvider extends ChangeNotifier {
  static const String _themeKey = 'theme_mode';
  
  ThemeMode _themeMode = ThemeMode.system;
  SharedPreferences? _prefs;

  ThemeMode get themeMode => _themeMode;

  bool get isDarkMode {
    if (_themeMode == ThemeMode.system) {
      return WidgetsBinding.instance.platformDispatcher.platformBrightness == 
             Brightness.dark;
    }
    return _themeMode == ThemeMode.dark;
  }

  ThemeProvider() {
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    _prefs = await SharedPreferences.getInstance();
    final savedTheme = _prefs?.getString(_themeKey);
    
    if (savedTheme != null) {
      _themeMode = ThemeMode.values.firstWhere(
        (e) => e.name == savedTheme,
        orElse: () => ThemeMode.system,
      );
      notifyListeners();
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    await _prefs?.setString(_themeKey, mode.name);
    notifyListeners();
  }

  void toggleTheme() {
    if (_themeMode == ThemeMode.dark) {
      setThemeMode(ThemeMode.light);
    } else {
      setThemeMode(ThemeMode.dark);
    }
  }
}

/// Cores do app - Azul Ciano para vibe de saúde e bem-estar
class AppColors {
  // Cores principais do gradiente ciano
  static const Color cyanPrimary = Color(0xFF00BCD4);      // Ciano principal
  static const Color cyanLight = Color(0xFF4DD0E1);        // Ciano claro
  static const Color cyanDark = Color(0xFF0097A7);         // Ciano escuro
  static const Color tealAccent = Color(0xFF1DE9B6);       // Teal vibrante
  static const Color aqua = Color(0xFF00E5FF);             // Aqua brilhante
  
  // Cores secundárias complementares
  static const Color mintGreen = Color(0xFF69F0AE);        // Verde menta (saúde)
  static const Color oceanBlue = Color(0xFF0288D1);        // Azul oceano
  
  // Gradientes para UI
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [cyanDark, cyanPrimary, cyanLight],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  static const LinearGradient energyGradient = LinearGradient(
    colors: [cyanPrimary, tealAccent],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  static const LinearGradient freshGradient = LinearGradient(
    colors: [aqua, cyanPrimary],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
  
  static const LinearGradient vitalityGradient = LinearGradient(
    colors: [cyanLight, mintGreen],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );
  
  // Gradiente para AppBar
  static const LinearGradient appBarGradient = LinearGradient(
    colors: [cyanDark, cyanPrimary],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  // Gradiente para botões
  static const LinearGradient buttonGradient = LinearGradient(
    colors: [cyanPrimary, tealAccent],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );
  
  // Gradiente suave para cards no tema escuro
  static const LinearGradient darkCardGradient = LinearGradient(
    colors: [Color(0xFF1A3A3F), Color(0xFF0D2327)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

/// Temas do app
class AppTheme {
  static const _primaryColor = AppColors.cyanPrimary;
  static const _secondaryColor = AppColors.tealAccent;

  /// Tema claro
  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: ColorScheme.fromSeed(
      seedColor: _primaryColor,
      secondary: _secondaryColor,
      brightness: Brightness.light,
    ).copyWith(
      primary: AppColors.cyanPrimary,
      secondary: AppColors.tealAccent,
      tertiary: AppColors.mintGreen,
    ),
    appBarTheme: const AppBarTheme(
      centerTitle: true,
      elevation: 0,
      backgroundColor: AppColors.cyanPrimary,
      foregroundColor: Colors.white,
    ),
    cardTheme: CardThemeData(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.cyanLight.withValues(alpha: 0.1),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.cyanLight),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.cyanPrimary, width: 2),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: AppColors.cyanLight.withValues(alpha: 0.5)),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.cyanPrimary,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.cyanPrimary,
        side: const BorderSide(color: AppColors.cyanPrimary),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: AppColors.cyanPrimary,
      foregroundColor: Colors.white,
    ),
    chipTheme: ChipThemeData(
      backgroundColor: AppColors.cyanLight.withValues(alpha: 0.2),
      selectedColor: AppColors.cyanPrimary,
      labelStyle: const TextStyle(color: AppColors.cyanDark),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: AppColors.cyanPrimary,
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return AppColors.cyanPrimary;
        }
        return Colors.grey;
      }),
      trackColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return AppColors.cyanLight;
        }
        return Colors.grey.shade300;
      }),
    ),
  );

  /// Tema escuro
  static ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: ColorScheme.fromSeed(
      seedColor: _primaryColor,
      secondary: _secondaryColor,
      brightness: Brightness.dark,
    ).copyWith(
      primary: AppColors.cyanLight,
      secondary: AppColors.tealAccent,
      tertiary: AppColors.mintGreen,
      surface: const Color(0xFF121212),
    ),
    scaffoldBackgroundColor: const Color(0xFF0A1416),
    appBarTheme: const AppBarTheme(
      centerTitle: true,
      elevation: 0,
      backgroundColor: Color(0xFF0D2327),
      foregroundColor: AppColors.cyanLight,
    ),
    cardTheme: CardThemeData(
      elevation: 4,
      color: const Color(0xFF1A2C2F),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFF1A2C2F),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.cyanDark),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.cyanLight, width: 2),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: AppColors.cyanDark.withValues(alpha: 0.5)),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.cyanPrimary,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.cyanLight,
        side: const BorderSide(color: AppColors.cyanLight),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: AppColors.cyanPrimary,
      foregroundColor: Colors.white,
    ),
    chipTheme: ChipThemeData(
      backgroundColor: AppColors.cyanDark.withValues(alpha: 0.3),
      selectedColor: AppColors.cyanPrimary,
      labelStyle: const TextStyle(color: AppColors.cyanLight),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: AppColors.cyanLight,
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return AppColors.cyanLight;
        }
        return Colors.grey;
      }),
      trackColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return AppColors.cyanDark;
        }
        return Colors.grey.shade800;
      }),
    ),
    dividerTheme: DividerThemeData(
      color: AppColors.cyanDark.withValues(alpha: 0.3),
    ),
  );
}
