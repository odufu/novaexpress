-- ============================================================================
-- MIGRATION: 20261026100000_sync_order_activities_warehouses_and_chat_attachments.sql
-- DESCRIPTION: Parity sync for order_activities audit fields, warehouse linkages,
--              and chat-attachments storage bucket.
-- ============================================================================

-- 1. Ensure order_activities has audit author and detailed notes
ALTER TABLE public.order_activities 
    ADD COLUMN IF NOT EXISTS user_id UUID REFERENCES public.users(id) ON DELETE SET NULL,
    ADD COLUMN IF NOT EXISTS notes TEXT;

-- 2. Ensure warehouses has location city, DC linkage, and updated timestamp
ALTER TABLE public.warehouses
    ADD COLUMN IF NOT EXISTS location_city TEXT,
    ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT NOW(),
    ADD COLUMN IF NOT EXISTS distribution_center_id UUID REFERENCES public.distribution_centers(id) ON DELETE CASCADE;

-- 3. Storage bucket policies for chat attachments (voice notes & files)
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
    'chat-attachments',
    'chat-attachments',
    true,
    52428800,
    ARRAY['image/jpeg', 'image/png', 'image/webp', 'image/gif', 'application/pdf', 'audio/m4a', 'audio/aac', 'audio/mp4', 'audio/mpeg', 'audio/webm', 'audio/wav', 'audio/ogg', 'text/plain', 'application/msword', 'application/vnd.openxmlformats-officedocument.wordprocessingml.document']
)
ON CONFLICT (id) DO UPDATE SET
    public = true,
    file_size_limit = 52428800;

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'objects' AND policyname = 'Public Access for Chat Attachments') THEN
        CREATE POLICY "Public Access for Chat Attachments" ON storage.objects
            FOR SELECT USING (bucket_id = 'chat-attachments');
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'objects' AND policyname = 'Allow Uploads for Chat Attachments') THEN
        CREATE POLICY "Allow Uploads for Chat Attachments" ON storage.objects
            FOR INSERT WITH CHECK (bucket_id = 'chat-attachments');
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'objects' AND policyname = 'Allow Updates for Chat Attachments') THEN
        CREATE POLICY "Allow Updates for Chat Attachments" ON storage.objects
            FOR UPDATE USING (bucket_id = 'chat-attachments');
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'objects' AND policyname = 'Allow Deletes for Chat Attachments') THEN
        CREATE POLICY "Allow Deletes for Chat Attachments" ON storage.objects
            FOR DELETE USING (bucket_id = 'chat-attachments');
    END IF;
END $$;
