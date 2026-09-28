-- ============================================================================
-- Migration: 20260928100000_supervisory_marketer_hierarchy_and_delivery_audit.sql
-- Description:
--   Supervisory Digital Marketer Realtime Delivery Notification & Hierarchy Aggregation:
--   1. Enhances fn_handle_order_delivery_marketer_lifecycle to automatically notify
--      the Supervisory Marketer when a supervisee's attributed order is delivered to buyer.
--   2. Adds fn_get_marketer_supervisees RPC to aggregate supervisee performance,
--      daily budget, conversion rates, and financial commission balances in a single indexed query.
-- ============================================================================

-- 1. Enhanced Delivery Lifecycle Trigger with Supervisory Alert
CREATE OR REPLACE FUNCTION public.fn_handle_order_delivery_marketer_lifecycle()
RETURNS TRIGGER AS $$
DECLARE
    v_marketer RECORD;
    v_supervisor RECORD;
    v_commission_amount NUMERIC := 0.00;
    v_company_id UUID;
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
                    unpaid_commission_balance = COALESCE(unpaid_commission_balance, 0.00) + v_commission_amount,
                    updated_at = NOW()
                WHERE id = v_marketer.id;

                -- Update linked lead_form delivery count if form_id is present
                IF NEW.form_id IS NOT NULL THEN
                    UPDATE public.lead_forms
                    SET total_orders_delivered = COALESCE(total_orders_delivered, 0) + 1,
                        updated_at = NOW()
                    WHERE id = NEW.form_id;
                END IF;

                -- Resolve company_id for notifications
                BEGIN
                    SELECT company_id INTO v_company_id FROM public.clients WHERE id = NEW.client_id;
                EXCEPTION WHEN OTHERS THEN
                    v_company_id := NULL;
                END;
                IF v_company_id IS NULL THEN
                    BEGIN
                        SELECT id INTO v_company_id FROM public.companies LIMIT 1;
                    EXCEPTION WHEN OTHERS THEN
                        v_company_id := NULL;
                    END;
                END IF;
                IF v_company_id IS NULL THEN
                    v_company_id := '11111111-1111-4111-8111-111111111111'::UUID;
                END IF;

                -- In-app notification to the primary marketer
                IF v_marketer.user_id IS NOT NULL THEN
                    BEGIN
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
                            v_company_id,
                            v_marketer.user_id,
                            'Buyer Received Delivery! 📦🎉',
                            'Ad Order #' || NEW.order_number || ' (' || NEW.customer_name || ' in ' || COALESCE(NEW.delivery_lga, NEW.delivery_city, 'LGA') || ') was delivered and confirmed by rider.' ||
                            CASE WHEN v_commission_amount > 0 THEN ' Commission of ₦' || v_commission_amount || ' credited.' ELSE '' END,
                            'marketing',
                            '/marketing',
                            false,
                            NOW()
                        );
                    EXCEPTION WHEN OTHERS THEN
                        NULL;
                    END;
                END IF;

                -- B. If marketer is subordinate to a Supervisor, notify the Supervisor as well
                IF v_marketer.supervisor_id IS NOT NULL THEN
                    SELECT * INTO v_supervisor FROM public.client_marketers WHERE id = v_marketer.supervisor_id;
                    IF v_supervisor.id IS NOT NULL AND v_supervisor.user_id IS NOT NULL THEN
                        BEGIN
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
                                v_company_id,
                                v_supervisor.user_id,
                                'Team Order Delivered! 📦🎉',
                                'Supervised media buyer ' || v_marketer.full_name || ' achieved verified delivery for Order #' || NEW.order_number || ' (' || NEW.product_name || ' in ' || COALESCE(NEW.delivery_lga, NEW.delivery_city, 'LGA') || ').',
                                'marketing',
                                '/marketing',
                                false,
                                NOW()
                            );
                        EXCEPTION WHEN OTHERS THEN
                            NULL;
                        END;
                    END IF;
                END IF;

            END IF;
        END IF;

        -- C. Post Lifecycle Milestone message into Pipeline Chat
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

-- 2. Stored Procedure: fn_get_marketer_supervisees
CREATE OR REPLACE FUNCTION public.fn_get_marketer_supervisees(p_supervisor_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_result JSONB;
BEGIN
    SELECT COALESCE(
        jsonb_agg(
            jsonb_build_object(
                'id', m.id,
                'client_id', m.client_id,
                'user_id', m.user_id,
                'marketer_code', m.marketer_code,
                'full_name', m.full_name,
                'email', m.email,
                'phone', m.phone,
                'is_active', m.is_active,
                'daily_ad_spend_budget', m.daily_ad_spend_budget,
                'commission_rate', m.commission_rate,
                'is_commission_enabled', m.is_commission_enabled,
                'is_supervisor', m.is_supervisor,
                'supervisor_id', m.supervisor_id,
                'commission_type', m.commission_type,
                'commission_per_form_submission', m.commission_per_form_submission,
                'commission_per_delivered_order', m.commission_per_delivered_order,
                'bank_name', m.bank_name,
                'account_number', m.account_number,
                'account_name', m.account_name,
                'avatar_url', m.avatar_url,
                'total_leads_generated', m.total_leads_generated,
                'total_orders_generated', m.total_orders_generated,
                'total_orders_delivered', m.total_orders_delivered,
                'total_commission_earned', m.total_commission_earned,
                'unpaid_commission_balance', m.unpaid_commission_balance,
                'total_paid_commission', m.total_paid_commission,
                'active_forms_count', (SELECT COUNT(*) FROM public.lead_forms lf WHERE lf.marketer_id = m.id AND lf.is_active = true),
                'total_forms_count', (SELECT COUNT(*) FROM public.lead_forms lf WHERE lf.marketer_id = m.id),
                'created_at', m.created_at,
                'updated_at', m.updated_at
            ) ORDER BY m.total_orders_delivered DESC, m.full_name ASC
        ),
        '[]'::jsonb
    ) INTO v_result
    FROM public.client_marketers m
    WHERE m.supervisor_id = p_supervisor_id AND m.id != p_supervisor_id;

    RETURN v_result;
END;
$$;

-- Grant permissions to authenticated, anon and service_role
GRANT EXECUTE ON FUNCTION public.fn_get_marketer_supervisees(UUID) TO authenticated, service_role, anon;
