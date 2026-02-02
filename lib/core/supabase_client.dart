import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Instância global do SupabaseClient para uso em todo o app
final supabase = Supabase.instance.client;

/// Configurações do Supabase carregadas de variáveis de ambiente
/// Com fallback para valores compilados via --dart-define
class SupabaseConfig {
  // Valores passados via --dart-define (fallback para build de release)
  static const String _compiledUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: '',
  );
  static const String _compiledKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: '',
  );

  /// URL do projeto Supabase
  static String get supabaseUrl {
    // Primeiro tenta do .env (funciona em debug)
    final url = dotenv.env['SUPABASE_URL'];
    if (url != null && url.isNotEmpty) {
      return url;
    }
    // Fallback para valor compilado
    if (_compiledUrl.isNotEmpty) {
      return _compiledUrl;
    }
    throw Exception(
      'SUPABASE_URL não configurada. Verifique o arquivo .env',
    );
  }

  /// Chave anônima do Supabase
  static String get supabaseAnonKey {
    // Primeiro tenta do .env (funciona em debug)
    final key = dotenv.env['SUPABASE_ANON_KEY'];
    if (key != null && key.isNotEmpty) {
      return key;
    }
    // Fallback para valor compilado
    if (_compiledKey.isNotEmpty) {
      return _compiledKey;
    }
    throw Exception(
      'SUPABASE_ANON_KEY não configurada. Verifique o arquivo .env',
    );
  }
}
