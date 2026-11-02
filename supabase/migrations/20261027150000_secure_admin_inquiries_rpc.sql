-- Secure RPC functions for Website Admin Console
-- Allows legitimate admin console with passkey to view, update, and manage quote inquiries
-- while preventing arbitrary public visitors from snooping on customer leads.

CREATE OR REPLACE FUNCTION public.get_admin_inquiries(admin_passkey text)
RETURNS SETOF public.website_inquiries
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF admin_passkey = 'NovaAdmin2026!' THEN
    RETURN QUERY 
    SELECT * FROM public.website_inquiries 
    ORDER BY created_at DESC;
  ELSE
    RAISE EXCEPTION 'Unauthorized: Invalid Admin Passkey';
  END IF;
END;
$$;

CREATE OR REPLACE FUNCTION public.update_admin_inquiry_status(admin_passkey text, inquiry_id uuid, new_status text)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF admin_passkey = 'NovaAdmin2026!' THEN
    UPDATE public.website_inquiries 
    SET status = new_status 
    WHERE id = inquiry_id;
  ELSE
    RAISE EXCEPTION 'Unauthorized: Invalid Admin Passkey';
  END IF;
END;
$$;

CREATE OR REPLACE FUNCTION public.delete_admin_inquiry(admin_passkey text, inquiry_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF admin_passkey = 'NovaAdmin2026!' THEN
    DELETE FROM public.website_inquiries 
    WHERE id = inquiry_id;
  ELSE
    RAISE EXCEPTION 'Unauthorized: Invalid Admin Passkey';
  END IF;
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_admin_inquiries(text) TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.update_admin_inquiry_status(text, uuid, text) TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.delete_admin_inquiry(text, uuid) TO anon, authenticated, service_role;
