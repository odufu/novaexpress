-- ============================================================================
-- Migration: 20260913130000_audit_and_chat_and_ownership_transfer.sql
-- Description:
--   1. Add covering_states and dc_stocks to products table
--   2. Add order transfer tracking columns to orders table
--   3. Add distribution_center_id to client_settlements
--   4. Create order_conversations table for order-level chat pipelines
--   5. Create order_conversation_messages table with automated system events
--   6. Realtime publication for chat tables
--   7. RLS policies for multi-tenant privacy (with explicit casting and rider join)
--   8. Trigger fn_sync_order_conversation for automated chat creation
--   9. Trigger fn_order_milestone_chat_broadcast for status events
--  10. Stored procedure transfer_order_product_and_ownership for atomic transfer
--  11. Backfill conversations for existing orders
-- ============================================================================

-- 1. Table Alterations: products
ALTER TABLE public.products 
ADD COLUMN IF NOT EXISTS covering_states TEXT[] DEFAULT '{}';

ALTER TABLE public.products 
ADD COLUMN IF NOT EXISTS dc_stocks JSONB DEFAULT '{}'::jsonb;

-- 2. Table Alterations: orders
ALTER TABLE public.orders 
ADD COLUMN IF NOT EXISTS original_client_id UUID REFERENCES public.clients(id) ON DELETE SET NULL;

ALTER TABLE public.orders 
ADD COLUMN IF NOT EXISTS original_client_name TEXT;

ALTER TABLE public.orders 
ADD COLUMN IF NOT EXISTS ownership_transferred_at TIMESTAMPTZ;

ALTER TABLE public.orders 
ADD COLUMN IF NOT EXISTS ownership_transfer_reason TEXT;

CREATE INDEX IF NOT EXISTS idx_orders_original_client_id ON public.orders(original_client_id);

-- 3. Table Alterations: client_settlements
ALTER TABLE public.client_settlements 
ADD COLUMN IF NOT EXISTS distribution_center_id UUID REFERENCES public.distribution_centers(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_client_settlements_dc_id ON public.client_settlements(distribution_center_id);

-- 4. New Table: order_conversations
CREATE TABLE IF NOT EXISTS public.order_conversations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    order_id UUID NOT NULL REFERENCES public.orders(id) ON DELETE CASCADE UNIQUE,
    order_number TEXT NOT NULL,
    customer_name TEXT NOT NULL,
    customer_phone TEXT,
    
    -- Client participant
    client_id UUID NOT NULL REFERENCES public.clients(id) ON DELETE CASCADE,
    client_name TEXT NOT NULL,
    
    -- DC participant
    distribution_center_id UUID REFERENCES public.distribution_centers(id) ON DELETE SET NULL,
    distribution_center_name TEXT,
    
    -- Rider participant
    delivery_agent_id UUID REFERENCES public.delivery_agents(id) ON DELETE SET NULL,
    delivery_agent_name TEXT,
    
    -- Pipeline metadata & state
    order_status TEXT NOT NULL DEFAULT 'pending',
    current_product_name TEXT,
    current_package_name TEXT,
    current_total_amount NUMERIC(12, 2) DEFAULT 0,
    
    -- Last message preview for WhatsApp-style chat list
    last_message_text TEXT,
    last_message_sender_name TEXT,
    last_message_at TIMESTAMPTZ DEFAULT now(),
    
    -- Unread badges
    unread_client_count INT NOT NULL DEFAULT 0,
    unread_dc_count INT NOT NULL DEFAULT 0,
    unread_rider_count INT NOT NULL DEFAULT 0,
    
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_order_conversations_order_id ON public.order_conversations(order_id);
CREATE INDEX IF NOT EXISTS idx_order_conversations_client_id ON public.order_conversations(client_id);
CREATE INDEX IF NOT EXISTS idx_order_conversations_dc_id ON public.order_conversations(distribution_center_id);
CREATE INDEX IF NOT EXISTS idx_order_conversations_delivery_agent_id ON public.order_conversations(delivery_agent_id);
CREATE INDEX IF NOT EXISTS idx_order_conversations_last_message_at ON public.order_conversations(last_message_at DESC);

-- 5. New Table: order_conversation_messages
CREATE TABLE IF NOT EXISTS public.order_conversation_messages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    conversation_id UUID NOT NULL REFERENCES public.order_conversations(id) ON DELETE CASCADE,
    order_id UUID NOT NULL REFERENCES public.orders(id) ON DELETE CASCADE,
    
    -- Sender Information
    sender_id UUID,
    sender_name TEXT NOT NULL,
    sender_role TEXT NOT NULL CHECK (sender_role IN ('client', 'dc_manager', 'delivery_agent', 'system')),
    
    -- Message Classification
    message_type TEXT NOT NULL DEFAULT 'text' CHECK (
        message_type IN (
            'text',
            'status_change',
            'rider_assigned',
            'product_changed',
            'ownership_transferred',
            'delivery_completed',
            'delivery_failed',
            'rescheduled'
        )
    ),
    
    message_body TEXT NOT NULL,
    
    -- Structured Metadata for rich UI rendering
    metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
    
    -- Read receipts
    read_by_client BOOLEAN NOT NULL DEFAULT false,
    read_by_dc BOOLEAN NOT NULL DEFAULT false,
    read_by_rider BOOLEAN NOT NULL DEFAULT false,
    
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_conversation_messages_conv_id ON public.order_conversation_messages(conversation_id);
CREATE INDEX IF NOT EXISTS idx_conversation_messages_order_id ON public.order_conversation_messages(order_id);
CREATE INDEX IF NOT EXISTS idx_conversation_messages_created_at ON public.order_conversation_messages(created_at ASC);

-- 6. Realtime Publication Setup
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_publication_tables 
        WHERE pubname = 'supabase_realtime' AND tablename = 'order_conversations'
    ) THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.order_conversations;
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_publication_tables 
        WHERE pubname = 'supabase_realtime' AND tablename = 'order_conversation_messages'
    ) THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.order_conversation_messages;
    END IF;
END $$;

-- 7. Row Level Security (RLS)
ALTER TABLE public.order_conversations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.order_conversation_messages ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
    DROP POLICY IF EXISTS "Users can view conversations relevant to them" ON public.order_conversations;
    CREATE POLICY "Users can view conversations relevant to them" ON public.order_conversations
    FOR SELECT USING (
        auth.role() = 'service_role' OR
        auth.uid() IS NULL OR
        EXISTS (
            SELECT 1 FROM public.users u
            LEFT JOIN public.delivery_agents da ON da.user_id = u.id
            WHERE u.id = auth.uid() AND (
                (u.role = 'client' AND u.client_id::text = order_conversations.client_id::text) OR
                (u.role = 'dc_manager' AND u.distribution_center_id::text = order_conversations.distribution_center_id::text) OR
                (da.id::text = order_conversations.delivery_agent_id::text) OR
                (u.role = 'super_admin')
            )
        )
    );

    DROP POLICY IF EXISTS "Users can view messages in their conversations" ON public.order_conversation_messages;
    CREATE POLICY "Users can view messages in their conversations" ON public.order_conversation_messages
    FOR SELECT USING (
        auth.role() = 'service_role' OR
        auth.uid() IS NULL OR
        EXISTS (
            SELECT 1 FROM public.order_conversations oc
            JOIN public.users u ON u.id = auth.uid()
            LEFT JOIN public.delivery_agents da ON da.user_id = u.id
            WHERE oc.id = order_conversation_messages.conversation_id AND (
                (u.role = 'client' AND u.client_id::text = oc.client_id::text) OR
                (u.role = 'dc_manager' AND u.distribution_center_id::text = oc.distribution_center_id::text) OR
                (da.id::text = oc.delivery_agent_id::text) OR
                (u.role = 'super_admin')
            )
        )
    );

    DROP POLICY IF EXISTS "Users can insert messages into their conversations" ON public.order_conversation_messages;
    CREATE POLICY "Users can insert messages into their conversations" ON public.order_conversation_messages
    FOR INSERT WITH CHECK (
        auth.role() = 'service_role' OR
        auth.uid() IS NULL OR
        EXISTS (
            SELECT 1 FROM public.order_conversations oc
            JOIN public.users u ON u.id = auth.uid()
            LEFT JOIN public.delivery_agents da ON da.user_id = u.id
            WHERE oc.id = order_conversation_messages.conversation_id AND (
                (u.role = 'client' AND u.client_id::text = oc.client_id::text) OR
                (u.role = 'dc_manager' AND u.distribution_center_id::text = oc.distribution_center_id::text) OR
                (da.id::text = oc.delivery_agent_id::text) OR
                (u.role = 'super_admin')
            )
        )
    );
END $$;

-- 8. Trigger Function: Sync Order Conversation
CREATE OR REPLACE FUNCTION public.fn_sync_order_conversation()
RETURNS TRIGGER AS $$
DECLARE
    v_conv_id UUID;
    v_client_name TEXT;
    v_dc_name TEXT;
    v_rider_name TEXT;
BEGIN
    -- Only sync if client_id is present
    IF NEW.client_id IS NULL THEN
        RETURN NEW;
    END IF;

    -- Resolve client name if missing
    IF NEW.client_name IS NOT NULL AND NEW.client_name <> '' THEN
        v_client_name := NEW.client_name;
    ELSE
        SELECT COALESCE(company_name, name) INTO v_client_name FROM public.clients WHERE id = NEW.client_id;
        IF v_client_name IS NULL THEN v_client_name := 'Merchant Client'; END IF;
    END IF;

    -- Resolve DC name
    IF NEW.distribution_center_id IS NOT NULL THEN
        SELECT name INTO v_dc_name FROM public.distribution_centers WHERE id = NEW.distribution_center_id;
    END IF;

    -- Resolve Rider name via delivery_agents -> users join
    IF NEW.delivery_agent_id IS NOT NULL THEN
        SELECT COALESCE(TRIM(u.first_name || ' ' || u.last_name), da.agent_code, 'Dispatch Rider')
        INTO v_rider_name
        FROM public.delivery_agents da
        LEFT JOIN public.users u ON u.id = da.user_id
        WHERE da.id = NEW.delivery_agent_id;
    END IF;

    -- Upsert Conversation
    INSERT INTO public.order_conversations (
        order_id,
        order_number,
        customer_name,
        customer_phone,
        client_id,
        client_name,
        distribution_center_id,
        distribution_center_name,
        delivery_agent_id,
        delivery_agent_name,
        order_status,
        current_product_name,
        current_package_name,
        current_total_amount,
        last_message_text,
        last_message_sender_name,
        last_message_at,
        updated_at
    ) VALUES (
        NEW.id,
        COALESCE(NEW.order_number, 'ORD-' || SUBSTRING(NEW.id::text, 1, 8)),
        COALESCE(NEW.customer_name, 'Customer'),
        NEW.customer_phone,
        NEW.client_id,
        v_client_name,
        NEW.distribution_center_id,
        v_dc_name,
        NEW.delivery_agent_id,
        v_rider_name,
        COALESCE(NEW.status, 'pending'),
        NEW.product_name,
        COALESCE(NEW.package_deal_name, 'Standard Package'),
        COALESCE(NEW.total_amount, 0),
        '💬 Order pipeline conversation opened.',
        'System',
        now(),
        now()
    )
    ON CONFLICT (order_id) DO UPDATE SET
        client_id = EXCLUDED.client_id,
        client_name = EXCLUDED.client_name,
        distribution_center_id = EXCLUDED.distribution_center_id,
        distribution_center_name = EXCLUDED.distribution_center_name,
        delivery_agent_id = EXCLUDED.delivery_agent_id,
        delivery_agent_name = EXCLUDED.delivery_agent_name,
        order_status = EXCLUDED.order_status,
        current_product_name = EXCLUDED.current_product_name,
        current_package_name = EXCLUDED.current_package_name,
        current_total_amount = EXCLUDED.current_total_amount,
        updated_at = now()
    RETURNING id INTO v_conv_id;

    -- On initial insert, post welcome system message
    IF TG_OP = 'INSERT' THEN
        INSERT INTO public.order_conversation_messages (
            conversation_id,
            order_id,
            sender_name,
            sender_role,
            message_type,
            message_body,
            metadata
        ) VALUES (
            v_conv_id,
            NEW.id,
            'System Bot',
            'system',
            'text',
            '📦 Pipeline conversation initiated. Client "' || v_client_name || '" connected with handling DC' || 
                CASE WHEN v_dc_name IS NOT NULL THEN ' "' || v_dc_name || '".' ELSE '.' END,
            jsonb_build_object('event', 'order_created', 'order_id', NEW.id)
        );
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_sync_order_conversation ON public.orders;
CREATE TRIGGER trg_sync_order_conversation
AFTER INSERT OR UPDATE OF distribution_center_id, delivery_agent_id, client_id, status, product_name, package_deal_name, total_amount
ON public.orders
FOR EACH ROW
EXECUTE FUNCTION public.fn_sync_order_conversation();

-- 9. Trigger Function: Order Milestone Chat Broadcast
CREATE OR REPLACE FUNCTION public.fn_order_milestone_chat_broadcast()
RETURNS TRIGGER AS $$
DECLARE
    v_conv_id UUID;
    v_rider_name TEXT;
    v_msg_type TEXT;
    v_body TEXT;
BEGIN
    SELECT id INTO v_conv_id FROM public.order_conversations WHERE order_id = NEW.id;
    IF v_conv_id IS NULL THEN RETURN NEW; END IF;

    -- Event 1: Rider Assigned
    IF (OLD.delivery_agent_id IS DISTINCT FROM NEW.delivery_agent_id) AND NEW.delivery_agent_id IS NOT NULL THEN
        SELECT COALESCE(TRIM(u.first_name || ' ' || u.last_name), da.agent_code, 'Dispatch Rider')
        INTO v_rider_name
        FROM public.delivery_agents da
        LEFT JOIN public.users u ON u.id = da.user_id
        WHERE da.id = NEW.delivery_agent_id;

        INSERT INTO public.order_conversation_messages (
            conversation_id, order_id, sender_name, sender_role, message_type, message_body, metadata
        ) VALUES (
            v_conv_id,
            NEW.id,
            'System Bot',
            'system',
            'rider_assigned',
            '🛵 Order assigned to Rider ' || v_rider_name || '. Rider has joined this conversation.',
            jsonb_build_object('delivery_agent_id', NEW.delivery_agent_id, 'rider_name', v_rider_name)
        );
        
        UPDATE public.order_conversations 
        SET last_message_text = '🛵 Order assigned to ' || v_rider_name,
            last_message_sender_name = 'System',
            last_message_at = now()
        WHERE id = v_conv_id;
    END IF;

    -- Event 2: Order Status Changed
    IF (OLD.status IS DISTINCT FROM NEW.status) THEN
        IF NEW.status = 'in_transit' THEN
            v_msg_type := 'status_change';
            v_body := '🚚 Package is out for delivery with the rider.';
        ELSIF NEW.status = 'delivered' THEN
            v_msg_type := 'delivery_completed';
            v_body := '✅ Order successfully delivered! Total collected: ₦' || TO_CHAR(COALESCE(NEW.total_amount, 0), 'FM999,999,990.00');
        ELSIF NEW.status = 'failed' THEN
            v_msg_type := 'delivery_failed';
            v_body := '❌ Delivery attempt failed. ' || COALESCE(NEW.delivery_notes, 'Customer unavailable.');
        ELSIF NEW.status = 'rescheduled' THEN
            v_msg_type := 'rescheduled';
            v_body := '📅 Order has been rescheduled for delivery.';
        ELSE
            v_msg_type := 'status_change';
            v_body := '📋 Order status updated to: ' || UPPER(NEW.status);
        END IF;

        INSERT INTO public.order_conversation_messages (
            conversation_id, order_id, sender_name, sender_role, message_type, message_body, metadata
        ) VALUES (
            v_conv_id,
            NEW.id,
            'System Bot',
            'system',
            v_msg_type,
            v_body,
            jsonb_build_object('old_status', OLD.status, 'new_status', NEW.status)
        );

        UPDATE public.order_conversations 
        SET last_message_text = v_body,
            last_message_sender_name = 'System',
            last_message_at = now()
        WHERE id = v_conv_id;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_order_milestone_chat_broadcast ON public.orders;
CREATE TRIGGER trg_order_milestone_chat_broadcast
AFTER UPDATE OF status, delivery_agent_id
ON public.orders
FOR EACH ROW
EXECUTE FUNCTION public.fn_order_milestone_chat_broadcast();

-- 10. Stored Procedure: Atomic Product & Ownership Transfer
CREATE OR REPLACE FUNCTION public.transfer_order_product_and_ownership(
    p_order_id UUID,
    p_new_product_id UUID,
    p_new_package_deal_id TEXT,
    p_new_package_name TEXT,
    p_new_quantity INT,
    p_new_paid_quantity INT,
    p_new_free_quantity INT,
    p_new_base_price NUMERIC,
    p_new_total_amount NUMERIC,
    p_actor_name TEXT,
    p_actor_role TEXT,
    p_transfer_reason TEXT
)
RETURNS JSONB AS $$
DECLARE
    v_curr_order RECORD;
    v_new_product RECORD;
    v_old_client_name TEXT;
    v_new_client_name TEXT;
    v_conv_id UUID;
    v_is_ownership_transfer BOOLEAN := false;
    v_msg_body TEXT;
    v_msg_type TEXT;
BEGIN
    -- 1. Fetch Current Order
    SELECT * INTO v_curr_order FROM public.orders WHERE id = p_order_id FOR UPDATE;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Order with ID % not found', p_order_id;
    END IF;

    -- 2. Fetch New Product
    SELECT * INTO v_new_product FROM public.products WHERE id = p_new_product_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Product with ID % not found', p_new_product_id;
    END IF;

    v_old_client_name := COALESCE(v_curr_order.client_name, 'Original Client');

    -- Resolve New Client Name
    SELECT COALESCE(company_name, name) INTO v_new_client_name FROM public.clients WHERE id = v_new_product.client_id;
    IF v_new_client_name IS NULL THEN v_new_client_name := 'Merchant Client'; END IF;

    -- 3. Check if ownership transfer is required
    IF v_curr_order.client_id <> v_new_product.client_id THEN
        v_is_ownership_transfer := true;
    END IF;

    -- 4. Update Order Record
    IF v_is_ownership_transfer THEN
        UPDATE public.orders SET
            product_id = v_new_product.id,
            product_name = v_new_product.name,
            product_sku = v_new_product.sku,
            package_deal_id = p_new_package_deal_id,
            package_deal_name = p_new_package_name,
            quantity = p_new_quantity,
            paid_quantity = p_new_paid_quantity,
            free_quantity = p_new_free_quantity,
            base_price = p_new_base_price,
            total_amount = p_new_total_amount,
            -- Ownership transfer fields
            client_id = v_new_product.client_id,
            client_name = v_new_client_name,
            client_company = v_new_client_name,
            original_client_id = COALESCE(v_curr_order.original_client_id, v_curr_order.client_id),
            original_client_name = v_old_client_name,
            ownership_transferred_at = now(),
            ownership_transfer_reason = p_transfer_reason,
            updated_at = now()
        WHERE id = p_order_id;

        v_msg_type := 'ownership_transferred';
        v_msg_body := '🔄 Order Ownership Transferred! Customer switched product to "' || v_new_product.name || 
                      '" (' || p_new_package_name || '). Order transferred from "' || v_old_client_name || 
                      '" to "' || v_new_client_name || '". New COD to collect: ₦' || 
                      TO_CHAR(p_new_total_amount, 'FM999,999,990.00');
    ELSE
        -- Same client package deal modification
        UPDATE public.orders SET
            package_deal_id = p_new_package_deal_id,
            package_deal_name = p_new_package_name,
            quantity = p_new_quantity,
            paid_quantity = p_new_paid_quantity,
            free_quantity = p_new_free_quantity,
            base_price = p_new_base_price,
            total_amount = p_new_total_amount,
            updated_at = now()
        WHERE id = p_order_id;

        v_msg_type := 'product_changed';
        v_msg_body := '📦 Order Package Updated to "' || p_new_package_name || '" (' || p_new_quantity || 
                      ' units). Total payable: ₦' || TO_CHAR(p_new_total_amount, 'FM999,999,990.00');
    END IF;

    -- 5. Update Order Conversation & Post Announcement
    SELECT id INTO v_conv_id FROM public.order_conversations WHERE order_id = p_order_id;
    IF v_conv_id IS NOT NULL THEN
        IF v_is_ownership_transfer THEN
            UPDATE public.order_conversations SET
                client_id = v_new_product.client_id,
                client_name = v_new_client_name,
                current_product_name = v_new_product.name,
                current_package_name = p_new_package_name,
                current_total_amount = p_new_total_amount,
                last_message_text = v_msg_body,
                last_message_sender_name = p_actor_name,
                last_message_at = now(),
                updated_at = now()
            WHERE id = v_conv_id;
        ELSE
            UPDATE public.order_conversations SET
                current_package_name = p_new_package_name,
                current_total_amount = p_new_total_amount,
                last_message_text = v_msg_body,
                last_message_sender_name = p_actor_name,
                last_message_at = now(),
                updated_at = now()
            WHERE id = v_conv_id;
        END IF;

        INSERT INTO public.order_conversation_messages (
            conversation_id,
            order_id,
            sender_name,
            sender_role,
            message_type,
            message_body,
            metadata
        ) VALUES (
            v_conv_id,
            p_order_id,
            p_actor_name,
            p_actor_role,
            v_msg_type,
            v_msg_body,
            jsonb_build_object(
                'old_product', v_curr_order.product_name,
                'new_product', v_new_product.name,
                'old_package', v_curr_order.package_deal_name,
                'new_package', p_new_package_name,
                'old_amount', v_curr_order.total_amount,
                'new_amount', p_new_total_amount,
                'old_client', v_old_client_name,
                'new_client', v_new_client_name,
                'ownership_transferred', v_is_ownership_transfer,
                'reason', p_transfer_reason
            )
        );
    END IF;

    RETURN jsonb_build_object(
        'success', true,
        'order_id', p_order_id,
        'ownership_transferred', v_is_ownership_transfer,
        'new_client_id', v_new_product.client_id,
        'new_client_name', v_new_client_name,
        'new_total_amount', p_new_total_amount,
        'message', v_msg_body
    );
END;
$$ LANGUAGE plpgsql;

-- 11. Backfill Conversations for Existing Orders
DO $$
DECLARE
    r RECORD;
    v_conv_id UUID;
    v_client_name TEXT;
    v_dc_name TEXT;
    v_rider_name TEXT;
BEGIN
    FOR r IN SELECT * FROM public.orders WHERE client_id IS NOT NULL LOOP
        IF r.client_name IS NOT NULL AND r.client_name <> '' THEN
            v_client_name := r.client_name;
        ELSE
            SELECT COALESCE(company_name, name) INTO v_client_name FROM public.clients WHERE id = r.client_id;
            IF v_client_name IS NULL THEN v_client_name := 'Merchant Client'; END IF;
        END IF;

        IF r.distribution_center_id IS NOT NULL THEN
            SELECT name INTO v_dc_name FROM public.distribution_centers WHERE id = r.distribution_center_id;
        ELSE
            v_dc_name := NULL;
        END IF;

        IF r.delivery_agent_id IS NOT NULL THEN
            SELECT COALESCE(TRIM(u.first_name || ' ' || u.last_name), da.agent_code, 'Dispatch Rider')
            INTO v_rider_name
            FROM public.delivery_agents da
            LEFT JOIN public.users u ON u.id = da.user_id
            WHERE da.id = r.delivery_agent_id;
        ELSE
            v_rider_name := NULL;
        END IF;

        INSERT INTO public.order_conversations (
            order_id,
            order_number,
            customer_name,
            customer_phone,
            client_id,
            client_name,
            distribution_center_id,
            distribution_center_name,
            delivery_agent_id,
            delivery_agent_name,
            order_status,
            current_product_name,
            current_package_name,
            current_total_amount,
            last_message_text,
            last_message_sender_name,
            last_message_at,
            created_at,
            updated_at
        ) VALUES (
            r.id,
            COALESCE(r.order_number, 'ORD-' || SUBSTRING(r.id::text, 1, 8)),
            COALESCE(r.customer_name, 'Customer'),
            r.customer_phone,
            r.client_id,
            v_client_name,
            r.distribution_center_id,
            v_dc_name,
            r.delivery_agent_id,
            v_rider_name,
            COALESCE(r.status, 'pending'),
            r.product_name,
            COALESCE(r.package_deal_name, 'Standard Package'),
            COALESCE(r.total_amount, 0),
            '💬 Order pipeline conversation opened.',
            'System',
            COALESCE(r.updated_at, r.created_at, now()),
            COALESCE(r.created_at, now()),
            COALESCE(r.updated_at, now())
        )
        ON CONFLICT (order_id) DO NOTHING
        RETURNING id INTO v_conv_id;

        IF v_conv_id IS NOT NULL THEN
            INSERT INTO public.order_conversation_messages (
                conversation_id,
                order_id,
                sender_name,
                sender_role,
                message_type,
                message_body,
                created_at
            ) VALUES (
                v_conv_id,
                r.id,
                'System Bot',
                'system',
                'text',
                '📦 Pipeline conversation initiated for order ' || COALESCE(r.order_number, r.id::text),
                COALESCE(r.created_at, now())
            );
        END IF;
    END LOOP;
END $$;
