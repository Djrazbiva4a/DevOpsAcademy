-- Additional script to create specific performance problems
-- Run this after the main setup to add more performance issues

-- 1. Create a table with no indexes and lots of data
CREATE TABLE IF NOT EXISTS product_reviews (
    id SERIAL PRIMARY KEY,
    product_id INTEGER,
    customer_id INTEGER,
    rating INTEGER,
    review_text TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Insert lots of review data (no indexes = slow queries)
INSERT INTO product_reviews (product_id, customer_id, rating, review_text)
SELECT 
    (random() * 50000 + 1)::int as product_id,
    (random() * 1000 + 1)::int as customer_id,
    (random() * 5 + 1)::int as rating,
    'Review text for product ' || generate_series as review_text
FROM generate_series(1, 100000);

-- 2. Create a table with inefficient data types
CREATE TABLE IF NOT EXISTS customer_sessions (
    id SERIAL PRIMARY KEY,
    customer_id INTEGER,
    session_data TEXT,  -- Storing large text instead of JSONB
    ip_address VARCHAR(255),
    user_agent TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Insert session data
INSERT INTO customer_sessions (customer_id, session_data, ip_address, user_agent)
SELECT 
    (random() * 1000 + 1)::int as customer_id,
    repeat('session data ', 100) as session_data,  -- Large text
    '192.168.1.' || (random() * 255)::int as ip_address,
    'Mozilla/5.0...' as user_agent
FROM generate_series(1, 50000);

-- 3. Create a table with lots of updates (causes bloat)
CREATE TABLE IF NOT EXISTS inventory_log (
    id SERIAL PRIMARY KEY,
    product_id INTEGER,
    old_quantity INTEGER,
    new_quantity INTEGER,
    change_reason TEXT,
    changed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Simulate frequent inventory updates
DO $$
DECLARE
    i INTEGER;
BEGIN
    FOR i IN 1..20000 LOOP
        INSERT INTO inventory_log (product_id, old_quantity, new_quantity, change_reason)
        VALUES (
            (random() * 50000 + 1)::int,
            (random() * 100)::int,
            (random() * 100)::int,
            'Stock adjustment'
        );
        
        -- Update the same records multiple times (creates bloat)
        IF i % 100 = 0 THEN
            UPDATE inventory_log 
            SET change_reason = 'Updated: ' || change_reason
            WHERE id IN (SELECT id FROM inventory_log ORDER BY random() LIMIT 100);
        END IF;
    END LOOP;
END $$;

-- 4. Create a view that does expensive operations
CREATE OR REPLACE VIEW expensive_customer_summary AS
SELECT 
    c.id,
    c.email,
    COUNT(DISTINCT o.id) as total_orders,
    SUM(o.total_amount) as lifetime_value,
    AVG(oi.quantity) as avg_items_per_order,
    MAX(o.order_date) as last_order_date
FROM customers c
LEFT JOIN orders o ON c.id = o.customer_id
LEFT JOIN order_items oi ON o.id = oi.order_id
GROUP BY c.id, c.email;
-- This view will be slow without proper indexes!

-- 5. Create a function that does full table scans
CREATE OR REPLACE FUNCTION find_customer_by_email(search_email VARCHAR)
RETURNS TABLE(id INTEGER, email VARCHAR, first_name VARCHAR, last_name VARCHAR) AS $$
BEGIN
    -- This will do a full table scan without an index on email!
    RETURN QUERY
    SELECT c.id, c.email, c.first_name, c.last_name
    FROM customers c
    WHERE c.email = search_email;
END;
$$ LANGUAGE plpgsql;

-- 6. Create some long-running transactions (simulate locking issues)
-- Note: This would need to be run in a separate session to actually cause locks
-- But we can create the scenario

COMMENT ON TABLE products IS 'WARNING: This table has 50,000+ rows with NO indexes on name or category_id. Queries will be slow!';
COMMENT ON TABLE order_items IS 'WARNING: This table has NO indexes on order_id or product_id. JOINs will be slow!';
COMMENT ON TABLE product_reviews IS 'WARNING: This table has 100,000+ rows with NO indexes. Queries will be very slow!';

-- Summary of performance problems created:
SELECT 
    'Performance Problems Created:' as summary,
    '1. product_reviews table: 100K rows, no indexes' as problem1,
    '2. customer_sessions table: 50K rows, inefficient TEXT storage' as problem2,
    '3. inventory_log table: 20K rows with heavy update bloat' as problem3,
    '4. expensive_customer_summary view: Slow aggregations' as problem4,
    '5. find_customer_by_email function: Full table scan' as problem5;

