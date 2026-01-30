-- =============================================================================
-- TRAINLY - TABELA DE CANCELAMENTOS (CANCELLATIONS)
-- =============================================================================
-- Execute este SQL no Supabase Dashboard > SQL Editor
-- Usado para controlar limite de cancelamentos por mês
-- =============================================================================

-- =============================================================================
-- CRIAR TABELA: public.cancellations
-- =============================================================================
CREATE TABLE IF NOT EXISTS public.cancellations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  booking_id UUID,  -- Referência informativa, não constraint
  cancelled_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- =============================================================================
-- HABILITAR RLS
-- =============================================================================
ALTER TABLE public.cancellations ENABLE ROW LEVEL SECURITY;

-- =============================================================================
-- POLICIES
-- =============================================================================
DROP POLICY IF EXISTS "cancellations_select_policy" ON public.cancellations;
DROP POLICY IF EXISTS "cancellations_insert_policy" ON public.cancellations;

-- Usuário vê apenas seus cancelamentos, admin vê todos
CREATE POLICY "cancellations_select_policy"
ON public.cancellations
FOR SELECT
TO authenticated
USING (
  auth.uid() = user_id
  OR public.is_admin()
);

-- Usuário pode registrar seus cancelamentos
CREATE POLICY "cancellations_insert_policy"
ON public.cancellations
FOR INSERT
TO authenticated
WITH CHECK (auth.uid() = user_id);

-- =============================================================================
-- ÍNDICES
-- =============================================================================
CREATE INDEX IF NOT EXISTS idx_cancellations_user_id ON public.cancellations(user_id);
CREATE INDEX IF NOT EXISTS idx_cancellations_cancelled_at ON public.cancellations(cancelled_at);
