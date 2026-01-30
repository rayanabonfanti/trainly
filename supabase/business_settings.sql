-- Tabela de configurações de negócio dinâmicas
-- Esta tabela armazena configurações que o admin pode alterar

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
-- Todos os usuários autenticados podem ler as configurações
CREATE POLICY "Usuários autenticados podem ler configurações"
    ON public.business_settings
    FOR SELECT
    TO authenticated
    USING (true);

-- Apenas admins podem atualizar as configurações
-- Nota: Você precisará ajustar esta policy baseado em como você identifica admins
-- Opção 1: Usando a tabela admins existente
CREATE POLICY "Admins podem atualizar configurações"
    ON public.business_settings
    FOR ALL
    TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.admins
            WHERE admins.user_id = auth.uid()
        )
    )
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.admins
            WHERE admins.user_id = auth.uid()
        )
    );

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
