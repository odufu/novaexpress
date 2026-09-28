-- ============================================================================
-- Migration: 20260928101500_fix_company_id_in_delivery_notification.sql
-- Description:
--   Ensures company_id is dynamically resolved and notifications never block delivery.
-- ============================================================================

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
