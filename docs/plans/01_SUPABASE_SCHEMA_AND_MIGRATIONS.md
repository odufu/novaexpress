# Supabase Schema & Database Migrations Plan

## 1. Migration Overview

- **Migration File**: `supabase/migrations/20260913130000_audit_and_chat_and_ownership_transfer.sql`
- **Target Database**: Supabase PostgreSQL Testing Environment (`qpcafevjsrbauweuiiyq`)
- **Key Deliverables**:
  1. Add missing schema columns to `products`, `orders`, and `client_settlements`.
  2. Create `order_conversations` table for order-level chat pipelines.
  3. Create `order_conversation_messages` table for real-time messaging and automated system event logs.
  4. Enable Supabase Realtime publication on both conversation tables.
  5. Add performance indexes for rapid conversation querying by order, client, DC, and rider.

---

## 2. Detailed Schema Definitions

### 2.1 Table Alterations: `products`
```sql
-- Ensure covering_states array exists on products table
ALTER TABLE public.products 
ADD COLUMN IF NOT EXISTS covering_states TEXT[] DEFAULT '{}';

-- Ensure dc_stocks jsonb exists for hub-level stock counts
ALTER TABLE public.products 
ADD COLUMN IF NOT EXISTS dc_stocks JSONB DEFAULT '{}'::jsonb;

-- Comment for developer clarity
COMMENT ON COLUMN public.products.covering_states IS 'List of state names where this client product is permitted for delivery';
COMMENT ON COLUMN public.products.dc_stocks IS 'Key-value map of {dc_id: quantity} representing physical stock held per distribution center';
```

### 2.2 Table Alterations: `orders`
```sql
-- Track order ownership changes and transfer history
ALTER TABLE public.orders 
ADD COLUMN IF NOT EXISTS original_client_id UUID REFERENCES public.clients(id) ON DELETE SET NULL;

ALTER TABLE public.orders 
ADD COLUMN IF NOT EXISTS original_client_name TEXT;

ALTER TABLE public.orders 
ADD COLUMN IF NOT EXISTS ownership_transferred_at TIMESTAMPTZ;

ALTER TABLE public.orders 
ADD COLUMN IF NOT EXISTS ownership_transfer_reason TEXT;

-- Index for querying transferred orders
CREATE INDEX IF NOT EXISTS idx_orders_original_client_id ON public.orders(original_client_id);
```

### 2.3 Table Alterations: `client_settlements`
```sql
-- Link settlements explicitly to the handling distribution center
ALTER TABLE public.client_settlements 
ADD COLUMN IF NOT EXISTS distribution_center_id UUID REFERENCES public.distribution_centers(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_client_settlements_dc_id ON public.client_settlements(distribution_center_id);
```

### 2.4 New Table: `order_conversations`
Represents the dedicated communication pipeline channel for an order.
```sql
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

-- Performance Indexes
CREATE INDEX IF NOT EXISTS idx_order_conversations_order_id ON public.order_conversations(order_id);
CREATE INDEX IF NOT EXISTS idx_order_conversations_client_id ON public.order_conversations(client_id);
CREATE INDEX IF NOT EXISTS idx_order_conversations_dc_id ON public.order_conversations(distribution_center_id);
CREATE INDEX IF NOT EXISTS idx_order_conversations_delivery_agent_id ON public.order_conversations(delivery_agent_id);
CREATE INDEX IF NOT EXISTS idx_order_conversations_last_message_at ON public.order_conversations(last_message_at DESC);
```

### 2.5 New Table: `order_conversation_messages`
Stores individual chat messages and automated system milestone announcements.
```sql
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
    
    -- Structured Metadata for rich UI rendering (old/new product, price diff, etc.)
    metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
    
    -- Read receipts
    read_by_client BOOLEAN NOT NULL DEFAULT false,
    read_by_dc BOOLEAN NOT NULL DEFAULT false,
    read_by_rider BOOLEAN NOT NULL DEFAULT false,
    
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Performance Indexes
CREATE INDEX IF NOT EXISTS idx_conversation_messages_conv_id ON public.order_conversation_messages(conversation_id);
CREATE INDEX IF NOT EXISTS idx_conversation_messages_order_id ON public.order_conversation_messages(order_id);
CREATE INDEX IF NOT EXISTS idx_conversation_messages_created_at ON public.order_conversation_messages(created_at ASC);
```

---

## 3. Realtime Publication Setup

To enable real-time message streaming and unread badge synchronization across all client, DC, and rider devices:

```sql
-- Enable Realtime for the conversation and message tables
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
```

---

## 4. Row Level Security (RLS) Policies

To enforce strict multi-tenant privacy while allowing authorized parties to chat:

```sql
ALTER TABLE public.order_conversations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.order_conversation_messages ENABLE ROW LEVEL SECURITY;

-- Allow authenticated users to view conversations they belong to:
CREATE POLICY "Users can view conversations relevant to them" ON public.order_conversations
FOR SELECT USING (
    -- Service role can read all
    auth.role() = 'service_role' OR
    -- Or user belongs to the client, DC, or is the assigned delivery agent
    EXISTS (
        SELECT 1 FROM public.users u
        WHERE u.id = auth.uid() AND (
            (u.role = 'client' AND u.client_id = order_conversations.client_id) OR
            (u.role = 'dc_manager' AND u.distribution_center_id = order_conversations.distribution_center_id) OR
            (u.delivery_agent_id = order_conversations.delivery_agent_id) OR
            (u.role = 'super_admin')
        )
    )
);

-- Allow authenticated users to view messages for conversations they belong to:
CREATE POLICY "Users can view messages in their conversations" ON public.order_conversation_messages
FOR SELECT USING (
    auth.role() = 'service_role' OR
    EXISTS (
        SELECT 1 FROM public.order_conversations oc
        JOIN public.users u ON u.id = auth.uid()
        WHERE oc.id = order_conversation_messages.conversation_id AND (
            (u.role = 'client' AND u.client_id = oc.client_id) OR
            (u.role = 'dc_manager' AND u.distribution_center_id = oc.distribution_center_id) OR
            (u.delivery_agent_id = oc.delivery_agent_id) OR
            (u.role = 'super_admin')
        )
    )
);

-- Allow sending messages:
CREATE POLICY "Users can insert messages into their conversations" ON public.order_conversation_messages
FOR INSERT WITH CHECK (
    auth.role() = 'service_role' OR
    EXISTS (
        SELECT 1 FROM public.order_conversations oc
        JOIN public.users u ON u.id = auth.uid()
        WHERE oc.id = order_conversation_messages.conversation_id AND (
            (u.role = 'client' AND u.client_id = oc.client_id) OR
            (u.role = 'dc_manager' AND u.distribution_center_id = oc.distribution_center_id) OR
            (u.delivery_agent_id = oc.delivery_agent_id) OR
            (u.role = 'super_admin')
        )
    )
);
```
