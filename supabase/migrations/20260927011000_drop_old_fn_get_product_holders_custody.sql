-- Drop old conflicting 3-parameter overload of fn_get_product_holders_custody
DROP FUNCTION IF EXISTS public.fn_get_product_holders_custody(UUID, TIMESTAMP WITH TIME ZONE, TIMESTAMP WITH TIME ZONE);
DROP FUNCTION IF EXISTS public.fn_get_product_holders_custody(UUID, TIMESTAMP, TIMESTAMP);
