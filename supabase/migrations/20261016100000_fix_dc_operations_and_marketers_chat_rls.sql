-- ============================================================================
-- MIGRATION: Fix DC Operations, Closers, Marketers, and Dispatch Chat RLS
-- Problem: Users with role 'dc_operations', 'operations_officer', 'dispatcher',
--          'marketer', etc. are denied by RLS on order_conversations and
--          order_conversation_messages. When realtime stream connects with
--          authenticated session, RLS returns 0 rows, wiping out messages in UI.
-- ============================================================================

-- 1. Relax and fix order_conversations SELECT policy
DROP POLICY IF EXISTS "Users can view conversations relevant to them" ON public.order_conversations;
CREATE POLICY "Users can view conversations relevant to them" ON public.order_conversations
FOR SELECT USING (
    auth.role() = 'service_role' OR
    (
        auth.uid() IS NOT NULL AND
        EXISTS (
            SELECT 1 FROM public.users u
            LEFT JOIN public.delivery_agents da ON da.user_id = u.id
            LEFT JOIN public.client_closers cc ON cc.user_id = u.id
            WHERE u.id = auth.uid() AND (
                -- Merchant / Client
                (u.role IN ('client', 'merchant', 'seller') AND u.client_id::text = order_conversations.client_id::text) OR
                -- All DC Operations, Managers, Supervisors, Dispatchers
                (u.role IN ('dc_operations', 'operations_officer', 'dispatcher', 'ops_officer', 'operations', 'dc_manager', 'dc_supervisor', 'dc_staff') AND (
                    order_conversations.distribution_center_id IS NULL OR
                    u.distribution_center_id::text = order_conversations.distribution_center_id::text OR
                    u.distribution_center_id::text = '22222222-2222-4222-8222-222222222222' OR
                    order_conversations.distribution_center_id::text = '22222222-2222-4222-8222-222222222222'
                )) OR
                -- Delivery Riders
                (da.id::text = order_conversations.delivery_agent_id::text OR u.id::text = order_conversations.delivery_agent_id::text) OR
                -- Telesales Closers
                (cc.id::text = order_conversations.closer_id::text OR u.id::text = order_conversations.closer_id::text) OR
                -- Digital Marketers
                (u.role IN ('marketer', 'digital_marketer', 'marketing_supervisor') AND (
                    u.id::text = order_conversations.marketer_id::text OR 
                    u.marketer_id::text = order_conversations.marketer_id::text
                )) OR
                -- Platform Admins
                (u.role IN ('super_admin', 'admin'))
            )
        )
    )
);

-- 2. Relax and fix order_conversations UPDATE policy
DROP POLICY IF EXISTS "Users can update their conversations" ON public.order_conversations;
CREATE POLICY "Users can update their conversations" ON public.order_conversations
FOR UPDATE USING (
    auth.role() = 'service_role' OR
    (
        auth.uid() IS NOT NULL AND
        EXISTS (
            SELECT 1 FROM public.users u
            LEFT JOIN public.delivery_agents da ON da.user_id = u.id
            LEFT JOIN public.client_closers cc ON cc.user_id = u.id
            WHERE u.id = auth.uid() AND (
                (u.role IN ('client', 'merchant', 'seller') AND u.client_id::text = order_conversations.client_id::text) OR
                (u.role IN ('dc_operations', 'operations_officer', 'dispatcher', 'ops_officer', 'operations', 'dc_manager', 'dc_supervisor', 'dc_staff') AND (
                    order_conversations.distribution_center_id IS NULL OR
                    u.distribution_center_id::text = order_conversations.distribution_center_id::text OR
                    u.distribution_center_id::text = '22222222-2222-4222-8222-222222222222' OR
                    order_conversations.distribution_center_id::text = '22222222-2222-4222-8222-222222222222'
                )) OR
                (da.id::text = order_conversations.delivery_agent_id::text OR u.id::text = order_conversations.delivery_agent_id::text) OR
                (cc.id::text = order_conversations.closer_id::text OR u.id::text = order_conversations.closer_id::text) OR
                (u.role IN ('marketer', 'digital_marketer', 'marketing_supervisor') AND (
                    u.id::text = order_conversations.marketer_id::text OR 
                    u.marketer_id::text = order_conversations.marketer_id::text
                )) OR
                (u.role IN ('super_admin', 'admin'))
            )
        )
    )
);

-- 3. Relax and fix order_conversation_messages SELECT policy
DROP POLICY IF EXISTS "Users can view messages in their conversations" ON public.order_conversation_messages;
CREATE POLICY "Users can view messages in their conversations" ON public.order_conversation_messages
FOR SELECT USING (
    auth.role() = 'service_role' OR
    (
        auth.uid() IS NOT NULL AND
        EXISTS (
            SELECT 1 FROM public.order_conversations oc
            JOIN public.users u ON u.id = auth.uid()
            LEFT JOIN public.delivery_agents da ON da.user_id = u.id
            LEFT JOIN public.client_closers cc ON cc.user_id = u.id
            WHERE oc.id = order_conversation_messages.conversation_id AND (
                (u.role IN ('client', 'merchant', 'seller') AND u.client_id::text = oc.client_id::text) OR
                (u.role IN ('dc_operations', 'operations_officer', 'dispatcher', 'ops_officer', 'operations', 'dc_manager', 'dc_supervisor', 'dc_staff') AND (
                    oc.distribution_center_id IS NULL OR
                    u.distribution_center_id::text = oc.distribution_center_id::text OR
                    u.distribution_center_id::text = '22222222-2222-4222-8222-222222222222' OR
                    oc.distribution_center_id::text = '22222222-2222-4222-8222-222222222222'
                )) OR
                (da.id::text = oc.delivery_agent_id::text OR u.id::text = oc.delivery_agent_id::text) OR
                (cc.id::text = oc.closer_id::text OR u.id::text = oc.closer_id::text) OR
                (u.role IN ('marketer', 'digital_marketer', 'marketing_supervisor') AND (
                    u.id::text = oc.marketer_id::text OR 
                    u.marketer_id::text = oc.marketer_id::text
                )) OR
                (u.role IN ('super_admin', 'admin'))
            )
        )
    )
);

-- 4. Relax and fix order_conversation_messages INSERT policy
DROP POLICY IF EXISTS "Users can insert messages into their conversations" ON public.order_conversation_messages;
CREATE POLICY "Users can insert messages into their conversations" ON public.order_conversation_messages
FOR INSERT WITH CHECK (
    auth.role() = 'service_role' OR
    (
        auth.uid() IS NOT NULL AND
        EXISTS (
            SELECT 1 FROM public.order_conversations oc
            JOIN public.users u ON u.id = auth.uid()
            LEFT JOIN public.delivery_agents da ON da.user_id = u.id
            LEFT JOIN public.client_closers cc ON cc.user_id = u.id
            WHERE oc.id = order_conversation_messages.conversation_id AND (
                (u.role IN ('client', 'merchant', 'seller') AND u.client_id::text = oc.client_id::text) OR
                (u.role IN ('dc_operations', 'operations_officer', 'dispatcher', 'ops_officer', 'operations', 'dc_manager', 'dc_supervisor', 'dc_staff') AND (
                    oc.distribution_center_id IS NULL OR
                    u.distribution_center_id::text = oc.distribution_center_id::text OR
                    u.distribution_center_id::text = '22222222-2222-4222-8222-222222222222' OR
                    oc.distribution_center_id::text = '22222222-2222-4222-8222-222222222222'
                )) OR
                (da.id::text = oc.delivery_agent_id::text OR u.id::text = oc.delivery_agent_id::text) OR
                (cc.id::text = oc.closer_id::text OR u.id::text = oc.closer_id::text) OR
                (u.role IN ('marketer', 'digital_marketer', 'marketing_supervisor') AND (
                    u.id::text = oc.marketer_id::text OR 
                    u.marketer_id::text = oc.marketer_id::text
                )) OR
                (u.role IN ('super_admin', 'admin'))
            )
        )
    )
);
