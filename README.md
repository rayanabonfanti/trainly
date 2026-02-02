# Trainly

Sistema completo de gestão para academias, escolas de natação e centros de treinamento. Permite gerenciamento de aulas, reservas, check-in de alunos e controle de frequência com suporte a múltiplas empresas (multi-tenant).

## Índice

- [Visão Geral](#visão-geral)
- [Funcionalidades](#funcionalidades)
- [Stack Tecnológico](#stack-tecnológico)
- [Arquitetura](#arquitetura)
- [Regras de Negócio](#regras-de-negócio)
- [Banco de Dados](#banco-de-dados)
- [Variáveis de Ambiente](#variáveis-de-ambiente)
- [Configuração](#configuração)
- [Build e Deploy](#build-e-deploy)
- [Testes](#testes)
- [Segurança](#segurança)
- [Estrutura do Projeto](#estrutura-do-projeto)

---

## Visão Geral

O Trainly é um aplicativo Flutter multiplataforma (Android, iOS, Web, Desktop) que oferece:

- **Multi-tenant**: Suporte a múltiplas empresas/academias
- **Sistema de Membros**: Alunos solicitam acesso e admins aprovam
- **Reservas Inteligentes**: Com validação de conflitos, limites e antecedência
- **Check-in**: Controle de presença em tempo real
- **Dashboard Admin**: Métricas e estatísticas de ocupação
- **Tema Adaptável**: Light/Dark mode com persistência

---

## Funcionalidades

### Para Alunos

| Funcionalidade | Descrição |
|----------------|-----------|
| Visualização de Aulas | Lista e calendário com aulas disponíveis |
| Reservas | Reservar aulas futuras com controle de vagas |
| Cancelamentos | Cancelar reservas respeitando prazos configuráveis |
| Histórico | Ver frequência e aulas já realizadas |
| Múltiplas Academias | Solicitar acesso a diferentes empresas |
| Perfil | Editar nome, telefone e foto de perfil |
| Tema | Suporte a light/dark mode |

### Para Administradores

| Funcionalidade | Descrição |
|----------------|-----------|
| Gerenciamento de Aulas | CRUD completo de aulas/treinos |
| Tipos de Aula | Criar tipos personalizados (Natação, Funcional, Yoga, etc.) |
| Check-in | Marcar presença dos alunos em tempo real |
| Dashboard | Estatísticas de ocupação e frequência |
| Gestão de Membros | Aprovar/rejeitar/suspender solicitações de acesso |
| Gestão de Admins | Promover usuários para administradores |
| Configurações | Regras de negócio dinâmicas |

---

## Stack Tecnológico

| Camada | Tecnologia |
|--------|------------|
| **Frontend** | Flutter 3.10+ com Material Design 3 |
| **Backend** | Supabase (PostgreSQL + Auth + Storage + Realtime) |
| **Autenticação** | Supabase Auth (Email/Password + OAuth) |
| **Armazenamento** | Supabase Storage (avatars, logos) |
| **Configuração** | flutter_dotenv + dart-define |
| **Calendário** | table_calendar |
| **Gráficos** | fl_chart |

### Dependências Principais

```yaml
dependencies:
  flutter: sdk
  supabase_flutter: ^2.8.0      # Backend as a Service
  flutter_dotenv: ^5.1.0        # Variáveis de ambiente
  table_calendar: ^3.1.2        # Calendário visual
  shimmer: ^3.0.0               # Loading skeleton
  fl_chart: ^0.69.2             # Gráficos para dashboard
  image_picker: ^1.1.2          # Seletor de imagem
  shared_preferences: ^2.3.3    # Armazenamento local
  mask_text_input_formatter: ^2.9.0 # Máscaras de input
```

---

## Arquitetura

### Padrões Utilizados

| Padrão | Uso |
|--------|-----|
| **Clean Architecture** | Separação em camadas (models, services, pages) |
| **Repository Pattern** | Services encapsulam acesso a dados |
| **Factory Pattern** | Constructors `fromJson`/`toJson` para serialização |
| **Singleton** | `BookingRules` para regras de negócio globais |
| **Result Pattern** | Classes `*Result` para retorno tipado de operações |

### Estrutura de Camadas

```
┌─────────────────────────────────────────┐
│              UI (Pages)                 │
│   admin/, auth/, home/, calendar/...    │
├─────────────────────────────────────────┤
│            Business Logic               │
│     core/ (rules, validators, theme)    │
├─────────────────────────────────────────┤
│              Services                   │
│  booking_service, classes_service...    │
├─────────────────────────────────────────┤
│               Models                    │
│   Booking, SwimClass, UserProfile...    │
├─────────────────────────────────────────┤
│          Supabase Client                │
│     supabase_client.dart (singleton)    │
└─────────────────────────────────────────┘
```

---

## Regras de Negócio

### Configurações Dinâmicas

Todas as regras são **configuráveis pelo administrador** em tempo real. Os valores são armazenados na tabela `business_settings` e carregados no início do app.

| Regra | Padrão | Descrição |
|-------|--------|-----------|
| `cancellation_deadline_hours` | 0 | Horas antes da aula para permitir cancelamento (0 = sem restrição) |
| `max_cancellations_per_month` | 0 | Limite de cancelamentos por mês |
| `cancellation_limit_enabled` | false | Se o limite de cancelamentos está ativo |
| `max_bookings_per_week` | 0 | Limite de reservas ativas por semana |
| `booking_limit_enabled` | false | Se o limite de reservas está ativo |
| `min_booking_advance_hours` | 0 | Antecedência mínima para reservar (0 = pode reservar a qualquer momento) |
| `default_class_capacity` | 10 | Capacidade padrão ao criar novas aulas |
| `default_lanes` | 4 | Número de vagas padrão |
| `class_types` | JSON | Tipos de aula personalizáveis |

### Tipos de Aula

Os tipos são armazenados como JSON e podem ser personalizados:

```json
[
  {"id": "class", "name": "Aula", "icon": "school"},
  {"id": "free", "name": "Treino Livre", "icon": "fitness_center"},
  {"id": "swimming", "name": "Natação", "icon": "pool"},
  {"id": "yoga", "name": "Yoga", "icon": "accessibility"}
]
```

### Regras de Reserva

| Regra | Comportamento |
|-------|---------------|
| **Aulas Futuras** | Reservas só podem ser feitas para aulas a partir do dia seguinte |
| **Antecedência Mínima** | Configurável (ex: 24h antes) |
| **Limite Semanal** | Configurável (ex: máximo 3 reservas por semana) |
| **Vagas Limitadas** | Cada aula tem capacidade máxima |
| **Sem Duplicatas** | Usuário não pode reservar a mesma aula duas vezes |
| **Conflito de Horário** | Não é permitido reservar aulas com horários sobrepostos |
| **Membership** | Usuário precisa ser membro aprovado da academia |

### Regras de Cancelamento

| Regra | Comportamento |
|-------|---------------|
| **Deadline** | Configurável (ex: 2 horas antes da aula) |
| **Limite Mensal** | Configurável (ex: máximo 2 cancelamentos por mês) |
| **Registro** | Cancelamentos são registrados para controle |
| **Ownership** | Apenas o dono da reserva pode cancelá-la |
| **Admin Override** | Admins podem cancelar qualquer reserva |

### Regras de Membership

| Status | Descrição | Pode Reservar |
|--------|-----------|---------------|
| `pending` | Aguardando aprovação | Não |
| `approved` | Membro ativo | Sim |
| `rejected` | Solicitação recusada | Não |
| `suspended` | Membro suspenso | Não |

### Permissões por Role

| Ação | Student | Admin |
|------|---------|-------|
| Ver aulas da academia | ✅ | ✅ |
| Reservar aulas | ✅ (se aprovado) | ❌ |
| Cancelar própria reserva | ✅ | ✅ |
| Cancelar qualquer reserva | ❌ | ✅ |
| Criar/editar aulas | ❌ | ✅ |
| Fazer check-in | ❌ | ✅ |
| Ver dashboard | ❌ | ✅ |
| Aprovar membros | ❌ | ✅ |
| Promover admins | ❌ | ✅ |
| Configurar regras | ❌ | ✅ |

---

## Banco de Dados

### Diagrama de Relacionamentos

```
┌──────────────┐     ┌──────────────┐     ┌──────────────┐
│   profiles   │────<│   bookings   │>────│   classes    │
└──────────────┘     └──────────────┘     └──────────────┘
       │                    │                    │
       │                    │                    │
       ▼                    ▼                    │
┌──────────────┐     ┌──────────────┐            │
│  businesses  │<────│cancellations │            │
└──────────────┘     └──────────────┘            │
       │                                         │
       │                                         │
       ▼                                         │
┌──────────────────┐        ┌──────────────────┐│
│business_members  │        │business_settings ││
└──────────────────┘        └──────────────────┘│
                                                │
                            ┌───────────────────┘
                            ▼
                     ┌──────────────┐
                     │    admins    │
                     └──────────────┘
```

### Tabelas

#### `profiles`
Perfis de usuários (sincronizado com auth.users)

| Coluna | Tipo | Constraints | Descrição |
|--------|------|-------------|-----------|
| `id` | UUID | PK, FK → auth.users | ID do usuário |
| `email` | TEXT | NOT NULL | Email do usuário |
| `name` | TEXT | | Nome de exibição |
| `phone` | TEXT | | Telefone |
| `avatar_url` | TEXT | | URL do avatar |
| `role` | TEXT | DEFAULT 'student' | 'student' ou 'admin' |
| `business_id` | UUID | FK → businesses | Empresa que o admin gerencia |
| `created_at` | TIMESTAMPTZ | DEFAULT now() | Data de criação |
| `updated_at` | TIMESTAMPTZ | | Data de atualização |

#### `businesses`
Empresas/Academias cadastradas

| Coluna | Tipo | Constraints | Descrição |
|--------|------|-------------|-----------|
| `id` | UUID | PK, DEFAULT uuid_generate_v4() | ID da empresa |
| `name` | TEXT | NOT NULL | Nome da empresa |
| `slug` | TEXT | UNIQUE, NOT NULL | Identificador único para URL |
| `description` | TEXT | | Descrição |
| `logo_url` | TEXT | | URL do logo |
| `address` | TEXT | | Endereço |
| `phone` | TEXT | | Telefone |
| `email` | TEXT | | Email de contato |
| `owner_id` | UUID | FK → auth.users | ID do proprietário |
| `is_active` | BOOLEAN | DEFAULT true | Se está ativa |
| `created_at` | TIMESTAMPTZ | DEFAULT now() | Data de criação |
| `updated_at` | TIMESTAMPTZ | | Data de atualização |

#### `business_members`
Associação de usuários com empresas

| Coluna | Tipo | Constraints | Descrição |
|--------|------|-------------|-----------|
| `id` | UUID | PK, DEFAULT uuid_generate_v4() | ID do membership |
| `user_id` | UUID | FK → auth.users | ID do usuário |
| `business_id` | UUID | FK → businesses | ID da empresa |
| `status` | TEXT | DEFAULT 'pending' | pending/approved/rejected/suspended |
| `rejection_reason` | TEXT | | Motivo da rejeição |
| `requested_at` | TIMESTAMPTZ | DEFAULT now() | Data da solicitação |
| `approved_at` | TIMESTAMPTZ | | Data da aprovação |
| `rejected_at` | TIMESTAMPTZ | | Data da rejeição |
| `approved_by` | UUID | FK → auth.users | Quem aprovou |
| `created_at` | TIMESTAMPTZ | DEFAULT now() | Data de criação |
| `updated_at` | TIMESTAMPTZ | | Data de atualização |

**Constraints:**
- `UNIQUE(user_id, business_id)` - Um usuário só pode ter um membership por empresa

#### `classes`
Aulas/Sessões de treinamento

| Coluna | Tipo | Constraints | Descrição |
|--------|------|-------------|-----------|
| `id` | UUID | PK, DEFAULT uuid_generate_v4() | ID da aula |
| `title` | TEXT | NOT NULL | Título da aula |
| `description` | TEXT | | Descrição |
| `start_time` | TIMESTAMPTZ | NOT NULL | Horário de início |
| `end_time` | TIMESTAMPTZ | NOT NULL | Horário de término |
| `capacity` | INTEGER | NOT NULL, DEFAULT 10 | Capacidade máxima |
| `lanes` | INTEGER | NOT NULL, DEFAULT 4 | Número de vagas |
| `type` | TEXT | NOT NULL, DEFAULT 'class' | Tipo da aula |
| `business_id` | UUID | FK → businesses | ID da empresa |
| `created_at` | TIMESTAMPTZ | DEFAULT now() | Data de criação |

#### `bookings`
Reservas de usuários para aulas

| Coluna | Tipo | Constraints | Descrição |
|--------|------|-------------|-----------|
| `id` | UUID | PK, DEFAULT uuid_generate_v4() | ID da reserva |
| `user_id` | UUID | FK → auth.users | ID do usuário |
| `class_id` | UUID | FK → classes | ID da aula |
| `checked_in` | BOOLEAN | DEFAULT false | Se fez check-in |
| `created_at` | TIMESTAMPTZ | DEFAULT now() | Data de criação |

**Constraints:**
- `UNIQUE(user_id, class_id)` - Um usuário só pode reservar uma aula uma vez

#### `cancellations`
Registro de cancelamentos para controle de limite

| Coluna | Tipo | Constraints | Descrição |
|--------|------|-------------|-----------|
| `id` | UUID | PK, DEFAULT uuid_generate_v4() | ID do cancelamento |
| `user_id` | UUID | FK → auth.users | ID do usuário |
| `booking_id` | UUID | | ID da reserva cancelada |
| `cancelled_at` | TIMESTAMPTZ | DEFAULT now() | Data do cancelamento |

#### `admins`
Relação de administradores (legacy, migrar para role em profiles)

| Coluna | Tipo | Constraints | Descrição |
|--------|------|-------------|-----------|
| `id` | UUID | PK, DEFAULT uuid_generate_v4() | ID do registro |
| `user_id` | UUID | UNIQUE, FK → auth.users | ID do usuário |
| `created_at` | TIMESTAMPTZ | DEFAULT now() | Data de criação |

#### `business_settings`
Configurações dinâmicas de regras de negócio

| Coluna | Tipo | Constraints | Descrição |
|--------|------|-------------|-----------|
| `id` | TEXT | PK, DEFAULT 'default' | ID das configurações |
| `business_id` | UUID | FK → businesses | ID da empresa (null = global) |
| `cancellation_deadline_hours` | INTEGER | DEFAULT 0 | Horas para deadline |
| `max_cancellations_per_month` | INTEGER | DEFAULT 0 | Limite de cancelamentos |
| `cancellation_limit_enabled` | BOOLEAN | DEFAULT false | Se limite está ativo |
| `max_bookings_per_week` | INTEGER | DEFAULT 0 | Limite de reservas |
| `booking_limit_enabled` | BOOLEAN | DEFAULT false | Se limite está ativo |
| `min_booking_advance_hours` | INTEGER | DEFAULT 0 | Antecedência mínima |
| `default_class_capacity` | INTEGER | DEFAULT 10 | Capacidade padrão |
| `default_lanes` | INTEGER | DEFAULT 4 | Vagas padrão |
| `class_types` | JSONB | | Tipos de aula personalizáveis |
| `updated_at` | TIMESTAMPTZ | | Data de atualização |
| `updated_by` | UUID | FK → auth.users | Quem atualizou |

### Scripts SQL

Execute os scripts na ordem para criar o banco de dados:

#### 1. Funções de RLS (`policies.sql`)

```sql
-- Função para verificar se usuário é admin
CREATE OR REPLACE FUNCTION is_admin()
RETURNS BOOLEAN AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM profiles 
    WHERE id = auth.uid() AND role = 'admin'
  ) OR EXISTS (
    SELECT 1 FROM admins 
    WHERE user_id = auth.uid()
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Função para verificar membership aprovado
CREATE OR REPLACE FUNCTION has_approved_membership(p_business_id UUID)
RETURNS BOOLEAN AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM business_members 
    WHERE user_id = auth.uid() 
    AND business_id = p_business_id 
    AND status = 'approved'
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
```

#### 2. Tabela de Perfis (`profiles.sql`)

```sql
-- Tabela de perfis
CREATE TABLE profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  email TEXT NOT NULL,
  name TEXT,
  phone TEXT,
  avatar_url TEXT,
  role TEXT DEFAULT 'student' CHECK (role IN ('student', 'admin')),
  business_id UUID REFERENCES businesses(id),
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ
);

-- Trigger para criar perfil automaticamente
CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO profiles (id, email)
  VALUES (NEW.id, NEW.email);
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION handle_new_user();

-- RLS
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own profile"
  ON profiles FOR SELECT
  USING (auth.uid() = id);

CREATE POLICY "Users can update own profile"
  ON profiles FOR UPDATE
  USING (auth.uid() = id);

CREATE POLICY "Admins can view all profiles"
  ON profiles FOR SELECT
  USING (is_admin());
```

#### 3. Tabela de Empresas (`businesses.sql`)

```sql
CREATE TABLE businesses (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name TEXT NOT NULL,
  slug TEXT UNIQUE NOT NULL,
  description TEXT,
  logo_url TEXT,
  address TEXT,
  phone TEXT,
  email TEXT,
  owner_id UUID NOT NULL REFERENCES auth.users(id),
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ
);

-- RLS
ALTER TABLE businesses ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Anyone can view active businesses"
  ON businesses FOR SELECT
  USING (is_active = true);

CREATE POLICY "Owners can manage their business"
  ON businesses FOR ALL
  USING (owner_id = auth.uid());
```

#### 4. Tabela de Membros (`business_members.sql`)

```sql
CREATE TABLE business_members (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  business_id UUID NOT NULL REFERENCES businesses(id) ON DELETE CASCADE,
  status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'rejected', 'suspended')),
  rejection_reason TEXT,
  requested_at TIMESTAMPTZ DEFAULT now(),
  approved_at TIMESTAMPTZ,
  rejected_at TIMESTAMPTZ,
  approved_by UUID REFERENCES auth.users(id),
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ,
  UNIQUE(user_id, business_id)
);

-- RLS
ALTER TABLE business_members ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own memberships"
  ON business_members FOR SELECT
  USING (user_id = auth.uid());

CREATE POLICY "Users can request membership"
  ON business_members FOR INSERT
  WITH CHECK (user_id = auth.uid() AND status = 'pending');

CREATE POLICY "Admins can manage members of their business"
  ON business_members FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM profiles 
      WHERE id = auth.uid() 
      AND role = 'admin' 
      AND business_id = business_members.business_id
    )
  );
```

#### 5. Tabela de Aulas (`classes.sql`)

```sql
CREATE TABLE classes (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  title TEXT NOT NULL,
  description TEXT,
  start_time TIMESTAMPTZ NOT NULL,
  end_time TIMESTAMPTZ NOT NULL,
  capacity INTEGER NOT NULL DEFAULT 10,
  lanes INTEGER NOT NULL DEFAULT 4,
  type TEXT NOT NULL DEFAULT 'class',
  business_id UUID REFERENCES businesses(id),
  created_at TIMESTAMPTZ DEFAULT now()
);

-- RLS
ALTER TABLE classes ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Members can view classes of their business"
  ON classes FOR SELECT
  USING (
    has_approved_membership(business_id) OR is_admin()
  );

CREATE POLICY "Admins can manage classes"
  ON classes FOR ALL
  USING (is_admin());
```

#### 6. Tabela de Reservas (`bookings.sql`)

```sql
CREATE TABLE bookings (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  class_id UUID NOT NULL REFERENCES classes(id) ON DELETE CASCADE,
  checked_in BOOLEAN DEFAULT false,
  created_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE(user_id, class_id)
);

-- RLS
ALTER TABLE bookings ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own bookings"
  ON bookings FOR SELECT
  USING (user_id = auth.uid());

CREATE POLICY "Users can create own bookings"
  ON bookings FOR INSERT
  WITH CHECK (user_id = auth.uid());

CREATE POLICY "Users can delete own bookings"
  ON bookings FOR DELETE
  USING (user_id = auth.uid());

CREATE POLICY "Admins can view all bookings"
  ON bookings FOR SELECT
  USING (is_admin());

CREATE POLICY "Admins can manage bookings"
  ON bookings FOR ALL
  USING (is_admin());
```

#### 7. Tabela de Cancelamentos (`cancellations.sql`)

```sql
CREATE TABLE cancellations (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  booking_id UUID,
  cancelled_at TIMESTAMPTZ DEFAULT now()
);

-- RLS
ALTER TABLE cancellations ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own cancellations"
  ON cancellations FOR SELECT
  USING (user_id = auth.uid());

CREATE POLICY "Users can create cancellations"
  ON cancellations FOR INSERT
  WITH CHECK (user_id = auth.uid());
```

#### 8. Tabela de Configurações (`business_settings.sql`)

```sql
CREATE TABLE business_settings (
  id TEXT PRIMARY KEY DEFAULT 'default',
  business_id UUID REFERENCES businesses(id),
  cancellation_deadline_hours INTEGER DEFAULT 0,
  max_cancellations_per_month INTEGER DEFAULT 0,
  cancellation_limit_enabled BOOLEAN DEFAULT false,
  max_bookings_per_week INTEGER DEFAULT 0,
  booking_limit_enabled BOOLEAN DEFAULT false,
  min_booking_advance_hours INTEGER DEFAULT 0,
  default_class_capacity INTEGER DEFAULT 10,
  default_lanes INTEGER DEFAULT 4,
  class_types JSONB DEFAULT '[{"id":"class","name":"Aula","icon":"school"},{"id":"free","name":"Treino Livre","icon":"fitness_center"}]',
  updated_at TIMESTAMPTZ,
  updated_by UUID REFERENCES auth.users(id)
);

-- RLS
ALTER TABLE business_settings ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Anyone can view settings"
  ON business_settings FOR SELECT
  USING (true);

CREATE POLICY "Admins can update settings"
  ON business_settings FOR UPDATE
  USING (is_admin());

CREATE POLICY "Admins can insert settings"
  ON business_settings FOR INSERT
  WITH CHECK (is_admin());
```

#### 9. Storage para Avatars

No Supabase Dashboard → Storage:

1. Criar bucket `avatars` com política pública
2. Configurar políticas:

```sql
-- Política para upload
CREATE POLICY "Users can upload own avatar"
  ON storage.objects FOR INSERT
  WITH CHECK (
    bucket_id = 'avatars' AND
    auth.uid()::text = (storage.foldername(name))[1]
  );

-- Política para leitura pública
CREATE POLICY "Avatars are publicly accessible"
  ON storage.objects FOR SELECT
  USING (bucket_id = 'avatars');

-- Política para delete
CREATE POLICY "Users can delete own avatar"
  ON storage.objects FOR DELETE
  USING (
    bucket_id = 'avatars' AND
    auth.uid()::text = (storage.foldername(name))[1]
  );
```

---

## Variáveis de Ambiente

### Desenvolvimento (arquivo `.env`)

Crie um arquivo `.env` na raiz do projeto:

```bash
# .env (NÃO COMMITAR!)
SUPABASE_URL=https://seu-projeto.supabase.co
SUPABASE_ANON_KEY=sua-anon-key-aqui
```

> ⚠️ **IMPORTANTE**: O arquivo `.env` já está no `.gitignore`. Nunca commit credenciais!

### Produção (via `--dart-define`)

Em produção, as credenciais são passadas via argumentos de build:

```bash
flutter build apk --release \
  --dart-define=SUPABASE_URL=$SUPABASE_URL \
  --dart-define=SUPABASE_ANON_KEY=$SUPABASE_ANON_KEY
```

### CI/CD (GitHub Actions)

Configure secrets no repositório:

| Secret | Descrição |
|--------|-----------|
| `SUPABASE_URL` | URL do projeto Supabase |
| `SUPABASE_ANON_KEY` | Anon Key do Supabase |
| `KEYSTORE_BASE64` | Keystore Android em Base64 |
| `KEYSTORE_PASSWORD` | Senha do keystore |
| `KEY_ALIAS` | Alias da chave |
| `KEY_PASSWORD` | Senha da chave |

---

## Configuração

### Pré-requisitos

- Flutter SDK 3.10+
- Conta no [Supabase](https://supabase.com)
- Android Studio ou Xcode (para builds nativos)

### 1. Clone o repositório

```bash
git clone https://github.com/seu-usuario/trainly.git
cd trainly
```

### 2. Instale as dependências

```bash
flutter pub get
```

### 3. Configure as variáveis de ambiente

```bash
cp .env.example .env
# Edite o arquivo .env com suas credenciais
```

### 4. Configure o Supabase

1. Crie um projeto no [Supabase Dashboard](https://app.supabase.com)
2. Copie a URL e Anon Key (Settings → API)
3. Execute os scripts SQL na ordem (SQL Editor)
4. Configure o Storage para avatars

### 5. Execute o projeto

```bash
# Modo debug
flutter run

# Especificar dispositivo
flutter run -d chrome  # Web
flutter run -d android # Android
flutter run -d ios     # iOS
```

---

## Build e Deploy

### Android (APK/AAB)

```bash
# APK para testes
flutter build apk --release \
  --dart-define=SUPABASE_URL=$SUPABASE_URL \
  --dart-define=SUPABASE_ANON_KEY=$SUPABASE_ANON_KEY

# App Bundle para Play Store
flutter build appbundle --release \
  --dart-define=SUPABASE_URL=$SUPABASE_URL \
  --dart-define=SUPABASE_ANON_KEY=$SUPABASE_ANON_KEY
```

### iOS

```bash
flutter build ios --release \
  --dart-define=SUPABASE_URL=$SUPABASE_URL \
  --dart-define=SUPABASE_ANON_KEY=$SUPABASE_ANON_KEY
```

### Web

```bash
flutter build web --release \
  --dart-define=SUPABASE_URL=$SUPABASE_URL \
  --dart-define=SUPABASE_ANON_KEY=$SUPABASE_ANON_KEY
```

### Checklist para Play Store

- [ ] Arquivo `.env` não está nos assets do build
- [ ] Credenciais passadas via `--dart-define`
- [ ] Keystore segura (não commitada)
- [ ] ProGuard/R8 configurado
- [ ] Versão atualizada no `pubspec.yaml`
- [ ] Ícones e splash screen configurados
- [ ] Política de privacidade disponível

---

## Testes

### Estrutura de Testes

```
test/
├── core/
│   ├── booking_rules_test.dart    # Regras de negócio
│   ├── input_validator_test.dart  # Validação de inputs
│   ├── security_helpers_test.dart # Helpers de segurança
│   └── theme_provider_test.dart   # Temas
├── models/
│   ├── booking_test.dart          # Model de reserva
│   ├── business_settings_test.dart# Model de configurações
│   ├── class_item_test.dart       # Model de item de aula
│   ├── class_type_test.dart       # Model de tipo de aula
│   ├── swim_class_test.dart       # Model de aula
│   ├── time_slot_test.dart        # Model de horário
│   ├── training_type_test.dart    # Model de tipo
│   └── user_profile_test.dart     # Model de perfil
├── services/
│   ├── admin_service_test.dart    # Serviço admin
│   ├── booking_service_test.dart  # Serviço de reservas
│   ├── classes_service_test.dart  # Serviço de aulas
│   ├── profile_service_test.dart  # Serviço de perfil
│   └── settings_service_test.dart # Serviço de configurações
├── widgets/
│   └── skeleton_loading_test.dart # Widgets de loading
└── helpers/
    └── test_helpers.dart          # Helpers para testes
```

### Executar Testes

```bash
# Todos os testes
flutter test

# Com verbose
flutter test --verbose

# Teste específico
flutter test test/core/booking_rules_test.dart

# Com cobertura
flutter test --coverage
genhtml coverage/lcov.info -o coverage/html
open coverage/html/index.html
```

### Cobertura Esperada

| Componente | Cobertura |
|------------|-----------|
| Models | 90%+ |
| Core/Rules | 100% |
| Services | 80%+ |
| Widgets | 70%+ |

---

## Segurança

### Camadas de Proteção

| Camada | Implementação |
|--------|---------------|
| **Variáveis de Ambiente** | Credenciais em `.env` (não commitado) ou `--dart-define` |
| **Row Level Security (RLS)** | Políticas no Supabase para cada tabela |
| **Validação de Input** | `InputValidator` centralizado |
| **Verificação de Ownership** | `SecurityHelpers.isResourceOwner()` |
| **Sanitização de Erros** | `SecurityHelpers.sanitizeErrorMessage()` |
| **Upload Seguro** | Validação de extensão, tamanho e path traversal |

### Validações de Input

```dart
// Validação de UUID
InputValidator.validateId(id, 'ID da aula');

// Validação de email
InputValidator.validateEmail(email);

// Validação de arquivo
InputValidator.validateAvatarExtension(filePath);
InputValidator.validateFileSize(sizeBytes, maxBytes);

// Sanitização de nome de arquivo
InputValidator.sanitizeFileName(fileName);
```

### Verificações de Segurança

```dart
// Verifica se é admin
final isAdmin = await SecurityHelpers.isCurrentUserAdmin();

// Verifica ownership
final isOwner = await SecurityHelpers.isResourceOwner(
  'bookings', bookingId, 'user_id'
);

// Sanitiza erro antes de mostrar
final safeMessage = SecurityHelpers.sanitizeErrorMessage(error);
```

### Boas Práticas Implementadas

- [x] Credenciais nunca hardcoded
- [x] `.env` no `.gitignore`
- [x] Keystore e `key.properties` no `.gitignore`
- [x] RLS em todas as tabelas
- [x] Validação de inputs no frontend e backend
- [x] Mensagens de erro genéricas (não expõem detalhes técnicos)
- [x] Verificação de permissões antes de operações sensíveis
- [x] Proteção contra SQL injection e XSS
- [x] Limite de tamanho e tipo de upload

---

## Estrutura do Projeto

```
lib/
├── admin/                    # Páginas administrativas
│   ├── admin_panel_page.dart    # Menu principal do admin
│   ├── check_in_page.dart       # Check-in de alunos
│   ├── class_detail_page.dart   # Detalhes de uma aula
│   ├── dashboard_page.dart      # Dashboard com estatísticas
│   ├── manage_admins_page.dart  # Gerenciar administradores
│   └── manage_members_page.dart # Gerenciar membros
├── attendance/               # Histórico de frequência
│   └── attendance_history_page.dart
├── auth/                     # Autenticação
│   ├── auth_gate.dart           # Roteamento baseado em auth
│   ├── login_page.dart          # Login
│   ├── register_admin_page.dart # Registro de admin
│   ├── register_student_page.dart # Registro de aluno
│   ├── select_business_page.dart  # Seleção de academia
│   ├── setup_business_page.dart   # Criar academia
│   └── welcome_page.dart        # Tela inicial
├── bookings/                 # Minhas reservas
│   └── my_bookings_page.dart
├── calendar/                 # Visualização calendário
│   └── calendar_page.dart
├── classes/                  # Gerenciamento de aulas
│   ├── class_form_page.dart     # Formulário de aula
│   └── classes_list_page.dart   # Lista de aulas
├── core/                     # Core do app
│   ├── booking_rules.dart       # Regras de negócio (singleton)
│   ├── input_validator.dart     # Validação de inputs
│   ├── security_helpers.dart    # Helpers de segurança
│   ├── supabase_client.dart     # Cliente Supabase
│   └── theme_provider.dart      # Gerenciador de tema
├── home/                     # Página inicial
│   └── home_page.dart
├── models/                   # Models/DTOs
│   ├── booking.dart             # Reserva
│   ├── business.dart            # Empresa
│   ├── business_membership.dart # Associação usuário-empresa
│   ├── business_settings.dart   # Configurações
│   ├── class_item.dart          # Item de aula (legacy)
│   ├── class_type.dart          # Tipo de aula
│   ├── swim_class.dart          # Aula/Sessão
│   ├── time_slot.dart           # Horário
│   ├── training_type.dart       # Tipo de treino (legacy)
│   └── user_profile.dart        # Perfil de usuário
├── profile/                  # Perfil do usuário
│   ├── my_memberships_page.dart # Minhas academias
│   └── profile_page.dart        # Edição de perfil
├── services/                 # Camada de serviços
│   ├── admin_service.dart       # Operações admin
│   ├── booking_service.dart     # Reservas
│   ├── business_service.dart    # Empresas
│   ├── classes_service.dart     # Aulas
│   ├── membership_service.dart  # Memberships
│   ├── profile_service.dart     # Perfil
│   ├── settings_service.dart    # Configurações
│   └── supabase_service.dart    # Base Supabase
├── widgets/                  # Widgets reutilizáveis
│   └── skeleton_loading.dart    # Loading skeleton
└── main.dart                 # Entry point
```

---

## Contribuição

1. Fork o projeto
2. Crie uma branch (`git checkout -b feature/nova-feature`)
3. Commit suas mudanças (`git commit -m 'Adiciona nova feature'`)
4. Push para a branch (`git push origin feature/nova-feature`)
5. Abra um Pull Request

### Convenções

- Commits em português ou inglês
- Código em inglês (variáveis, funções, classes)
- UI em português (strings de exibição)
- Testes para toda nova funcionalidade

---

## Licença

Este projeto é privado e de uso educacional.

---

## Contato

Para dúvidas ou sugestões, abra uma issue no repositório.
