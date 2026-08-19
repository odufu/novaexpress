-- ============================================================================
-- NovaExpress Logistics Management System
-- Dynamic Notifications Engine & Automated Ledger Triggers
-- ============================================================================

CREATE TABLE IF NOT EXISTS notifications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID REFERENCES companies(id) ON DELETE CASCADE,
    delivery_agent_id UUID REFERENCES delivery_agents(id) ON DELETE CASCADE,
    title VARCHAR(255) NOT NULL,
    message TEXT NOT NULL,
    category VARCHAR(50) NOT NULL DEFAULT 'system', -- 'delivery', 'finance', 'stock', 'system'
    action_route TEXT,
    is_read BOOLEAN DEFAULT false,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Index for high-performance agent notification queries
CREATE INDEX IF NOT EXISTS idx_notifications_agent_id ON notifications(delivery_agent_id);
CREATE INDEX IF NOT EXISTS idx_notifications_category ON notifications(category);

-- ----------------------------------------------------------------------------
-- 1. TRIGGER: Automatic Notification on Cash Remittance Status Changes
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION trg_notify_remittance_status()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    IF (TG_OP = 'INSERT') THEN
        INSERT INTO notifications (company_id, delivery_agent_id, title, message, category, action_route)
        VALUES (
            NEW.company_id,
            NEW.delivery_agent_id,
            'Remittance Submitted 💸',
            'Your cash remittance of ₦' || TO_CHAR(NEW.amount, 'FM999,999,999') || ' (Ref: ' || COALESCE(NEW.reference_number, 'RMT-PENDING') || ') was logged and sent for DC verification.',
            'finance',
            '/cash/history'
        );
    ELSIF (TG_OP = 'UPDATE' AND OLD.status IS DISTINCT FROM NEW.status) THEN
        IF (NEW.status = 'approved') THEN
            INSERT INTO notifications (company_id, delivery_agent_id, title, message, category, action_route)
            VALUES (
                NEW.company_id,
                NEW.delivery_agent_id,
                'Remittance Approved ✓',
                'Your cash remittance of ₦' || TO_CHAR(NEW.amount, 'FM999,999,999') || ' (Ref: ' || COALESCE(NEW.reference_number, 'RMT-APPROVED') || ') was verified and reconciled by Wuse DC Finance desk.',
                'finance',
                '/cash/history'
            );
        ELSIF (NEW.status = 'rejected') THEN
            INSERT INTO notifications (company_id, delivery_agent_id, title, message, category, action_route)
            VALUES (
                NEW.company_id,
                NEW.delivery_agent_id,
                'Remittance Returned ⚠️',
                'Your remittance of ₦' || TO_CHAR(NEW.amount, 'FM999,999,999') || ' requires attention. Please contact Wuse DC Finance desk.',
                'finance',
                '/cash/history'
            );
        END IF;
    END IF;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_remittance_notification ON cash_remittances;
CREATE TRIGGER trg_remittance_notification
AFTER INSERT OR UPDATE ON cash_remittances
FOR EACH ROW
EXECUTE FUNCTION trg_notify_remittance_status();

-- ----------------------------------------------------------------------------
-- 2. SEED LIVE NOTIFICATIONS FOR ACCOUNT PDA-7000
-- ----------------------------------------------------------------------------
INSERT INTO notifications (company_id, delivery_agent_id, title, message, category, action_route, is_read)
VALUES
(
    '11111111-1111-4111-8111-111111111111',
    'b1111111-1111-4111-8111-111111111111',
    'New Delivery Assigned 📦',
    'Order TRK-8925 (Dr. Aisha Garba) in Maitama has been assigned to your queue.',
    'delivery',
    '/orders',
    false
),
(
    '11111111-1111-4111-8111-111111111111',
    'b1111111-1111-4111-8111-111111111111',
    'Remittance Approved ✓',
    'Your cash remittance of ₦15,000 (RMT-0004) has been verified and reconciled by Wuse DC Finance desk.',
    'finance',
    '/cash/history',
    false
),
(
    '11111111-1111-4111-8111-111111111111',
    'b1111111-1111-4111-8111-111111111111',
    'Stock Replenishment Ready 🏷️',
    'Transfer request REQ-00482 (20x Respira, 15x Grazer) is packaged and ready for pickup at Wuse DC counter.',
    'stock',
    '/orders/scan',
    false
),
(
    '11111111-1111-4111-8111-111111111111',
    NULL, -- Broadcast notification for all agents in company
    'Security & Field Advisory ⚠️',
    'Rain advisory in Lekki/Ajah & CBD expressway. Maintain speed safety and verify waterproof package seals.',
    'system',
    NULL,
    true
)
ON CONFLICT DO NOTHING;

NOTIFY pgrst, 'reload schema';
