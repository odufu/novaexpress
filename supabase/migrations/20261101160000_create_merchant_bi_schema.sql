-- ==============================================================================
-- MIGRATION: 20261101160000_create_merchant_bi_schema.sql
-- DESCRIPTION: NovaBI AI Business Intelligence tables for Merchant Admin Chat,
--              interactive visualizations (charts, flowcharts, trends), and custom knowledge.
-- ==============================================================================

-- 1. MERCHANT BI CHAT SESSIONS
CREATE TABLE IF NOT EXISTS public.merchant_bi_chats (
    id TEXT PRIMARY KEY,
    client_id UUID NOT NULL REFERENCES public.clients(id) ON DELETE CASCADE,
    title TEXT NOT NULL DEFAULT 'Executive Intelligence',
    last_message TEXT,
    is_pinned BOOLEAN DEFAULT false,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_merchant_bi_chats_client_id 
    ON public.merchant_bi_chats(client_id);
CREATE INDEX IF NOT EXISTS idx_merchant_bi_chats_updated_at 
    ON public.merchant_bi_chats(updated_at DESC);

-- 2. MERCHANT BI MESSAGES (WITH CHART & FLOWCHART PAYLOADS)
CREATE TABLE IF NOT EXISTS public.merchant_bi_messages (
    id TEXT PRIMARY KEY,
    chat_id TEXT NOT NULL REFERENCES public.merchant_bi_chats(id) ON DELETE CASCADE,
    client_id UUID NOT NULL REFERENCES public.clients(id) ON DELETE CASCADE,
    sender TEXT NOT NULL CHECK (sender IN ('user', 'ai', 'system')),
    content TEXT NOT NULL,
    chart_payload JSONB,
    quick_prompts JSONB DEFAULT '[]'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_merchant_bi_messages_chat_id 
    ON public.merchant_bi_messages(chat_id);
CREATE INDEX IF NOT EXISTS idx_merchant_bi_messages_client_id 
    ON public.merchant_bi_messages(client_id);
CREATE INDEX IF NOT EXISTS idx_merchant_bi_messages_created_at 
    ON public.merchant_bi_messages(created_at ASC);

-- 3. MERCHANT BI CUSTOM KNOWLEDGE BASE (MERCHANT-SUPPLIED INSTRUCTIONS & USPs)
CREATE TABLE IF NOT EXISTS public.merchant_bi_custom_knowledge (
    id TEXT PRIMARY KEY,
    client_id UUID NOT NULL REFERENCES public.clients(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    content TEXT NOT NULL,
    tags JSONB DEFAULT '[]'::jsonb,
    is_active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_merchant_bi_knowledge_client_id 
    ON public.merchant_bi_custom_knowledge(client_id);

-- 4. ROW LEVEL SECURITY (RLS) POLICIES
ALTER TABLE public.merchant_bi_chats ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.merchant_bi_messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.merchant_bi_custom_knowledge ENABLE ROW LEVEL SECURITY;

-- Allow authenticated users to access only records belonging to their merchant organization
CREATE POLICY "Merchant BI Chats tenant isolation"
    ON public.merchant_bi_chats
    FOR ALL
    TO authenticated
    USING (
        client_id IN (
            SELECT client_id FROM public.clients_users WHERE user_id = auth.uid()
            UNION
            SELECT id FROM public.clients WHERE id = auth.uid()
        )
    )
    WITH CHECK (
        client_id IN (
            SELECT client_id FROM public.clients_users WHERE user_id = auth.uid()
            UNION
            SELECT id FROM public.clients WHERE id = auth.uid()
        )
    );

CREATE POLICY "Merchant BI Messages tenant isolation"
    ON public.merchant_bi_messages
    FOR ALL
    TO authenticated
    USING (
        client_id IN (
            SELECT client_id FROM public.clients_users WHERE user_id = auth.uid()
            UNION
            SELECT id FROM public.clients WHERE id = auth.uid()
        )
    )
    WITH CHECK (
        client_id IN (
            SELECT client_id FROM public.clients_users WHERE user_id = auth.uid()
            UNION
            SELECT id FROM public.clients WHERE id = auth.uid()
        )
    );

CREATE POLICY "Merchant BI Knowledge tenant isolation"
    ON public.merchant_bi_custom_knowledge
    FOR ALL
    TO authenticated
    USING (
        client_id IN (
            SELECT client_id FROM public.clients_users WHERE user_id = auth.uid()
            UNION
            SELECT id FROM public.clients WHERE id = auth.uid()
        )
    )
    WITH CHECK (
        client_id IN (
            SELECT client_id FROM public.clients_users WHERE user_id = auth.uid()
            UNION
            SELECT id FROM public.clients WHERE id = auth.uid()
        )
    );

-- 5. GRANTS
GRANT ALL ON public.merchant_bi_chats TO authenticated, service_role;
GRANT ALL ON public.merchant_bi_messages TO authenticated, service_role;
GRANT ALL ON public.merchant_bi_custom_knowledge TO authenticated, service_role;

