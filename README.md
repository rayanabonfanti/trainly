# Trainly - Sistema de Agendamento de Aulas de Natação

Sistema completo para gerenciamento de aulas de natação com suporte a reservas, check-in, e controle de frequência.

## Índice

- [Funcionalidades](#funcionalidades)
- [Regras de Negócio](#regras-de-negócio)
- [Segurança](#segurança)
- [Arquitetura](#arquitetura)
- [Configuração](#configuração)
- [Executando o Projeto](#executando-o-projeto)
- [Testes](#testes)
- [Estrutura do Projeto](#estrutura-do-projeto)
- [Scripts SQL](#scripts-sql)

---

## Funcionalidades

### Para Alunos
- **Visualização de Aulas**: Lista e calendário com aulas disponíveis
- **Reservas**: Reservar aulas futuras com controle de vagas
- **Cancelamentos**: Cancelar reservas respeitando prazos
- **Histórico**: Ver frequência e aulas já realizadas
- **Perfil**: Editar nome, telefone e foto de perfil
- **Tema Escuro**: Suporte a light/dark mode

### Para Administradores
- **Gerenciamento de Aulas**: CRUD completo de aulas
- **Tipos de Aula Configuráveis**: Adicionar/remover tipos de aula dinamicamente
- **Check-in**: Marcar presença dos alunos
- **Dashboard**: Estatísticas de ocupação e frequência
- **Gestão de Admins**: Promover usuários para administradores
- **Configurações**: Regras de negócio dinâmicas (limites, deadlines, capacidades)

---

## Regras de Negócio

### Configurações Dinâmicas (Admin)

O sistema possui regras de negócio **configuráveis dinamicamente** pelo administrador através do painel de configurações. Isso permite que cada academia/escola personalize as regras conforme suas políticas.

#### Regras Configuráveis

| Regra | Padrão | Descrição |
|-------|--------|-----------|
| **Deadline de cancelamento** | 2 horas | Horas antes da aula que ainda é permitido cancelar (0 = sem restrição) |
| **Limite de cancelamentos/mês** | 2 | Máximo de cancelamentos por usuário por mês |
| **Habilitar limite de cancelamentos** | Sim | Se o limite de cancelamentos está ativo |
| **Limite de reservas/semana** | 3 | Máximo de reservas ativas por semana |
| **Habilitar limite de reservas** | Sim | Se o limite de reservas está ativo |
| **Antecedência mínima** | 24 horas | Antecedência mínima para fazer uma reserva (0 = pode reservar até o momento) |
| **Capacidade padrão** | 10 alunos | Valor padrão de capacidade ao criar novas aulas |
| **Raias padrão** | 4 | Número de raias padrão ao criar novas aulas |

#### Como Acessar as Configurações

1. Faça login como administrador
2. Acesse o **Painel Admin**
3. Clique em **Configurações**
4. Ajuste os valores conforme necessário
5. Clique em **Salvar Configurações**

### Tipos de Aula

Os tipos de aula são **configuráveis pelo administrador** na página de configurações:

| Tipo Padrão | Descrição |
|-------------|-----------|
| **Aula de Natação** | Aula com instrutor, turmas organizadas |
| **Nado Livre** | Horário para prática livre na piscina |

**O admin pode:**
- Adicionar novos tipos (ex: Hidroginástica, Natação Infantil, etc.)
- Editar nome e ícone de tipos existentes
- Remover tipos (mínimo 1 obrigatório)

### Reservas

| Regra | Descrição |
|-------|-----------|
| **Antecedência mínima** | Configurável (padrão: reservas só a partir do dia seguinte) |
| **Limite semanal** | Configurável (padrão: 3 reservas ativas por semana) |
| **Vagas limitadas** | Cada aula tem capacidade máxima de alunos |
| **Sem duplicatas** | Um usuário não pode reservar a mesma aula duas vezes |
| **Conflito de horário** | Não é permitido reservar aulas com horários sobrepostos |

### Cancelamentos

| Regra | Descrição |
|-------|-----------|
| **Deadline** | Configurável (padrão: 2 horas antes da aula) |
| **Limite mensal** | Configurável (padrão: 2 cancelamentos por mês) |
| **Registro** | Cancelamentos são registrados para controle de limite |
| **Ownership** | Apenas o dono da reserva pode cancelá-la (admins podem cancelar qualquer uma) |

### Permissões

| Ação | Aluno | Admin |
|------|-------|-------|
| Ver aulas | ✅ | ✅ |
| Reservar aulas | ✅ | ❌ |
| Cancelar reserva | ✅ (própria) | ✅ (todas) |
| Criar/editar aulas | ❌ | ✅ |
| Fazer check-in | ❌ | ✅ |
| Ver dashboard | ❌ | ✅ |
| Promover admins | ❌ | ✅ |
| Configurar regras | ❌ | ✅ |
| Gerenciar tipos de aula | ❌ | ✅ |

---

## Segurança

O sistema implementa múltiplas camadas de segurança:

### Variáveis de Ambiente

As credenciais do Supabase são armazenadas em variáveis de ambiente (`.env`), nunca hardcoded no código:

```bash
# .env (não commitar!)
SUPABASE_URL=https://seu-projeto.supabase.co
SUPABASE_ANON_KEY=sua-anon-key
```

### Validação de Input

Todas as entradas do usuário são validadas:
- IDs (formato UUID)
- Emails, nomes, telefones
- Tamanho e tipo de arquivos de upload
- Proteção contra SQL injection e XSS

### Verificação de Ownership

Operações sensíveis verificam se o usuário é dono do recurso:
- Cancelamento de reservas
- Atualização de perfil

### Proteção de Endpoints Admin

Endpoints que expõem dados sensíveis verificam se o usuário é admin:
- Lista de reservas com dados de alunos
- Configurações do sistema
- CRUD de aulas

### Sanitização de Erros

Mensagens de erro são sanitizadas para não expor detalhes internos do sistema.

### Upload Seguro

Uploads de avatar incluem:
- Validação de extensão (jpg, png, gif, webp)
- Limite de tamanho (5MB)
- Sanitização de nome de arquivo
- Proteção contra path traversal

---

## Arquitetura

### Stack Tecnológico

- **Frontend**: Flutter 3.10+ com Material Design 3
- **Backend**: Supabase (PostgreSQL + Auth + Storage)
- **State Management**: setState (stateful widgets)
- **Tema**: Light/Dark mode com ThemeProvider
- **Configuração**: flutter_dotenv para variáveis de ambiente

### Padrões

- **Clean Architecture**: Separação em camadas (models, services, pages)
- **Repository Pattern**: Services encapsulam acesso a dados
- **Factory Pattern**: Constructors para criação de objetos
- **Security Helpers**: Validação centralizada de inputs e permissões

---

## Configuração

### Pré-requisitos

- Flutter SDK 3.10+
- Conta no Supabase

### 1. Clone o repositório

```bash
git clone <repository-url>
cd trainly
```

### 2. Configure as variáveis de ambiente

```bash
# Copie o arquivo de exemplo
cp .env.example .env

# Edite com suas credenciais
nano .env
```

Conteúdo do `.env`:
```bash
SUPABASE_URL=https://seu-projeto.supabase.co
SUPABASE_ANON_KEY=sua-anon-key
```

> ⚠️ **IMPORTANTE**: Nunca commite o arquivo `.env` no Git!

### 3. Configure o Supabase

1. Crie um projeto no [Supabase](https://supabase.com)
2. Copie a URL e Anon Key para o arquivo `.env`

### 4. Execute os scripts SQL

Execute na ordem no SQL Editor do Supabase:

1. `supabase/policies.sql` - Funções de RLS
2. `supabase/profiles.sql` - Tabela de perfis
3. `supabase/classes.sql` - Tabela de aulas
4. `supabase/bookings.sql` - Tabela de reservas
5. `supabase/bookings_update.sql` - Campo de check-in
6. `supabase/cancellations.sql` - Tabela de cancelamentos
7. `supabase/business_settings.sql` - Configurações dinâmicas de negócio

**Adicione também o suporte a tipos de aula dinâmicos:**

```sql
ALTER TABLE business_settings 
ADD COLUMN IF NOT EXISTS class_types JSONB DEFAULT '[{"id":"class","name":"Aula de Natação","icon":"school"},{"id":"free","name":"Nado Livre","icon":"pool"}]';
```

### 5. Configure o Storage (opcional)

Para upload de avatar, crie um bucket chamado `avatars` no Storage do Supabase com política pública.

---

## Executando o Projeto

### Instalar dependências

```bash
flutter pub get
```

### Executar em modo debug

```bash
flutter run
```

### Executar em dispositivo específico

```bash
# Listar dispositivos
flutter devices

# Executar em dispositivo específico
flutter run -d <device_id>

# Executar no Chrome (web)
flutter run -d chrome

# Executar no iOS Simulator
flutter run -d iPhone
```

### Build de produção

```bash
# Android APK
flutter build apk --release

# Android App Bundle (Play Store)
flutter build appbundle --release

# iOS
flutter build ios --release

# Web
flutter build web --release
```

---

## Testes

### Estrutura de Testes

```
test/
├── core/
│   ├── booking_rules_test.dart    # Regras de negócio
│   └── theme_provider_test.dart   # Temas
├── models/
│   ├── booking_test.dart          # Model de reserva
│   ├── business_settings_test.dart# Model de configurações
│   ├── class_item_test.dart       # Model de item de aula
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

### Executar Testes Unitários

```bash
# Executar todos os testes
flutter test

# Executar com verbose
flutter test --verbose

# Executar teste específico
flutter test test/core/booking_rules_test.dart

# Executar testes de um diretório
flutter test test/models/

# Executar com cobertura
flutter test --coverage

# Gerar relatório HTML de cobertura
genhtml coverage/lcov.info -o coverage/html
open coverage/html/index.html
```

### Executar Testes com Watch Mode

```bash
# Instalar ferramenta de watch (opcional)
dart pub global activate test_cov

# Executar testes em modo watch
flutter test --watch
```

### Testes de Integração

```bash
# Executar testes de integração
flutter test integration_test/

# Executar em dispositivo real
flutter drive --target=test_driver/app.dart
```

### Coverage Mínimo Esperado

| Componente | Cobertura |
|------------|-----------|
| Models | 90%+ |
| Core/Rules | 100% |
| Services (Results) | 80%+ |
| Widgets | 70%+ |

---

## Estrutura do Projeto

```
lib/
├── admin/                    # Páginas administrativas
│   ├── admin_panel_page.dart
│   ├── check_in_page.dart
│   ├── dashboard_page.dart
│   ├── manage_admins_page.dart
│   └── settings_page.dart    # Configurações + tipos de aula
├── attendance/               # Histórico de frequência
│   └── attendance_history_page.dart
├── auth/                     # Autenticação
│   ├── auth_gate.dart
│   └── login_page.dart
├── bookings/                 # Minhas reservas
│   └── my_bookings_page.dart
├── calendar/                 # Visualização calendário
│   └── calendar_page.dart
├── classes/                  # Gerenciamento de aulas
│   ├── class_form_page.dart  # Formulário com tipos dinâmicos
│   └── classes_list_page.dart
├── core/                     # Core do app
│   ├── booking_rules.dart    # Regras de negócio
│   ├── input_validator.dart  # Validação de inputs
│   ├── security_helpers.dart # Helpers de segurança
│   ├── supabase_client.dart  # Cliente Supabase (usa .env)
│   └── theme_provider.dart   # Gerenciador de tema
├── home/                     # Página inicial
│   └── home_page.dart
├── models/                   # Models/DTOs
│   ├── booking.dart
│   ├── business_settings.dart # Configurações + tipos de aula
│   ├── class_item.dart
│   ├── class_type.dart       # Tipos de aula configuráveis
│   ├── swim_class.dart
│   ├── time_slot.dart
│   ├── training_type.dart
│   └── user_profile.dart
├── profile/                  # Perfil do usuário
│   └── profile_page.dart
├── services/                 # Camada de serviços
│   ├── admin_service.dart
│   ├── booking_service.dart  # Com verificação de ownership
│   ├── classes_service.dart  # Com verificação de admin
│   ├── profile_service.dart  # Com validação de upload
│   ├── settings_service.dart # Com tipos de aula
│   └── supabase_service.dart
├── widgets/                  # Widgets reutilizáveis
│   └── skeleton_loading.dart
└── main.dart                 # Entry point (carrega .env)
```

---

## Scripts SQL

### Ordem de Execução

1. **policies.sql** - Função `is_admin()` para RLS
2. **profiles.sql** - Tabela de perfis com trigger automático
3. **classes.sql** - Tabela de aulas com tipos
4. **bookings.sql** - Tabela de reservas com validações
5. **bookings_update.sql** - Adiciona campo `checked_in`
6. **cancellations.sql** - Controle de limite de cancelamentos
7. **business_settings.sql** - Configurações dinâmicas de regras de negócio

### Tabelas Principais

| Tabela | Descrição |
|--------|-----------|
| `profiles` | Perfis de usuários (nome, telefone, avatar, role) |
| `classes` | Aulas agendadas |
| `bookings` | Reservas dos usuários |
| `cancellations` | Registro de cancelamentos |
| `admins` | Relação de administradores |
| `business_settings` | Configurações dinâmicas + tipos de aula |

---

## Dependências Principais

```yaml
dependencies:
  flutter:
    sdk: flutter
  supabase_flutter: ^2.8.0      # Backend
  flutter_dotenv: ^5.1.0        # Variáveis de ambiente
  table_calendar: ^3.1.2        # Calendário
  shimmer: ^3.0.0               # Loading skeleton
  fl_chart: ^0.69.2             # Gráficos
  image_picker: ^1.1.2          # Seletor de imagem
  shared_preferences: ^2.3.3    # Armazenamento local
  mask_text_input_formatter: ^2.9.0 # Máscaras de input
```

---

## Deploy para Play Store

### Checklist de Segurança

Antes de publicar na Play Store, verifique:

- [ ] Arquivo `.env` está no `.gitignore`
- [ ] Credenciais do Supabase não estão hardcoded
- [ ] Anon Key foi rotacionada (se exposta anteriormente)
- [ ] RLS policies estão configuradas no Supabase
- [ ] Upload de arquivos tem validação de tipo e tamanho
- [ ] Mensagens de erro não expõem detalhes técnicos

### Build para Play Store

```bash
# Gerar App Bundle
flutter build appbundle --release

# O arquivo estará em:
# build/app/outputs/bundle/release/app-release.aab
```

---

## Contribuição

1. Fork o projeto
2. Crie uma branch (`git checkout -b feature/nova-feature`)
3. Commit suas mudanças (`git commit -m 'Adiciona nova feature'`)
4. Push para a branch (`git push origin feature/nova-feature`)
5. Abra um Pull Request

---

## Licença

Este projeto é privado e de uso educacional.

---

## Contato

Para dúvidas ou sugestões, abra uma issue no repositório.
