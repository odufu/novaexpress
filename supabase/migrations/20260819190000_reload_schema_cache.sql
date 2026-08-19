-- Reload PostgREST Schema Cache
SELECT pg_notify('pgrst', 'reload schema');
