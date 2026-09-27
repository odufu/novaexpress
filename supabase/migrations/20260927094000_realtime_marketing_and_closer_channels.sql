-- Migration: 20260927094000_realtime_marketing_and_closer_channels.sql
-- Description: Ensure customer_leads, client_closers, lead_forms, client_marketers, and orders
-- are all added to the supabase_realtime publication for live socket streaming.

DO $$
DECLARE
    tbl text;
    tables text[] := ARRAY[
        'orders',
        'customer_leads',
        'lead_forms',
        'client_closers',
        'client_marketers'
    ];
BEGIN
    FOREACH tbl IN ARRAY tables LOOP
        IF NOT EXISTS (
            SELECT 1 FROM pg_publication_tables 
            WHERE pubname = 'supabase_realtime' AND tablename = tbl
        ) THEN
            BEGIN
                EXECUTE format('ALTER PUBLICATION supabase_realtime ADD TABLE public.%I;', tbl);
            EXCEPTION WHEN OTHERS THEN
                NULL;
            END;
        END IF;
    END LOOP;
END $$;
