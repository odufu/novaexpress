-- ============================================================================
-- Migration: 20260913161000_auto_increment_chat_unreads_trigger.sql
-- Description:
--   Automatically updates order_conversations preview and increments unread counters
--   for recipient roles on every inserted message.
-- ============================================================================

CREATE OR REPLACE FUNCTION public.fn_on_order_message_inserted()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.sender_role = 'delivery_agent' THEN
        UPDATE public.order_conversations
        SET last_message_text = NEW.message_body,
            last_message_sender_name = NEW.sender_name,
            last_message_at = NEW.created_at,
            unread_rider_count = 0,
            unread_dc_count = unread_dc_count + 1,
            unread_client_count = unread_client_count + 1,
            updated_at = now()
        WHERE id = NEW.conversation_id;

    ELSIF NEW.sender_role = 'dc_manager' THEN
        UPDATE public.order_conversations
        SET last_message_text = NEW.message_body,
            last_message_sender_name = NEW.sender_name,
            last_message_at = NEW.created_at,
            unread_dc_count = 0,
            unread_rider_count = unread_rider_count + 1,
            unread_client_count = unread_client_count + 1,
            updated_at = now()
        WHERE id = NEW.conversation_id;

    ELSIF NEW.sender_role = 'client' THEN
        UPDATE public.order_conversations
        SET last_message_text = NEW.message_body,
            last_message_sender_name = NEW.sender_name,
            last_message_at = NEW.created_at,
            unread_client_count = 0,
            unread_rider_count = unread_rider_count + 1,
            unread_dc_count = unread_dc_count + 1,
            updated_at = now()
        WHERE id = NEW.conversation_id;

    ELSE
        -- System or milestone notification
        UPDATE public.order_conversations
        SET last_message_text = NEW.message_body,
            last_message_sender_name = NEW.sender_name,
            last_message_at = NEW.created_at,
            unread_rider_count = unread_rider_count + 1,
            unread_dc_count = unread_dc_count + 1,
            unread_client_count = unread_client_count + 1,
            updated_at = now()
        WHERE id = NEW.conversation_id;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trg_on_order_message_inserted ON public.order_conversation_messages;
CREATE TRIGGER trg_on_order_message_inserted
AFTER INSERT ON public.order_conversation_messages
FOR EACH ROW
EXECUTE FUNCTION public.fn_on_order_message_inserted();
