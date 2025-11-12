-- SQL queries to find any remaining references to available_protein_options

-- 1. Check all functions for references to available_protein_options
SELECT 
    n.nspname as schema_name,
    p.proname as function_name,
    pg_get_functiondef(p.oid) as function_definition
FROM pg_proc p
JOIN pg_namespace n ON p.pronamespace = n.oid
WHERE pg_get_functiondef(p.oid) ILIKE '%available_protein_options%'
AND n.nspname = 'public';

-- 2. Check all views for references to available_protein_options  
SELECT 
    schemaname,
    viewname,
    definition
FROM pg_views 
WHERE definition ILIKE '%available_protein_options%'
AND schemaname = 'public';

-- 3. Check all triggers for references to available_protein_options
SELECT 
    t.tgname as trigger_name,
    c.relname as table_name,
    pg_get_triggerdef(t.oid) as trigger_definition
FROM pg_trigger t
JOIN pg_class c ON t.tgrelid = c.oid
JOIN pg_namespace n ON c.relnamespace = n.oid
WHERE pg_get_triggerdef(t.oid) ILIKE '%available_protein_options%'
AND n.nspname = 'public';

-- 4. Check for any materialized views
SELECT 
    schemaname,
    matviewname,
    definition
FROM pg_matviews 
WHERE definition ILIKE '%available_protein_options%'
AND schemaname = 'public';

-- 5. Check all stored procedures (different from functions)
SELECT 
    n.nspname as schema_name,
    p.proname as procedure_name,
    p.prokind,
    pg_get_functiondef(p.oid) as definition
FROM pg_proc p
JOIN pg_namespace n ON p.pronamespace = n.oid
WHERE pg_get_functiondef(p.oid) ILIKE '%available_protein_options%'
AND n.nspname = 'public'
AND p.prokind = 'p';  -- procedures only

-- 6. Check for any rules that might reference the column
SELECT 
    schemaname,
    tablename,
    rulename,
    definition
FROM pg_rules
WHERE definition ILIKE '%available_protein_options%'
AND schemaname = 'public';

-- 7. Check if the column still exists in the dishes table (it should be gone)
SELECT 
    column_name,
    data_type,
    is_nullable
FROM information_schema.columns 
WHERE table_schema = 'public' 
AND table_name = 'dishes'
AND column_name = 'available_protein_options';

-- 8. Check for any indexes that might still reference the old column
SELECT 
    i.relname as index_name,
    t.relname as table_name,
    pg_get_indexdef(i.oid) as index_definition
FROM pg_class i
JOIN pg_index ix ON i.oid = ix.indexrelid
JOIN pg_class t ON ix.indrelid = t.oid
JOIN pg_namespace n ON t.relnamespace = n.oid
WHERE pg_get_indexdef(i.oid) ILIKE '%available_protein_options%'
AND n.nspname = 'public';

-- 9. Search for any cached query plans or prepared statements
-- (This might not show much in Supabase but worth checking)
SELECT 
    query,
    calls,
    mean_exec_time
FROM pg_stat_statements 
WHERE query ILIKE '%available_protein_options%'
LIMIT 10;
