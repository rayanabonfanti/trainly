/// Configurações do Supabase
/// 
/// IMPORTANTE: Antes de rodar o app, você precisa:
/// 1. Criar um projeto no Supabase (https://supabase.com)
/// 2. Ativar o Google Provider em Authentication > Providers
/// 3. Configurar as credenciais OAuth do Google Cloud Console
/// 4. Substituir os valores abaixo pelos do seu projeto

class SupabaseConfig {
  // URL do seu projeto Supabase
  // Encontre em: Project Settings > API > Project URL
  static const String supabaseUrl = 'https://vebcapnzmndgfzmyuyzh.supabase.co';
  
  // Chave anônima (anon key) do Supabase
  // Encontre em: Project Settings > API > anon public key
  static const String supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZlYmNhcG56bW5kZ2Z6bXl1eXpoIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Njk3ODQzNjEsImV4cCI6MjA4NTM2MDM2MX0.SlVwm6DYrzgHynZViSUIaZSlJ1XTykiT8IspinfGX5Y';
}
