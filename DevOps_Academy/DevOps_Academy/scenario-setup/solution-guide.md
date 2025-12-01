# TechShop Database - Solution Guide

This guide shows how to fix all the problems in the TechShop database scenario.

## ⚠️ Important

**Try to fix the problems yourself first!** Only use this guide to:
- Verify your solutions
- Get hints if you're stuck
- Understand best practices

---

## Solution 1: Fix Missing Indexes

### Problem
Queries are slow because frequently queried columns don't have indexes.

### Solution

```sql
-- Create indexes on frequently queried columns
CREATE INDEX CONCURRENTLY idx_products_name ON products(name);
CREATE INDEX CONCURRENTLY idx_products_category ON products(category_id);
CREATE INDEX CONCURRENTLY idx_order_items_order_id ON order_items(order_id);
CREATE INDEX CONCURRENTLY idx_order_items_product_id ON order_items(product_id);
CREATE INDEX CONCURRENTLY idx_orders_customer_id ON orders(customer_id);
CREATE INDEX CONCURRENTLY idx_orders_status ON orders(status);
CREATE INDEX CONCURRENTLY idx_orders_date ON orders(order_date);
CREATE INDEX CONCURRENTLY idx_customers_email ON customers(email);

-- If product_reviews table exists
CREATE INDEX CONCURRENTLY idx_product_reviews_product_id ON product_reviews(product_id);
CREATE INDEX CONCURRENTLY idx_product_reviews_customer_id ON product_reviews(customer_id);
```

**Why CONCURRENTLY?** It doesn't lock the table, so you can create indexes on production without downtime.

**Verify:**
```sql
-- Check indexes were created
SELECT tablename, indexname 
FROM pg_indexes 
WHERE schemaname = 'public' 
ORDER BY tablename, indexname;

-- Test query performance
EXPLAIN ANALYZE SELECT * FROM products WHERE name LIKE '%laptop%';
-- Should show "Index Scan" instead of "Seq Scan"
```

---

## Solution 2: Fix Data Integrity Issues

### Problem 2.1: Duplicate Customer Emails

```sql
-- First, identify duplicates
SELECT email, COUNT(*) 
FROM customers 
GROUP BY email 
HAVING COUNT(*) > 1;

-- Option 1: Keep the oldest record, update others
WITH duplicates AS (
    SELECT email, MIN(id) as keep_id
    FROM customers
    GROUP BY email
    HAVING COUNT(*) > 1
)
UPDATE customers c
SET email = c.email || '_duplicate_' || c.id
FROM duplicates d
WHERE c.email = d.email AND c.id != d.keep_id;

-- Option 2: Delete duplicates (if safe to do so)
-- DELETE FROM customers 
-- WHERE id NOT IN (
--     SELECT MIN(id) FROM customers GROUP BY email
-- );

-- Add UNIQUE constraint to prevent future duplicates
ALTER TABLE customers ADD CONSTRAINT customers_email_unique UNIQUE (email);
```

### Problem 2.2: Negative Stock Quantities

```sql
-- Check negative stock
SELECT id, name, stock_quantity 
FROM products 
WHERE stock_quantity < 0;

-- Fix: Set to 0 (or investigate why they're negative)
UPDATE products 
SET stock_quantity = 0 
WHERE stock_quantity < 0;

-- Add CHECK constraint to prevent future issues
ALTER TABLE products 
ADD CONSTRAINT products_stock_positive 
CHECK (stock_quantity >= 0);
```

### Problem 2.3: Orphaned Order Items

```sql
-- Find orphaned order_items
SELECT oi.* 
FROM order_items oi
LEFT JOIN orders o ON oi.order_id = o.id
WHERE o.id IS NULL;

-- Option 1: Delete orphaned records (if confirmed safe)
DELETE FROM order_items 
WHERE order_id NOT IN (SELECT id FROM orders);

-- Option 2: Investigate and potentially restore missing orders
-- (Would require backup/restore if orders were accidentally deleted)

-- Add foreign key constraint to prevent future issues
ALTER TABLE order_items 
ADD CONSTRAINT order_items_order_id_fkey 
FOREIGN KEY (order_id) REFERENCES orders(id);
```

### Problem 2.4: Invalid Product IDs in Order Items

```sql
-- Find invalid product_ids
SELECT oi.* 
FROM order_items oi
LEFT JOIN products p ON oi.product_id = p.id
WHERE p.id IS NULL;

-- Delete invalid records (or update to valid product_id if known)
DELETE FROM order_items 
WHERE product_id NOT IN (SELECT id FROM products);

-- Add foreign key constraint
ALTER TABLE order_items 
ADD CONSTRAINT order_items_product_id_fkey 
FOREIGN KEY (product_id) REFERENCES products(id);
```

### Problem 2.5: Orders with Zero/Negative Totals

```sql
-- Find invalid totals
SELECT id, customer_id, total_amount, order_date
FROM orders
WHERE total_amount <= 0;

-- Option 1: Recalculate from order_items
UPDATE orders o
SET total_amount = COALESCE((
    SELECT SUM(quantity * price)
    FROM order_items
    WHERE order_id = o.id
), 0)
WHERE o.total_amount <= 0;

-- Option 2: Delete orders with zero totals (if they have no items)
DELETE FROM orders 
WHERE total_amount = 0 
AND id NOT IN (SELECT DISTINCT order_id FROM order_items);

-- Add CHECK constraint
ALTER TABLE orders 
ADD CONSTRAINT orders_total_positive 
CHECK (total_amount > 0);
```

### Problem 2.6: Products with NULL Category ID

```sql
-- Find products without categories
SELECT id, name, category_id 
FROM products 
WHERE category_id IS NULL;

-- Option 1: Set to a default category (e.g., "Uncategorized")
-- First, create or find an "Uncategorized" category
INSERT INTO categories (name, parent_id) 
VALUES ('Uncategorized', NULL) 
ON CONFLICT DO NOTHING;

UPDATE products 
SET category_id = (SELECT id FROM categories WHERE name = 'Uncategorized')
WHERE category_id IS NULL;

-- Option 2: Add foreign key constraint (if NULL should be allowed)
ALTER TABLE products 
ADD CONSTRAINT products_category_id_fkey 
FOREIGN KEY (category_id) REFERENCES categories(id);
```

---

## Solution 3: Fix Missing Constraints

### Add Missing UNIQUE Constraints

```sql
-- Email should be unique
ALTER TABLE customers 
ADD CONSTRAINT customers_email_unique UNIQUE (email);

-- SKU should be unique
ALTER TABLE products 
ADD CONSTRAINT products_sku_unique UNIQUE (sku);
```

### Add Missing Foreign Key Constraints

```sql
-- Order items should reference valid orders
ALTER TABLE order_items 
ADD CONSTRAINT order_items_order_id_fkey 
FOREIGN KEY (order_id) REFERENCES orders(id) ON DELETE CASCADE;

-- Order items should reference valid products
ALTER TABLE order_items 
ADD CONSTRAINT order_items_product_id_fkey 
FOREIGN KEY (product_id) REFERENCES products(id);

-- Products should reference valid categories
ALTER TABLE products 
ADD CONSTRAINT products_category_id_fkey 
FOREIGN KEY (category_id) REFERENCES categories(id);
```

### Add Missing CHECK Constraints

```sql
-- Stock quantity should be non-negative
ALTER TABLE products 
ADD CONSTRAINT products_stock_positive 
CHECK (stock_quantity >= 0);

-- Order total should be positive
ALTER TABLE orders 
ADD CONSTRAINT orders_total_positive 
CHECK (total_amount > 0);

-- Rating should be between 1 and 5 (if product_reviews exists)
ALTER TABLE product_reviews 
ADD CONSTRAINT product_reviews_rating_range 
CHECK (rating >= 1 AND rating <= 5);
```

---

## Solution 4: Fix Maintenance Issues

### Update Statistics

```sql
-- Update statistics for all tables
ANALYZE;

-- Or update specific tables
ANALYZE products;
ANALYZE orders;
ANALYZE order_items;
ANALYZE customers;
```

### Clean Up Dead Tuples (VACUUM)

```sql
-- Vacuum all tables
VACUUM ANALYZE;

-- Or vacuum specific tables
VACUUM ANALYZE products;
VACUUM ANALYZE orders;
VACUUM ANALYZE order_items;

-- For heavily bloated tables, use VACUUM FULL (locks table!)
-- VACUUM FULL products;  -- Use with caution!
```

### Verify Maintenance

```sql
-- Check dead tuples are cleaned up
SELECT 
    tablename,
    n_dead_tup,
    n_live_tup,
    ROUND(n_dead_tup * 100.0 / NULLIF(n_live_tup + n_dead_tup, 0), 2) AS dead_pct,
    last_vacuum,
    last_autovacuum,
    last_analyze,
    last_autoanalyze
FROM pg_stat_user_tables
WHERE schemaname = 'public'
ORDER BY n_dead_tup DESC;
```

---

## Solution 5: Verify All Fixes

### Comprehensive Verification Query

```sql
-- Create a verification report
WITH fixes AS (
    SELECT 
        'Indexes' as category,
        COUNT(*) as fixed_count,
        'Indexes created on frequently queried columns' as status
    FROM pg_indexes
    WHERE schemaname = 'public'
    AND (
        indexname LIKE '%name%' OR
        indexname LIKE '%category%' OR
        indexname LIKE '%order_id%' OR
        indexname LIKE '%product_id%' OR
        indexname LIKE '%email%'
    )
),
integrity AS (
    SELECT 
        'Data Integrity' as category,
        0 as fixed_count,
        CASE 
            WHEN (SELECT COUNT(*) FROM (
                SELECT email FROM customers GROUP BY email HAVING COUNT(*) > 1
            ) d) = 0 
            AND (SELECT COUNT(*) FROM products WHERE stock_quantity < 0) = 0
            AND (SELECT COUNT(*) FROM order_items oi 
                 LEFT JOIN orders o ON oi.order_id = o.id WHERE o.id IS NULL) = 0
            THEN 'All data integrity issues fixed ✓'
            ELSE 'Some data integrity issues remain ✗'
        END as status
),
constraints AS (
    SELECT 
        'Constraints' as category,
        COUNT(*) as fixed_count,
        'Constraints added' as status
    FROM pg_constraint
    WHERE conrelid IN (
        'customers'::regclass,
        'products'::regclass,
        'orders'::regclass,
        'order_items'::regclass
    )
    AND contype IN ('u', 'f', 'c')
),
maintenance AS (
    SELECT 
        'Maintenance' as category,
        COUNT(*) as fixed_count,
        CASE 
            WHEN (SELECT SUM(n_dead_tup) FROM pg_stat_user_tables 
                  WHERE schemaname = 'public') < 1000
            THEN 'Dead tuples cleaned up ✓'
            ELSE 'Dead tuples still present'
        END as status
    FROM pg_stat_user_tables
    WHERE schemaname = 'public'
    AND n_dead_tup < 100
)
SELECT * FROM fixes
UNION ALL SELECT * FROM integrity
UNION ALL SELECT * FROM constraints
UNION ALL SELECT * FROM maintenance;
```

---

## Complete Fix Script

Here's a complete script that fixes all issues:

```sql
-- ============================================
-- COMPLETE FIX SCRIPT
-- ============================================

BEGIN;

-- 1. Fix data integrity issues first
-- Remove duplicate emails
WITH duplicates AS (
    SELECT email, MIN(id) as keep_id
    FROM customers
    GROUP BY email
    HAVING COUNT(*) > 1
)
UPDATE customers c
SET email = c.email || '_duplicate_' || c.id
FROM duplicates d
WHERE c.email = d.email AND c.id != d.keep_id;

-- Fix negative stock
UPDATE products SET stock_quantity = 0 WHERE stock_quantity < 0;

-- Remove orphaned order_items
DELETE FROM order_items WHERE order_id NOT IN (SELECT id FROM orders);
DELETE FROM order_items WHERE product_id NOT IN (SELECT id FROM products);

-- Fix NULL categories
INSERT INTO categories (name, parent_id) 
VALUES ('Uncategorized', NULL) 
ON CONFLICT DO NOTHING;

UPDATE products 
SET category_id = (SELECT id FROM categories WHERE name = 'Uncategorized')
WHERE category_id IS NULL;

-- Fix invalid order totals
UPDATE orders o
SET total_amount = COALESCE((
    SELECT SUM(quantity * price)
    FROM order_items
    WHERE order_id = o.id
), 0)
WHERE o.total_amount <= 0;

-- 2. Add constraints
ALTER TABLE customers ADD CONSTRAINT customers_email_unique UNIQUE (email);
ALTER TABLE products ADD CONSTRAINT products_sku_unique UNIQUE (sku);
ALTER TABLE products ADD CONSTRAINT products_stock_positive CHECK (stock_quantity >= 0);
ALTER TABLE orders ADD CONSTRAINT orders_total_positive CHECK (total_amount > 0);
ALTER TABLE order_items ADD CONSTRAINT order_items_order_id_fkey 
    FOREIGN KEY (order_id) REFERENCES orders(id) ON DELETE CASCADE;
ALTER TABLE order_items ADD CONSTRAINT order_items_product_id_fkey 
    FOREIGN KEY (product_id) REFERENCES products(id);
ALTER TABLE products ADD CONSTRAINT products_category_id_fkey 
    FOREIGN KEY (category_id) REFERENCES categories(id);

-- 3. Create indexes
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_products_name ON products(name);
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_products_category ON products(category_id);
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_order_items_order_id ON order_items(order_id);
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_order_items_product_id ON order_items(product_id);
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_orders_customer_id ON orders(customer_id);
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_orders_status ON orders(status);
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_customers_email ON customers(email);

-- 4. Run maintenance
ANALYZE;
VACUUM ANALYZE;

COMMIT;

-- Verify fixes
\echo 'Verification:'
SELECT 'Indexes created: ' || COUNT(*)::text 
FROM pg_indexes 
WHERE schemaname = 'public' 
AND (indexname LIKE '%name%' OR indexname LIKE '%category%' 
     OR indexname LIKE '%order_id%' OR indexname LIKE '%email%');

SELECT 'Duplicate emails: ' || COUNT(*)::text 
FROM (SELECT email FROM customers GROUP BY email HAVING COUNT(*) > 1) d;

SELECT 'Negative stock: ' || COUNT(*)::text 
FROM products WHERE stock_quantity < 0;

SELECT 'Orphaned order_items: ' || COUNT(*)::text 
FROM order_items oi 
LEFT JOIN orders o ON oi.order_id = o.id 
WHERE o.id IS NULL;
```

---

## Best Practices Applied

1. **Fix data first, then add constraints** - Prevents constraint violations
2. **Use CONCURRENTLY for indexes** - No downtime
3. **Use transactions** - All-or-nothing approach
4. **Verify after fixes** - Confirm everything worked
5. **Document changes** - Keep track of what was fixed

---

## Performance Improvements Expected

After applying all fixes:
- ✅ Query performance: 10-100x faster on indexed columns
- ✅ Data integrity: No orphaned records, no invalid data
- ✅ Maintenance: Reduced bloat, updated statistics
- ✅ Constraints: Prevent future data quality issues

---

## Next Steps

1. Set up automated maintenance (cron jobs for VACUUM, ANALYZE)
2. Create monitoring queries to catch issues early
3. Document the fixes for your team
4. Set up regular backups
5. Create alerts for data quality issues

Good job fixing the database! 🎉

