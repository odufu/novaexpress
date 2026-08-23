-- ==============================================================================
-- NOVAEXPRESS LOGISTICS: SUPABASE STORAGE BUCKETS & UPLOAD SECURITY RESTRICTIONS
-- ==============================================================================

-- 1. Create and configure 'avatars' bucket with 5MB limit and image restrictions
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
    'avatars',
    'avatars',
    true,
    5242880, -- 5 MB
    ARRAY['image/jpeg', 'image/png', 'image/webp', 'image/gif']
)
ON CONFLICT (id) DO UPDATE SET
    public = true,
    file_size_limit = 5242880,
    allowed_mime_types = ARRAY['image/jpeg', 'image/png', 'image/webp', 'image/gif'];

-- 2. Create and configure 'remittance-proofs' bucket
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
    'remittance-proofs',
    'remittance-proofs',
    true,
    10485760, -- 10 MB
    ARRAY['image/jpeg', 'image/png', 'image/webp', 'application/pdf']
)
ON CONFLICT (id) DO UPDATE SET
    public = true,
    file_size_limit = 10485760,
    allowed_mime_types = ARRAY['image/jpeg', 'image/png', 'image/webp', 'application/pdf'];

-- 3. Create and configure 'pod-proofs' bucket
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
    'pod-proofs',
    'pod-proofs',
    true,
    10485760, -- 10 MB
    ARRAY['image/jpeg', 'image/png', 'image/webp']
)
ON CONFLICT (id) DO UPDATE SET
    public = true,
    file_size_limit = 10485760,
    allowed_mime_types = ARRAY['image/jpeg', 'image/png', 'image/webp'];

-- ==============================================================================
-- STORAGE RLS SECURITY POLICIES
-- ==============================================================================

-- Public Read Policy for avatars
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies 
        WHERE tablename = 'objects' AND policyname = 'Public Access for Avatars'
    ) THEN
        CREATE POLICY "Public Access for Avatars"
        ON storage.objects FOR SELECT
        USING (bucket_id = 'avatars');
    END IF;
END $$;

-- Upload Policy for avatars
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies 
        WHERE tablename = 'objects' AND policyname = 'Allow Authenticated or Service Role Avatar Uploads'
    ) THEN
        CREATE POLICY "Allow Authenticated or Service Role Avatar Uploads"
        ON storage.objects FOR INSERT
        WITH CHECK (bucket_id = 'avatars');
    END IF;
END $$;
