import 'package:supabase_flutter/supabase_flutter.dart';

/// Instância global do SupabaseClient para uso em todo o app
final supabase = Supabase.instance.client;

/// Configurações do Supabase
class SupabaseConfig {
  static const String supabaseUrl = 'https://vebcapnzmndgfzmyuyzh.supabase.co';
  static const String supabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZlYmNhcG56bW5kZ2Z6bXl1eXpoIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Njk3ODQzNjEsImV4cCI6MjA4NTM2MDM2MX0.SlVwm6DYrzgHynZViSUIaZSlJ1XTykiT8IspinfGX5Y';
}
