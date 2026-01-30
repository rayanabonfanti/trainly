-- =============================================================================
-- TRAINLY - ATUALIZAÇÃO TABELA BOOKINGS (CHECK-IN)
-- =============================================================================
-- Execute este SQL no Supabase Dashboard > SQL Editor
-- Adiciona campo checked_in para controle de presença
-- =============================================================================

-- Adiciona coluna checked_in se não existir
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

-- Índice para consultas de check-in
CREATE INDEX IF NOT EXISTS idx_bookings_checked_in ON public.bookings(checked_in);

-- =============================================================================
-- ATUALIZAR POLICY DE UPDATE PARA PERMITIR CHECK-IN
-- =============================================================================
DROP POLICY IF EXISTS "bookings_update_policy" ON public.bookings;

-- Admin pode atualizar qualquer booking (para check-in)
CREATE POLICY "bookings_update_policy"
ON public.bookings
FOR UPDATE
TO authenticated
USING (public.is_admin())
WITH CHECK (public.is_admin());
