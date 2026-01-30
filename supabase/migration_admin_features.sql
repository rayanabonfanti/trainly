-- =============================================================================
-- TRAINLY - MIGRAÇÃO: FUNCIONALIDADES DE ADMIN
-- =============================================================================
-- Execute este SQL no Supabase Dashboard > SQL Editor
-- Este script adiciona as funcionalidades necessárias para o painel admin:
-- 1. Coluna 'role' na tabela profiles
-- 2. Tabela business_settings para configurações dinâmicas
-- 3. Função is_admin() para verificação de permissões
-- 4. Políticas de segurança para admins
-- =============================================================================

-- =============================================================================
-- PARTE 1: ADICIONAR COLUNA 'role' À TABELA profiles
-- =============================================================================
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' 
    AND table_name = 'profiles' 
    AND column_name = 'role'
  ) THEN
    ALTER TABLE public.profiles ADD COLUMN role TEXT DEFAULT 'student';
  END IF;
END $$;

-- Adicionar comentário explicativo
COMMENT ON COLUMN public.profiles.role IS 'Papel do usuário: student (padrão) ou admin';

-- Índice para buscar admins rapidamente
CREATE INDEX IF NOT EXISTS idx_profiles_role ON public.profiles(role);

-- =============================================================================
-- PARTE 2: FUNÇÃO is_admin()
-- =============================================================================
-- Verifica se o usuário atual é administrador
-- Usa SECURITY DEFINER para evitar recursão infinita nas policies RLS
CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS BOOLEAN AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.profiles
    WHERE id = auth.uid()
    AND role = 'admin'
  );
$$ LANGUAGE sql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION public.is_admin() TO authenticated;

-- =============================================================================
-- PARTE 3: POLICY para permitir que admins atualizem outros perfis
-- =============================================================================
-- Remove policy antiga se existir
DROP POLICY IF EXISTS "admins_can_update_profiles" ON public.profiles;

-- Admins podem atualizar qualquer perfil (para promover outros admins)
CREATE POLICY "admins_can_update_profiles"
ON public.profiles
FOR UPDATE
TO authenticated
USING (
  auth.uid() = id OR public.is_admin()
)
WITH CHECK (
  auth.uid() = id OR public.is_admin()
);

-- Remove a policy antiga de update que só permitia o próprio usuário
DROP POLICY IF EXISTS "profiles_update_policy" ON public.profiles;

-- =============================================================================
-- PARTE 4: TABELA business_settings
-- =============================================================================
CREATE TABLE IF NOT EXISTS public.business_settings (
    id TEXT PRIMARY KEY DEFAULT 'default',
    
    -- Regras de Cancelamento
    cancellation_deadline_hours INTEGER NOT NULL DEFAULT 2,
    max_cancellations_per_month INTEGER NOT NULL DEFAULT 2,
    cancellation_limit_enabled BOOLEAN NOT NULL DEFAULT true,
    
    -- Regras de Reserva
    max_bookings_per_week INTEGER NOT NULL DEFAULT 3,
    booking_limit_enabled BOOLEAN NOT NULL DEFAULT true,
    min_booking_advance_hours INTEGER NOT NULL DEFAULT 24,
    
    -- Padrões para Novas Aulas
    default_class_capacity INTEGER NOT NULL DEFAULT 10,
    default_lanes INTEGER NOT NULL DEFAULT 4,
    
    -- Metadados
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc', NOW()),
    updated_by UUID REFERENCES auth.users(id),
    
    -- Constraints
    CONSTRAINT valid_cancellation_deadline CHECK (cancellation_deadline_hours >= 0 AND cancellation_deadline_hours <= 72),
    CONSTRAINT valid_max_cancellations CHECK (max_cancellations_per_month >= 0 AND max_cancellations_per_month <= 30),
    CONSTRAINT valid_max_bookings CHECK (max_bookings_per_week >= 0 AND max_bookings_per_week <= 14),
    CONSTRAINT valid_min_advance CHECK (min_booking_advance_hours >= 0 AND min_booking_advance_hours <= 168),
    CONSTRAINT valid_capacity CHECK (default_class_capacity >= 1 AND default_class_capacity <= 100),
    CONSTRAINT valid_lanes CHECK (default_lanes >= 1 AND default_lanes <= 20)
);

-- Habilitar RLS
ALTER TABLE public.business_settings ENABLE ROW LEVEL SECURITY;

-- Políticas de acesso
DROP POLICY IF EXISTS "Usuários autenticados podem ler configurações" ON public.business_settings;
DROP POLICY IF EXISTS "Admins podem atualizar configurações" ON public.business_settings;

-- Todos os usuários autenticados podem ler as configurações
CREATE POLICY "Usuários autenticados podem ler configurações"
    ON public.business_settings
    FOR SELECT
    TO authenticated
    USING (true);

-- Apenas admins podem modificar as configurações
CREATE POLICY "Admins podem atualizar configurações"
    ON public.business_settings
    FOR ALL
    TO authenticated
    USING (public.is_admin())
    WITH CHECK (public.is_admin());

-- Inserir configurações padrão se não existir
INSERT INTO public.business_settings (id)
VALUES ('default')
ON CONFLICT (id) DO NOTHING;

-- Comentários para documentação
COMMENT ON TABLE public.business_settings IS 'Configurações de regras de negócio dinâmicas do sistema';
COMMENT ON COLUMN public.business_settings.cancellation_deadline_hours IS 'Horas antes da aula que ainda é permitido cancelar (0 = sem restrição)';
COMMENT ON COLUMN public.business_settings.max_cancellations_per_month IS 'Máximo de cancelamentos permitidos por mês por usuário';
COMMENT ON COLUMN public.business_settings.cancellation_limit_enabled IS 'Se o limite de cancelamentos está ativo';
COMMENT ON COLUMN public.business_settings.max_bookings_per_week IS 'Máximo de reservas ativas por semana por usuário';
COMMENT ON COLUMN public.business_settings.booking_limit_enabled IS 'Se o limite de reservas está ativo';
COMMENT ON COLUMN public.business_settings.min_booking_advance_hours IS 'Antecedência mínima em horas para fazer reserva (0 = pode reservar até o momento)';
COMMENT ON COLUMN public.business_settings.default_class_capacity IS 'Capacidade padrão para novas aulas';
COMMENT ON COLUMN public.business_settings.default_lanes IS 'Número de raias padrão para novas aulas';

-- =============================================================================
-- PARTE 5: CRIAR O PRIMEIRO ADMIN
-- =============================================================================
-- IMPORTANTE: Substitua 'seu-email@exemplo.com' pelo email do primeiro admin!
-- Descomente a linha abaixo e execute para criar o primeiro admin:
-- UPDATE public.profiles SET role = 'admin' WHERE email = 'seu-email@exemplo.com';

-- =============================================================================
-- VERIFICAÇÃO
-- =============================================================================
-- Após executar, verifique se tudo foi criado corretamente:
-- SELECT * FROM public.business_settings;
-- SELECT id, email, role FROM public.profiles WHERE role = 'admin';

-- =============================================================================
-- FIM DA MIGRAÇÃO
-- =============================================================================
