-- ============================================================================
-- Migration: 20260928090000_marketer_delivery_lifecycle_and_commission_trigger.sql
-- Description:
--   Digital Marketer End-to-End Lifecycle Automation:
--   1. Ensures lead_forms has total_orders_delivered tracking column.
--   2. Automates Marketer Delivery Commission & Stats when orders reach 'delivered':
--      - Increments client_marketers.total_orders_delivered.
--      - Automatically credits total_commission_earned when commission_type = 'per_delivered_order'.
--      - Increments lead_forms.total_orders_delivered.
--      - Dispatches realtime in-app notification to the Digital Marketer.
--      - Broadcasts verified POD delivery milestone into order_conversations pipeline chat.
-- ============================================================================

-- 1. Extend lead_forms with total_orders_delivered column
ALTER TABLE public.lead_forms
  ADD COLUMN IF NOT EXISTS total_orders_delivered INT DEFAULT 0;

-- 2. Stored Procedure for Order Delivery Marketer Lifecycle
CREATE OR REPLACE FUNCTION public.fn_handle_order_delivery_marketer_lifecycle()
RETURNS TRIGGER AS $$
DECLARE
    v_marketer RECORD;
    v_commission_amount NUMERIC := 0.00;
    v_form RECORD;
BEGIN
    -- Only fire when status transitions to 'delivered' or 'completed'
    IF (OLD.status IS DISTINCT FROM NEW.status) AND (LOWER(NEW.status) IN ('delivered', 'completed')) THEN
        
        -- A. If order has an attached Digital Marketer
        IF NEW.marketer_id IS NOT NULL THEN
            SELECT * INTO v_marketer FROM public.client_marketers WHERE id = NEW.marketer_id;
            
            IF v_marketer.id IS NOT NULL THEN
                -- Compute delivery commission if model is per_delivered_order
                IF v_marketer.commission_type = 'per_delivered_order' OR COALESCE(v_marketer.commission_per_delivered_order, 0) > 0 THEN
                    v_commission_amount := COALESCE(NULLIF(v_marketer.commission_per_delivered_order, 0), NULLIF(v_marketer.commission_rate, 0), 2000.00);
                END IF;

                -- Update marketer performance stats & earned balance
                UPDATE public.client_marketers
                SET total_orders_delivered = COALESCE(total_orders_delivered, 0) + 1,
                    total_commission_earned = COALESCE(total_commission_earned, 0) + v_commission_amount,
                    updated_at = NOW()
                WHERE id = v_marketer.id;

                -- Update linked lead_form delivery count if form_id is present
                IF NEW.form_id IS NOT NULL THEN
                    UPDATE public.lead_forms
                    SET total_orders_delivered = COALESCE(total_orders_delivered, 0) + 1,
                        updated_at = NOW()
                    WHERE id = NEW.form_id;
                END IF;

                -- Send in-app push notification to the marketer
                IF v_marketer.user_id IS NOT NULL THEN
                    INSERT INTO public.notifications (
                        company_id,
                        user_id,
                        title,
                        message,
                        category,
                        action_route,
                        is_read,
                        created_at
                    ) VALUES (
                        COALESCE(NEW.client_id, '11111111-1111-4111-8111-111111111111'),
                        v_marketer.user_id,
                        'Buyer Received Delivery! 📦🎉',
                        'Ad Order #' || NEW.order_number || ' (' || NEW.customer_name || ' in ' || COALESCE(NEW.delivery_lga, NEW.delivery_city, 'LGA') || ') was delivered and confirmed by rider.' ||
                        CASE WHEN v_commission_amount > 0 THEN ' Commission of ₦' || v_commission_amount || ' credited.' ELSE '' END,
                        'marketing',
                        '/marketing',
                        false,
                        NOW()
                    );
                END IF;
            END IF;
        END IF;

        -- B. Post Lifecycle Milestone message into Pipeline Chat
        BEGIN
            PERFORM public.fn_sync_order_conversation(
                NEW.id,
                'System Notification',
                'system',
                '✅ Package Delivered & Received: Order #' || NEW.order_number || ' (' || NEW.product_name || ') has been successfully delivered to customer with verified POD.',
                NULL
            );
        EXCEPTION WHEN OTHERS THEN
            NULL; -- Non-blocking for conversation chat sync
        END;

    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 3. Bind Trigger to public.orders
DROP TRIGGER IF EXISTS trg_orders_marketer_delivery_lifecycle ON public.orders;
CREATE TRIGGER trg_orders_marketer_delivery_lifecycle
    AFTER UPDATE OF status ON public.orders
    FOR EACH ROW
    EXECUTE FUNCTION public.fn_handle_order_delivery_marketer_lifecycle();

NOTIFY pgrst, 'reload schema';
