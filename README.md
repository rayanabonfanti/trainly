# Trainly

App de treinos com autenticação via Google usando Supabase.

## Configuração Necessária

### 1. Supabase

1. Crie um projeto no [Supabase](https://supabase.com)
2. Vá em **Project Settings > API** e copie:
   - `Project URL` → substitua `YOUR_SUPABASE_URL` em `lib/config/supabase_config.dart`
   - `anon public key` → substitua `YOUR_SUPABASE_ANON_KEY`

### 2. Google Cloud Console

1. Acesse o [Google Cloud Console](https://console.cloud.google.com)
2. Crie um projeto (ou use existente)
3. Ative a **Google Sign-In API**
4. Vá em **APIs & Services > Credentials**
5. Crie um **OAuth 2.0 Client ID** do tipo **Web application**:
   - Nome: `Trainly Web`
   - Authorized redirect URIs: `https://YOUR_SUPABASE_PROJECT_REF.supabase.co/auth/v1/callback`
   - Copie o **Client ID** e **Client Secret**

### 3. Configurar Google Provider no Supabase

1. No Supabase, vá em **Authentication > Providers**
2. Ative **Google**
3. Configure:
   - **Client ID**: o Web Client ID criado no Google Cloud
   - **Client Secret**: o secret do Web Client ID

### 4. Configurar Redirect URL no Supabase

1. No Supabase, vá em **Authentication > URL Configuration**
2. Em **Redirect URLs**, adicione:
   - `io.supabase.trainly://login-callback`

### 5. Executar o App

```bash
flutter pub get
flutter run
```

## Estrutura do Projeto

```
lib/
├── config/
│   └── supabase_config.dart   # URL e Anon Key do Supabase
├── screens/
│   ├── home_screen.dart       # Tela após login
│   └── login_screen.dart      # Tela de login
└── main.dart                  # Inicialização e AuthGate
```

## Fluxo de Autenticação

1. App inicia e verifica sessão existente (`AuthGate`)
2. Se não logado, mostra `LoginScreen`
3. Usuário clica "Entrar com Google"
4. `signInWithOAuth` abre o browser
5. Supabase redireciona para Google
6. Google autentica e redireciona de volta para Supabase
7. Supabase valida e redireciona para o app via deep link
8. App detecta a sessão e navega para `HomeScreen`

## Troubleshooting

### Erro "Invalid redirect"
- Verifique se `io.supabase.trainly://login-callback` está em **Authentication > URL Configuration > Redirect URLs** no Supabase

### Login abre browser mas não volta ao app
- Confirme o deep link no `android/app/src/main/AndroidManifest.xml`
- O scheme deve ser `io.supabase.trainly` e host `login-callback`

### Login não persiste
- O Supabase Flutter persiste a sessão automaticamente
- Verifique se o `Supabase.initialize()` está sendo chamado antes do `runApp()`
