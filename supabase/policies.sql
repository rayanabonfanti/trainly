-- =============================================================================
-- TRAINLY - POLÍTICAS DE SEGURANÇA (RLS) PARA TABELA PROFILES
-- =============================================================================
-- Execute estas políticas no SQL Editor do Supabase Dashboard
-- Acesse: https://supabase.com/dashboard/project/<seu-projeto>/sql/new
-- =============================================================================

-- Primeiro, garanta que RLS está habilitado na tabela profiles
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;

-- =============================================================================
-- FUNÇÃO AUXILIAR: Verificar se usuário atual é admin
-- SECURITY DEFINER permite que a função ignore RLS ao verificar
-- =============================================================================
CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS BOOLEAN AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.profiles
    WHERE id = auth.uid()
    AND role = 'admin'
  );
$$ LANGUAGE sql SECURITY DEFINER;

-- =============================================================================
-- REMOVER POLICIES ANTIGAS (caso existam)
-- =============================================================================
DROP POLICY IF EXISTS "Users can view own profile" ON profiles;
DROP POLICY IF EXISTS "Admins can view all profiles" ON profiles;
DROP POLICY IF EXISTS "Users can update own profile except role" ON profiles;
DROP POLICY IF EXISTS "Only admins can update role" ON profiles;
DROP POLICY IF EXISTS "Enable insert for authenticated users" ON profiles;
DROP POLICY IF EXISTS "profiles_select_policy" ON profiles;
DROP POLICY IF EXISTS "profiles_update_policy" ON profiles;
DROP POLICY IF EXISTS "profiles_insert_policy" ON profiles;

-- =============================================================================
-- POLICY SELECT: Usuários veem seu próprio perfil OU admins veem todos
-- =============================================================================
CREATE POLICY "profiles_select_policy"
ON profiles
FOR SELECT
USING (
  auth.uid() = id 
  OR public.is_admin()
);

-- =============================================================================
-- POLICY UPDATE: Usuários atualizam seu perfil OU admins atualizam qualquer um
-- =============================================================================
CREATE POLICY "profiles_update_policy"
ON profiles
FOR UPDATE
USING (
  auth.uid() = id 
  OR public.is_admin()
)
WITH CHECK (
  auth.uid() = id 
  OR public.is_admin()
);

-- =============================================================================
-- POLICY INSERT: Novos perfis podem ser inseridos pelo próprio usuário
-- =============================================================================
CREATE POLICY "profiles_insert_policy"
ON profiles
FOR INSERT
WITH CHECK (auth.uid() = id);

-- =============================================================================
-- GRANT: Permitir que usuários autenticados executem a função
-- =============================================================================
GRANT EXECUTE ON FUNCTION public.is_admin() TO authenticated;

-- =============================================================================
-- NOTAS IMPORTANTES:
-- =============================================================================
-- 1. A função is_admin() usa SECURITY DEFINER para evitar recursão infinita
--    nas policies RLS.
--
-- 2. Estas policies garantem que:
--    - Usuários normais só podem ver/editar seu próprio perfil
--    - Admins podem ver e editar todos os perfis
--
-- 3. Para criar o primeiro admin, execute manualmente:
--    UPDATE profiles SET role = 'admin' WHERE email = 'seu-email@exemplo.com';
--
-- 4. Depois que o primeiro admin existir, ele pode promover outros via app
-- =============================================================================
