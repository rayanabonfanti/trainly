import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Instância global do SupabaseClient para uso em todo o app
final supabase = Supabase.instance.client;

/// Configurações do Supabase carregadas de variáveis de ambiente
class SupabaseConfig {
  /// URL do projeto Supabase (carregado de .env)
  static String get supabaseUrl {
    final url = dotenv.env['SUPABASE_URL'];
    if (url == null || url.isEmpty) {
      throw Exception(
        'SUPABASE_URL não configurada. Verifique o arquivo .env',
      );
    }
    return url;
  }

  /// Chave anônima do Supabase (carregada de .env)
  static String get supabaseAnonKey {
    final key = dotenv.env['SUPABASE_ANON_KEY'];
    if (key == null || key.isEmpty) {
      throw Exception(
        'SUPABASE_ANON_KEY não configurada. Verifique o arquivo .env',
      );
    }
    return key;
  }
}
