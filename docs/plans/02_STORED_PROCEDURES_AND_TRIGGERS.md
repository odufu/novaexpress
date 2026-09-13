# Stored Procedures, Triggers & Edge Functions Plan

## 1. Overview

This document details all PostgreSQL triggers and stored procedures required to automate order pipeline communications, status milestone broadcasting, and the atomic order product/ownership transfer mechanism.

---

## 2. Trigger 1: Automatic Order Conversation Creation (`trg_create_order_conversation`)

### Purpose
Whenever an order is inserted or assigned to a Distribution Center, automatically create an entry in `order_conversations` with:
- The Client who created/owns the order
- The Handling Distribution Center
- An initial greeting/setup system message in `order_conversation_messages`

### Implementation
```sql
CREATE OR REPLACE FUNCTION public.fn_sync_order_conversation()
RETURNS TRIGGER AS $$
DECLARE
    v_conv_id UUID;
    v_client_name TEXT;
    v_dc_name TEXT;
    v_rider_name TEXT;
BEGIN
    -- Resolve client name if missing
    IF NEW.client_name IS NOT NULL AND NEW.client_name <> '' THEN
        v_client_name := NEW.client_name;
    ELSE
        SELECT company_name INTO v_client_name FROM public.clients WHERE id = NEW.client_id;
        IF v_client_name IS NULL THEN v_client_name := 'Merchant Client'; END IF;
    END IF;

    -- Resolve DC name
    IF NEW.distribution_center_id IS NOT NULL THEN
        SELECT name INTO v_dc_name FROM public.distribution_centers WHERE id = NEW.distribution_center_id;
    END IF;

    -- Resolve Rider name
    IF NEW.delivery_agent_id IS NOT NULL THEN
        SELECT full_name INTO v_rider_name FROM public.delivery_agents WHERE id = NEW.delivery_agent_id;
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
```

---

## 3. Trigger 2: Automatic Lifecycle Milestone Broadcasts (`trg_order_milestone_chat_broadcast`)

### Purpose
Generate automated system event pills in `order_conversation_messages` when:
1. **Rider is Assigned**: `"🛵 Order assigned to Rider [Name]. Rider is now added to this conversation."`
2. **Status Changes**:
   - `in_transit`: `"🚚 Rider [Name] is out for delivery with the package."`
   - `delivered`: `"✅ Order successfully delivered and payment collected. Amount: ₦[Amount]."`
   - `failed`: `"⚠️ Delivery attempt failed. Reason: [Notes]."`
   - `rescheduled`: `"📅 Delivery rescheduled to [Date]."`

### Implementation
```sql
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
        SELECT full_name INTO v_rider_name FROM public.delivery_agents WHERE id = NEW.delivery_agent_id;
        IF v_rider_name IS NULL THEN v_rider_name := 'Dispatch Rider'; END IF;

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
        
        -- Update conversation last message preview
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
```

---

## 4. Stored Procedure: Atomic Order Product & Ownership Transfer (`transfer_order_product_and_ownership`)

### Purpose
Executes the atomic workflow when a rider modifies an order's product or package during customer delivery:
1. Recalculates order amounts, unit counts, and package deal ID.
2. If new product belongs to a **different client**:
   - Reassigns `client_id`, `client_name`, and `client_company`.
   - Records `original_client_id` and timestamp for audit transparency.
   - Reassigns conversation `client_id` and `client_name` to the new merchant.
   - Posts a high-priority system announcement in the chat.
3. If new product belongs to the **same client**:
   - Updates package name, quantity, and total amount.
   - Posts package upgrade/downgrade announcement in the chat.
4. Adjusts physical inventory in vehicle custody / DC inventory.

### Implementation
```sql
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
            client_name = v_new_product.client_name,
            client_company = v_new_product.client_name,
            original_client_id = COALESCE(v_curr_order.original_client_id, v_curr_order.client_id),
            original_client_name = v_old_client_name,
            ownership_transferred_at = now(),
            ownership_transfer_reason = p_transfer_reason,
            updated_at = now()
        WHERE id = p_order_id;

        v_msg_type := 'ownership_transferred';
        v_msg_body := '🔄 Order Ownership Transferred! Customer switched product to "' || v_new_product.name || 
                      '" (' || p_new_package_name || '). Order transferred from "' || v_old_client_name || 
                      '" to "' || v_new_product.client_name || '". New COD to collect: ₦' || 
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
                client_name = v_new_product.client_name,
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
                'new_client', v_new_product.client_name,
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
        'new_client_name', v_new_product.client_name,
        'new_total_amount', p_new_total_amount,
        'message', v_msg_body
    );
END;
$$ LANGUAGE plpgsql;
```
