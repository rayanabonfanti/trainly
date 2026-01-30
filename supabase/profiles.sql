-- =============================================================================
-- TRAINLY - TABELA DE PERFIS (PROFILES)
-- =============================================================================
-- Execute este SQL no Supabase Dashboard > SQL Editor
-- =============================================================================

-- =============================================================================
-- CRIAR TABELA: public.profiles
-- =============================================================================
CREATE TABLE IF NOT EXISTS public.profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  email TEXT,
  name TEXT,
  phone TEXT,
  avatar_url TEXT,
  role TEXT DEFAULT 'student', -- 'student' ou 'admin'
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Índice para buscar admins rapidamente
CREATE INDEX IF NOT EXISTS idx_profiles_role ON public.profiles(role);

-- Comentário explicativo
COMMENT ON COLUMN public.profiles.role IS 'Papel do usuário: student (padrão) ou admin';

-- =============================================================================
-- HABILITAR RLS
-- =============================================================================
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

-- =============================================================================
-- POLICIES
-- =============================================================================
DROP POLICY IF EXISTS "profiles_select_policy" ON public.profiles;
DROP POLICY IF EXISTS "profiles_insert_policy" ON public.profiles;
DROP POLICY IF EXISTS "profiles_update_policy" ON public.profiles;

-- Qualquer usuário autenticado pode ver perfis (para admins verem alunos)
CREATE POLICY "profiles_select_policy"
ON public.profiles
FOR SELECT
TO authenticated
USING (true);

-- Usuário pode criar seu próprio perfil
CREATE POLICY "profiles_insert_policy"
ON public.profiles
FOR INSERT
TO authenticated
WITH CHECK (auth.uid() = id);

-- Usuário pode atualizar seu próprio perfil
CREATE POLICY "profiles_update_policy"
ON public.profiles
FOR UPDATE
TO authenticated
USING (auth.uid() = id)
WITH CHECK (auth.uid() = id);

-- =============================================================================
-- ÍNDICES
-- =============================================================================
CREATE INDEX IF NOT EXISTS idx_profiles_email ON public.profiles(email);

-- =============================================================================
-- TRIGGER para criar perfil automaticamente quando usuário é criado
-- =============================================================================
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
