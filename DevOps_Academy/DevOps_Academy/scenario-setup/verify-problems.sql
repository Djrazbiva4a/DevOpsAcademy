-- Script to verify all the problems exist
-- Run this to see what issues need to be fixed

\echo '=========================================='
\echo 'PROBLEM VERIFICATION REPORT'
\echo '=========================================='
\echo ''

\echo '1. CHECKING FOR MISSING INDEXES...'
\echo ''

-- Check for missing indexes on frequently queried columns
SELECT 
    'Missing Indexes:' as check_type,
    'products.name' as column_name,
    'Frequently searched, no index!' as issue
WHERE NOT EXISTS (
    SELECT 1 FROM pg_indexes 
    WHERE tablename = 'products' AND indexname LIKE '%name%'
)
UNION ALL
SELECT 
    'Missing Indexes:',
    'products.category_id',
    'Frequently filtered, no index!'
WHERE NOT EXISTS (
    SELECT 1 FROM pg_indexes 
    WHERE tablename = 'products' AND indexname LIKE '%category%'
)
UNION ALL
SELECT 
    'Missing Indexes:',
    'order_items.order_id',
    'Frequently joined, no index!'
WHERE NOT EXISTS (
    SELECT 1 FROM pg_indexes 
    WHERE tablename = 'order_items' AND indexname LIKE '%order_id%'
)
UNION ALL
SELECT 
    'Missing Indexes:',
    'order_items.product_id',
    'Frequently joined, no index!'
WHERE NOT EXISTS (
    SELECT 1 FROM pg_indexes 
    WHERE tablename = 'order_items' AND indexname LIKE '%product_id%'
)
UNION ALL
SELECT 
    'Missing Indexes:',
    'customers.email',
    'Frequently searched, no index!'
WHERE NOT EXISTS (
    SELECT 1 FROM pg_indexes 
    WHERE tablename = 'customers' AND indexname LIKE '%email%'
);

\echo ''
\echo '2. CHECKING FOR DATA INTEGRITY ISSUES...'
\echo ''

-- Duplicate emails
SELECT 
    'Data Integrity:',
    'Duplicate customer emails',
    COUNT(*)::text || ' duplicate email addresses found'
FROM (
    SELECT email, COUNT(*) 
    FROM customers 
    GROUP BY email 
    HAVING COUNT(*) > 1
) duplicates;

-- Negative stock
SELECT 
    'Data Integrity:',
    'Negative stock quantities',
    COUNT(*)::text || ' products with negative stock'
FROM products 
WHERE stock_quantity < 0;

-- Orphaned order_items
SELECT 
    'Data Integrity:',
    'Orphaned order_items',
    COUNT(*)::text || ' order_items reference non-existent orders'
FROM order_items oi
LEFT JOIN orders o ON oi.order_id = o.id
WHERE o.id IS NULL;

-- Invalid product_ids in order_items
SELECT 
    'Data Integrity:',
    'Invalid product_ids',
    COUNT(*)::text || ' order_items reference non-existent products'
FROM order_items oi
LEFT JOIN products p ON oi.product_id = p.id
WHERE p.id IS NULL;

-- Orders with zero/negative totals
SELECT 
    'Data Integrity:',
    'Invalid order totals',
    COUNT(*)::text || ' orders with zero or negative totals'
FROM orders
WHERE total_amount <= 0;

-- Products with NULL category_id
SELECT 
    'Data Integrity:',
    'NULL category_ids',
    COUNT(*)::text || ' products with NULL category_id'
FROM products
WHERE category_id IS NULL;

\echo ''
\echo '3. CHECKING FOR MAINTENANCE ISSUES...'
\echo ''

-- Table bloat (dead tuples)
SELECT 
    'Maintenance:',
    tablename,
    n_dead_tup::text || ' dead tuples (' || 
    ROUND(n_dead_tup * 100.0 / NULLIF(n_live_tup + n_dead_tup, 0), 1) || '%)'
FROM pg_stat_user_tables
WHERE schemaname = 'public' 
  AND n_dead_tup > 100
ORDER BY n_dead_tup DESC;

-- Outdated statistics
SELECT 
    'Maintenance:',
    tablename,
    'Last analyzed: ' || COALESCE(last_analyze::text, last_autoanalyze::text, 'NEVER')
FROM pg_stat_user_tables
WHERE schemaname = 'public'
  AND (last_analyze IS NULL AND last_autoanalyze IS NULL 
       OR last_analyze < NOW() - INTERVAL '7 days'
       OR last_autoanalyze < NOW() - INTERVAL '7 days')
ORDER BY tablename;

\echo ''
\echo '4. CHECKING FOR MISSING CONSTRAINTS...'
\echo ''

-- Check for missing UNIQUE constraint on customers.email
SELECT 
    'Constraints:',
    'customers.email',
    'Missing UNIQUE constraint - allows duplicates!'
WHERE NOT EXISTS (
    SELECT 1 FROM pg_constraint 
    WHERE conrelid = 'customers'::regclass 
    AND contype = 'u' 
    AND conkey::text LIKE '%2%'  -- email is typically column 2
);

-- Check for missing UNIQUE constraint on products.sku
SELECT 
    'Constraints:',
    'products.sku',
    'Missing UNIQUE constraint!'
WHERE NOT EXISTS (
    SELECT 1 FROM pg_constraint 
    WHERE conrelid = 'products'::regclass 
    AND contype = 'u'
);

-- Check for missing foreign key on order_items.order_id
SELECT 
    'Constraints:',
    'order_items.order_id',
    'Missing FOREIGN KEY constraint!'
WHERE NOT EXISTS (
    SELECT 1 FROM pg_constraint 
    WHERE conrelid = 'order_items'::regclass 
    AND contype = 'f'
    AND conkey::text LIKE '%2%'  -- order_id is typically column 2
);

-- Check for missing foreign key on order_items.product_id
SELECT 
    'Constraints:',
    'order_items.product_id',
    'Missing FOREIGN KEY constraint!'
WHERE NOT EXISTS (
    SELECT 1 FROM pg_constraint 
    WHERE conrelid = 'order_items'::regclass 
    AND contype = 'f'
    AND conkey::text LIKE '%3%'  -- product_id is typically column 3
);

\echo ''
\echo '5. PERFORMANCE TEST QUERIES...'
\echo ''
\echo 'Run these queries and check execution time:'
\echo ''
\echo '-- This should be SLOW (no index on name):'
\echo 'EXPLAIN ANALYZE SELECT * FROM products WHERE name LIKE ''%laptop%'';'
\echo ''
\echo '-- This should be SLOW (no index on category_id):'
\echo 'EXPLAIN ANALYZE SELECT * FROM products WHERE category_id = 2;'
\echo ''
\echo '-- This should be SLOW (no index on order_id):'
\echo 'EXPLAIN ANALYZE SELECT * FROM order_items WHERE order_id = 5000;'
\echo ''
\echo '=========================================='
\echo 'END OF VERIFICATION REPORT'
\echo '=========================================='

