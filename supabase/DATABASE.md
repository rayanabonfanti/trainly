# Trainly - Documentação do Banco de Dados

Este documento descreve a estrutura completa do banco de dados do Trainly, incluindo tabelas, funções, políticas de segurança (RLS) e índices.

**Execute estes scripts no Supabase Dashboard > SQL Editor**

---

## Índice

1. [Tabela: profiles](#1-tabela-profiles)
2. [Tabela: classes](#2-tabela-classes)
3. [Tabela: bookings](#3-tabela-bookings)
4. [Tabela: cancellations](#4-tabela-cancellations)
5. [Tabela: business_settings](#5-tabela-business_settings)
6. [Funções Auxiliares](#6-funções-auxiliares)
7. [Ordem de Execução](#7-ordem-de-execução)

---

## 1. Tabela: profiles

### Descrição
Armazena informações dos usuários do sistema.

### Estrutura

| Campo | Tipo | Descrição |
|-------|------|-----------|
| `id` | UUID | Chave primária (referência auth.users) |
| `email` | TEXT | Email do usuário |
| `name` | TEXT | Nome do usuário |
| `phone` | TEXT | Telefone |
| `avatar_url` | TEXT | URL do avatar |
| `created_at` | TIMESTAMP WITH TIME ZONE | Data de criação |
| `updated_at` | TIMESTAMP WITH TIME ZONE | Data de atualização |

### Criar Tabela

```sql
CREATE TABLE IF NOT EXISTS public.profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  email TEXT,
  name TEXT,
  phone TEXT,
  avatar_url TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);
```

### Habilitar RLS

```sql
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
```

### Políticas de Segurança (RLS)

#### Remover políticas antigas

```sql
DROP POLICY IF EXISTS "profiles_select_policy" ON public.profiles;
DROP POLICY IF EXISTS "profiles_insert_policy" ON public.profiles;
DROP POLICY IF EXISTS "profiles_update_policy" ON public.profiles;
```

#### SELECT: Qualquer usuário autenticado pode ver perfis

```sql
CREATE POLICY "profiles_select_policy"
ON public.profiles
FOR SELECT
TO authenticated
USING (true);
```

#### INSERT: Usuário pode criar seu próprio perfil

```sql
CREATE POLICY "profiles_insert_policy"
ON public.profiles
FOR INSERT
TO authenticated
WITH CHECK (auth.uid() = id);
```

#### UPDATE: Usuário pode atualizar seu próprio perfil

```sql
CREATE POLICY "profiles_update_policy"
ON public.profiles
FOR UPDATE
TO authenticated
USING (auth.uid() = id)
WITH CHECK (auth.uid() = id);
```

### Índices

```sql
CREATE INDEX IF NOT EXISTS idx_profiles_email ON public.profiles(email);
```

### Trigger: Criar perfil automaticamente

Cria um perfil automaticamente quando um novo usuário se registra.

```sql
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger AS $$
BEGIN
  INSERT INTO public.profiles (id, email)
  VALUES (NEW.id, NEW.email)
  ON CONFLICT (id) DO NOTHING;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();
```

### Função Auxiliar: is_admin()

Verifica se o usuário atual é administrador. Usa `SECURITY DEFINER` para evitar recursão infinita nas policies RLS.

```sql
CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS BOOLEAN AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.profiles
    WHERE id = auth.uid()
    AND role = 'admin'
  );
$$ LANGUAGE sql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION public.is_admin() TO authenticated;
```

### Notas Importantes

- Para criar o primeiro admin, execute manualmente:
  ```sql
  UPDATE profiles SET role = 'admin' WHERE email = 'seu-email@exemplo.com';
  ```
- Depois que o primeiro admin existir, ele pode promover outros via app

---

## 2. Tabela: classes

### Descrição
Armazena as aulas disponíveis para agendamento.

### Estrutura

| Campo | Tipo | Descrição |
|-------|------|-----------|
| `id` | UUID | Chave primária (auto-gerada) |
| `title` | TEXT | Nome da aula (obrigatório) |
| `description` | TEXT | Descrição da aula |
| `start_time` | TIMESTAMP WITH TIME ZONE | Horário de início (obrigatório) |
| `end_time` | TIMESTAMP WITH TIME ZONE | Horário de término (obrigatório) |
| `capacity` | INT | Número máximo de alunos (> 0) |
| `lanes` | INT | Número de raias disponíveis (> 0) |
| `type` | TEXT | Tipo: 'class' (aula com instrutor) ou 'free' (nado livre) |
| `created_at` | TIMESTAMP WITH TIME ZONE | Data de criação |

### Criar Tabela

```sql
DROP TABLE IF EXISTS public.classes CASCADE;

CREATE TABLE public.classes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  title TEXT NOT NULL,
  description TEXT,
  start_time TIMESTAMP WITH TIME ZONE NOT NULL,
  end_time TIMESTAMP WITH TIME ZONE NOT NULL,
  capacity INT NOT NULL CHECK (capacity > 0),
  lanes INT NOT NULL CHECK (lanes > 0),
  type TEXT NOT NULL CHECK (type IN ('class', 'free')),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  
  CONSTRAINT classes_time_check CHECK (end_time > start_time)
);
```

### Habilitar RLS

```sql
ALTER TABLE public.classes ENABLE ROW LEVEL SECURITY;
```

### Políticas de Segurança (RLS)

#### Remover políticas antigas

```sql
DROP POLICY IF EXISTS "classes_select_policy" ON public.classes;
DROP POLICY IF EXISTS "classes_insert_policy" ON public.classes;
DROP POLICY IF EXISTS "classes_update_policy" ON public.classes;
DROP POLICY IF EXISTS "classes_delete_policy" ON public.classes;
```

#### SELECT: Qualquer usuário autenticado pode visualizar aulas

```sql
CREATE POLICY "classes_select_policy"
ON public.classes
FOR SELECT
TO authenticated
USING (true);
```

#### INSERT: Apenas admins podem criar aulas

```sql
CREATE POLICY "classes_insert_policy"
ON public.classes
FOR INSERT
TO authenticated
WITH CHECK (public.is_admin());
```

#### UPDATE: Apenas admins podem atualizar aulas

```sql
CREATE POLICY "classes_update_policy"
ON public.classes
FOR UPDATE
TO authenticated
USING (public.is_admin())
WITH CHECK (public.is_admin());
```

#### DELETE: Apenas admins podem excluir aulas

```sql
CREATE POLICY "classes_delete_policy"
ON public.classes
FOR DELETE
TO authenticated
USING (public.is_admin());
```

### Índices

```sql
CREATE INDEX IF NOT EXISTS idx_classes_start_time ON public.classes(start_time);
CREATE INDEX IF NOT EXISTS idx_classes_type ON public.classes(type);
```

### Tipos de Aula

| Tipo | Descrição |
|------|-----------|
| `class` | Aula com instrutor |
| `free` | Nado livre |

---

## 3. Tabela: bookings

### Descrição
Armazena as reservas de aulas feitas pelos usuários.

### Estrutura

| Campo | Tipo | Descrição |
|-------|------|-----------|
| `id` | UUID | Chave primária (auto-gerada) |
| `user_id` | UUID | Referência ao usuário (auth.users) |
| `class_id` | UUID | Referência à aula (classes) |
| `checked_in` | BOOLEAN | Status de check-in (default: false) |
| `created_at` | TIMESTAMP WITH TIME ZONE | Data da reserva |

### Criar Tabela

```sql
DROP TABLE IF EXISTS public.bookings CASCADE;

CREATE TABLE public.bookings (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  class_id UUID NOT NULL REFERENCES public.classes(id) ON DELETE CASCADE,
  checked_in BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  
  CONSTRAINT unique_user_class UNIQUE (user_id, class_id)
);
```

### Adicionar campo checked_in (se tabela já existir)

```sql
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' 
    AND table_name = 'bookings' 
    AND column_name = 'checked_in'
  ) THEN
    ALTER TABLE public.bookings ADD COLUMN checked_in BOOLEAN DEFAULT FALSE;
  END IF;
END $$;
```

### Índices

```sql
CREATE INDEX idx_bookings_user_id ON public.bookings(user_id);
CREATE INDEX idx_bookings_class_id ON public.bookings(class_id);
CREATE INDEX IF NOT EXISTS idx_bookings_checked_in ON public.bookings(checked_in);
```

### Habilitar RLS

```sql
ALTER TABLE public.bookings ENABLE ROW LEVEL SECURITY;
```

### Políticas de Segurança (RLS)

#### Remover políticas antigas

```sql
DROP POLICY IF EXISTS "bookings_select_policy" ON public.bookings;
DROP POLICY IF EXISTS "bookings_insert_policy" ON public.bookings;
DROP POLICY IF EXISTS "bookings_update_policy" ON public.bookings;
DROP POLICY IF EXISTS "bookings_delete_policy" ON public.bookings;
```

#### SELECT: Usuário vê suas reservas OU admin vê todas

```sql
CREATE POLICY "bookings_select_policy"
ON public.bookings
FOR SELECT
TO authenticated
USING (
  auth.uid() = user_id
  OR public.is_admin()
);
```

#### INSERT: Usuário pode reservar com validações

Regras:
1. É para si mesmo
2. Aula é para amanhã ou depois
3. Há vagas disponíveis
4. Não há conflito de horário

```sql
CREATE POLICY "bookings_insert_policy"
ON public.bookings
FOR INSERT
TO authenticated
WITH CHECK (
  auth.uid() = user_id
  AND public.is_future_class(class_id)
  AND public.has_available_spots(class_id)
  AND NOT public.has_time_conflict(auth.uid(), class_id)
);
```

#### UPDATE: Apenas admins podem atualizar (para check-in)

```sql
CREATE POLICY "bookings_update_policy"
ON public.bookings
FOR UPDATE
TO authenticated
USING (public.is_admin())
WITH CHECK (public.is_admin());
```

#### DELETE: Usuário pode cancelar sua reserva OU admin cancela qualquer

```sql
CREATE POLICY "bookings_delete_policy"
ON public.bookings
FOR DELETE
TO authenticated
USING (
  auth.uid() = user_id
  OR public.is_admin()
);
```

---

## 4. Tabela: cancellations

### Descrição
Armazena o histórico de cancelamentos para controlar o limite mensal.

### Estrutura

| Campo | Tipo | Descrição |
|-------|------|-----------|
| `id` | UUID | Chave primária (auto-gerada) |
| `user_id` | UUID | Referência ao usuário (auth.users) |
| `booking_id` | UUID | Referência informativa ao booking cancelado |
| `cancelled_at` | TIMESTAMP WITH TIME ZONE | Data do cancelamento |

### Criar Tabela

```sql
CREATE TABLE IF NOT EXISTS public.cancellations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  booking_id UUID,
  cancelled_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);
```

### Habilitar RLS

```sql
ALTER TABLE public.cancellations ENABLE ROW LEVEL SECURITY;
```

### Políticas de Segurança (RLS)

#### Remover políticas antigas

```sql
DROP POLICY IF EXISTS "cancellations_select_policy" ON public.cancellations;
DROP POLICY IF EXISTS "cancellations_insert_policy" ON public.cancellations;
```

#### SELECT: Usuário vê seus cancelamentos, admin vê todos

```sql
CREATE POLICY "cancellations_select_policy"
ON public.cancellations
FOR SELECT
TO authenticated
USING (
  auth.uid() = user_id
  OR public.is_admin()
);
```

#### INSERT: Usuário pode registrar seus cancelamentos

```sql
CREATE POLICY "cancellations_insert_policy"
ON public.cancellations
FOR INSERT
TO authenticated
WITH CHECK (auth.uid() = user_id);
```

### Índices

```sql
CREATE INDEX IF NOT EXISTS idx_cancellations_user_id ON public.cancellations(user_id);
CREATE INDEX IF NOT EXISTS idx_cancellations_cancelled_at ON public.cancellations(cancelled_at);
```

---

## 5. Tabela: business_settings

### Descrição
Armazena configurações dinâmicas de regras de negócio que podem ser alteradas pelos admins.

### Estrutura

| Campo | Tipo | Descrição |
|-------|------|-----------|
| `id` | TEXT | Chave primária (default: 'default') |
| `cancellation_deadline_hours` | INTEGER | Horas antes da aula para cancelar (0-72) |
| `max_cancellations_per_month` | INTEGER | Máximo de cancelamentos/mês (0-30) |
| `cancellation_limit_enabled` | BOOLEAN | Se limite de cancelamentos está ativo |
| `max_bookings_per_week` | INTEGER | Máximo de reservas/semana (0-14) |
| `booking_limit_enabled` | BOOLEAN | Se limite de reservas está ativo |
| `min_booking_advance_hours` | INTEGER | Antecedência mínima em horas (0-168) |
| `default_class_capacity` | INTEGER | Capacidade padrão para novas aulas (1-100) |
| `default_lanes` | INTEGER | Raias padrão para novas aulas (1-20) |
| `updated_at` | TIMESTAMP WITH TIME ZONE | Data da última atualização |
| `updated_by` | UUID | ID do admin que atualizou |

### Criar Tabela

Consulte o arquivo `migration_admin_features.sql` para o script completo.

### Notas
- Esta tabela deve ter apenas um registro com id='default'
- Apenas admins podem modificar as configurações
- Todos os usuários autenticados podem ler as configurações

---

## 6. Funções Auxiliares

### is_future_class(p_class_id UUID)

Verifica se a aula é para amanhã ou depois.

```sql
CREATE OR REPLACE FUNCTION public.is_future_class(p_class_id UUID)
RETURNS BOOLEAN AS $$
DECLARE
  v_start_time TIMESTAMP WITH TIME ZONE;
  v_tomorrow DATE;
BEGIN
  SELECT start_time INTO v_start_time 
  FROM public.classes 
  WHERE id = p_class_id;
  
  v_tomorrow := (CURRENT_DATE + INTERVAL '1 day')::DATE;
  
  RETURN v_start_time::DATE >= v_tomorrow;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
```

### has_available_spots(p_class_id UUID)

Verifica se há vagas disponíveis na aula.

```sql
CREATE OR REPLACE FUNCTION public.has_available_spots(p_class_id UUID)
RETURNS BOOLEAN AS $$
DECLARE
  v_capacity INT;
  v_booked INT;
BEGIN
  SELECT capacity INTO v_capacity 
  FROM public.classes 
  WHERE id = p_class_id;
  
  SELECT COUNT(*) INTO v_booked 
  FROM public.bookings 
  WHERE class_id = p_class_id;
  
  RETURN v_booked < v_capacity;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
```

### has_time_conflict(p_user_id UUID, p_class_id UUID)

Verifica se o usuário já tem reserva que conflita no horário.

```sql
CREATE OR REPLACE FUNCTION public.has_time_conflict(p_user_id UUID, p_class_id UUID)
RETURNS BOOLEAN AS $$
DECLARE
  v_new_start TIMESTAMP WITH TIME ZONE;
  v_new_end TIMESTAMP WITH TIME ZONE;
  v_conflict_count INT;
BEGIN
  SELECT start_time, end_time INTO v_new_start, v_new_end
  FROM public.classes
  WHERE id = p_class_id;
  
  SELECT COUNT(*) INTO v_conflict_count
  FROM public.bookings b
  JOIN public.classes c ON b.class_id = c.id
  WHERE b.user_id = p_user_id
    AND b.class_id != p_class_id
    AND (
      (v_new_start >= c.start_time AND v_new_start < c.end_time)
      OR
      (v_new_end > c.start_time AND v_new_end <= c.end_time)
      OR
      (v_new_start <= c.start_time AND v_new_end >= c.end_time)
    );
  
  RETURN v_conflict_count > 0;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
```

### get_available_spots(p_class_id UUID)

Retorna o número de vagas disponíveis de uma aula.

```sql
CREATE OR REPLACE FUNCTION public.get_available_spots(p_class_id UUID)
RETURNS INT AS $$
DECLARE
  v_capacity INT;
  v_booked INT;
BEGIN
  SELECT capacity INTO v_capacity 
  FROM public.classes 
  WHERE id = p_class_id;
  
  SELECT COUNT(*) INTO v_booked 
  FROM public.bookings 
  WHERE class_id = p_class_id;
  
  RETURN GREATEST(0, v_capacity - v_booked);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
```

### Grants para as funções

```sql
GRANT EXECUTE ON FUNCTION public.is_future_class(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.has_available_spots(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.has_time_conflict(UUID, UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_available_spots(UUID) TO authenticated;
```

---

## 7. Ordem de Execução

Execute os scripts na seguinte ordem no Supabase SQL Editor:

1. **Profiles** - Criar tabela, trigger e função is_admin()
2. **Classes** - Criar tabela de aulas
3. **Bookings** - Criar tabela de reservas e funções de validação
4. **Cancellations** - Criar tabela de cancelamentos

---

## Script Completo

```sql
-- =============================================
-- PARTE 1: TABELA PROFILES
-- =============================================

CREATE TABLE IF NOT EXISTS public.profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  email TEXT,
  name TEXT,
  phone TEXT,
  avatar_url TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "profiles_select_policy" ON public.profiles;
DROP POLICY IF EXISTS "profiles_insert_policy" ON public.profiles;
DROP POLICY IF EXISTS "profiles_update_policy" ON public.profiles;

CREATE POLICY "profiles_select_policy"
ON public.profiles FOR SELECT TO authenticated
USING (true);

CREATE POLICY "profiles_insert_policy"
ON public.profiles FOR INSERT TO authenticated
WITH CHECK (auth.uid() = id);

CREATE POLICY "profiles_update_policy"
ON public.profiles FOR UPDATE TO authenticated
USING (auth.uid() = id)
WITH CHECK (auth.uid() = id);

CREATE INDEX IF NOT EXISTS idx_profiles_email ON public.profiles(email);

-- Trigger para criar perfil automaticamente
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger AS $$
BEGIN
  INSERT INTO public.profiles (id, email)
  VALUES (NEW.id, NEW.email)
  ON CONFLICT (id) DO NOTHING;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- Função is_admin()
CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS BOOLEAN AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.profiles
    WHERE id = auth.uid()
    AND role = 'admin'
  );
$$ LANGUAGE sql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION public.is_admin() TO authenticated;

-- =============================================
-- PARTE 2: TABELA CLASSES
-- =============================================

DROP TABLE IF EXISTS public.classes CASCADE;

CREATE TABLE public.classes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  title TEXT NOT NULL,
  description TEXT,
  start_time TIMESTAMP WITH TIME ZONE NOT NULL,
  end_time TIMESTAMP WITH TIME ZONE NOT NULL,
  capacity INT NOT NULL CHECK (capacity > 0),
  lanes INT NOT NULL CHECK (lanes > 0),
  type TEXT NOT NULL CHECK (type IN ('class', 'free')),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  CONSTRAINT classes_time_check CHECK (end_time > start_time)
);

ALTER TABLE public.classes ENABLE ROW LEVEL SECURITY;

CREATE POLICY "classes_select_policy" ON public.classes
FOR SELECT TO authenticated USING (true);

CREATE POLICY "classes_insert_policy" ON public.classes
FOR INSERT TO authenticated WITH CHECK (public.is_admin());

CREATE POLICY "classes_update_policy" ON public.classes
FOR UPDATE TO authenticated
USING (public.is_admin()) WITH CHECK (public.is_admin());

CREATE POLICY "classes_delete_policy" ON public.classes
FOR DELETE TO authenticated USING (public.is_admin());

CREATE INDEX IF NOT EXISTS idx_classes_start_time ON public.classes(start_time);
CREATE INDEX IF NOT EXISTS idx_classes_type ON public.classes(type);

-- =============================================
-- PARTE 3: TABELA BOOKINGS
-- =============================================

DROP TABLE IF EXISTS public.bookings CASCADE;

CREATE TABLE public.bookings (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  class_id UUID NOT NULL REFERENCES public.classes(id) ON DELETE CASCADE,
  checked_in BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  CONSTRAINT unique_user_class UNIQUE (user_id, class_id)
);

CREATE INDEX idx_bookings_user_id ON public.bookings(user_id);
CREATE INDEX idx_bookings_class_id ON public.bookings(class_id);
CREATE INDEX IF NOT EXISTS idx_bookings_checked_in ON public.bookings(checked_in);

ALTER TABLE public.bookings ENABLE ROW LEVEL SECURITY;

-- Funções de validação
CREATE OR REPLACE FUNCTION public.is_future_class(p_class_id UUID)
RETURNS BOOLEAN AS $$
DECLARE
  v_start_time TIMESTAMP WITH TIME ZONE;
  v_tomorrow DATE;
BEGIN
  SELECT start_time INTO v_start_time FROM public.classes WHERE id = p_class_id;
  v_tomorrow := (CURRENT_DATE + INTERVAL '1 day')::DATE;
  RETURN v_start_time::DATE >= v_tomorrow;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION public.has_available_spots(p_class_id UUID)
RETURNS BOOLEAN AS $$
DECLARE
  v_capacity INT;
  v_booked INT;
BEGIN
  SELECT capacity INTO v_capacity FROM public.classes WHERE id = p_class_id;
  SELECT COUNT(*) INTO v_booked FROM public.bookings WHERE class_id = p_class_id;
  RETURN v_booked < v_capacity;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION public.has_time_conflict(p_user_id UUID, p_class_id UUID)
RETURNS BOOLEAN AS $$
DECLARE
  v_new_start TIMESTAMP WITH TIME ZONE;
  v_new_end TIMESTAMP WITH TIME ZONE;
  v_conflict_count INT;
BEGIN
  SELECT start_time, end_time INTO v_new_start, v_new_end
  FROM public.classes WHERE id = p_class_id;
  
  SELECT COUNT(*) INTO v_conflict_count
  FROM public.bookings b
  JOIN public.classes c ON b.class_id = c.id
  WHERE b.user_id = p_user_id
    AND b.class_id != p_class_id
    AND (
      (v_new_start >= c.start_time AND v_new_start < c.end_time)
      OR (v_new_end > c.start_time AND v_new_end <= c.end_time)
      OR (v_new_start <= c.start_time AND v_new_end >= c.end_time)
    );
  
  RETURN v_conflict_count > 0;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION public.get_available_spots(p_class_id UUID)
RETURNS INT AS $$
DECLARE
  v_capacity INT;
  v_booked INT;
BEGIN
  SELECT capacity INTO v_capacity FROM public.classes WHERE id = p_class_id;
  SELECT COUNT(*) INTO v_booked FROM public.bookings WHERE class_id = p_class_id;
  RETURN GREATEST(0, v_capacity - v_booked);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION public.is_future_class(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.has_available_spots(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.has_time_conflict(UUID, UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_available_spots(UUID) TO authenticated;

-- Policies de bookings
CREATE POLICY "bookings_select_policy" ON public.bookings
FOR SELECT TO authenticated
USING (auth.uid() = user_id OR public.is_admin());

CREATE POLICY "bookings_insert_policy" ON public.bookings
FOR INSERT TO authenticated
WITH CHECK (
  auth.uid() = user_id
  AND public.is_future_class(class_id)
  AND public.has_available_spots(class_id)
  AND NOT public.has_time_conflict(auth.uid(), class_id)
);

CREATE POLICY "bookings_update_policy" ON public.bookings
FOR UPDATE TO authenticated
USING (public.is_admin())
WITH CHECK (public.is_admin());

CREATE POLICY "bookings_delete_policy" ON public.bookings
FOR DELETE TO authenticated
USING (auth.uid() = user_id OR public.is_admin());

-- =============================================
-- PARTE 4: TABELA CANCELLATIONS
-- =============================================

CREATE TABLE IF NOT EXISTS public.cancellations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  booking_id UUID,
  cancelled_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

ALTER TABLE public.cancellations ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "cancellations_select_policy" ON public.cancellations;
DROP POLICY IF EXISTS "cancellations_insert_policy" ON public.cancellations;

CREATE POLICY "cancellations_select_policy"
ON public.cancellations FOR SELECT TO authenticated
USING (auth.uid() = user_id OR public.is_admin());

CREATE POLICY "cancellations_insert_policy"
ON public.cancellations FOR INSERT TO authenticated
WITH CHECK (auth.uid() = user_id);

CREATE INDEX IF NOT EXISTS idx_cancellations_user_id ON public.cancellations(user_id);
CREATE INDEX IF NOT EXISTS idx_cancellations_cancelled_at ON public.cancellations(cancelled_at);
```

---

## View Opcional

Para queries mais simples, você pode criar uma view que já calcula a disponibilidade:

```sql
CREATE OR REPLACE VIEW public.classes_with_availability AS
SELECT 
  c.*,
  c.capacity - COALESCE(b.booked_count, 0) AS available_spots,
  COALESCE(b.booked_count, 0) AS booked_count
FROM public.classes c
LEFT JOIN (
  SELECT class_id, COUNT(*) AS booked_count
  FROM public.bookings
  GROUP BY class_id
) b ON c.id = b.class_id;

GRANT SELECT ON public.classes_with_availability TO authenticated;
```

---

## Regras de Negócio

1. **Reservas**: Apenas para aulas a partir de amanhã
2. **Limite de vagas**: Respeitado automaticamente via RLS
3. **Conflito de horários**: Usuário não pode ter duas aulas no mesmo horário
4. **Cancelamento**: Pelo próprio usuário ou admin (registrado em cancellations)
5. **Check-in**: Apenas admins podem fazer check-in de alunos
6. **Gerenciamento de aulas**: Apenas admins podem criar/editar/excluir
7. **Visualização**: Todos os usuários autenticados podem ver as aulas disponíveis
8. **Perfil automático**: Criado automaticamente via trigger quando usuário se registra
