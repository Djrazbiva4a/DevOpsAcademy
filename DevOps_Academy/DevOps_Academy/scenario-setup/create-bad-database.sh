#!/bin/bash

# Script to create a database with intentional problems for troubleshooting practice
# This simulates a poorly maintained database with various issues

set -e

echo "=========================================="
echo "Creating TechShop Database with Problems"
echo "=========================================="
echo ""
echo "This script will create a database with intentional issues"
echo "that you'll need to diagnose and fix."
echo ""

# Check if container exists
if ! docker ps -a | grep -q techshop-db; then
    echo "Creating PostgreSQL container..."
    docker run --name techshop-db \
        -e POSTGRES_PASSWORD=techshop123 \
        -e POSTGRES_USER=postgres \
        -e POSTGRES_DB=techshop \
        -p 5433:5432 \
        -d postgres:15
    
    echo "Waiting for PostgreSQL to start..."
    sleep 5
else
    echo "Container exists. Starting it..."
    docker start techshop-db
    sleep 3
fi

echo "Creating database schema..."

# Create schema with intentional issues
docker exec -i techshop-db psql -U postgres -d techshop << 'EOF'

-- Create tables (intentionally missing some indexes and constraints)
CREATE TABLE IF NOT EXISTS customers (
    id SERIAL PRIMARY KEY,
    email VARCHAR(255),  -- Missing UNIQUE constraint!
    first_name VARCHAR(100),
    last_name VARCHAR(100),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS categories (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    parent_id INTEGER REFERENCES categories(id)
);

CREATE TABLE IF NOT EXISTS products (
    id SERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    sku VARCHAR(50),  -- Missing UNIQUE constraint!
    price DECIMAL(10, 2) NOT NULL,
    stock_quantity INTEGER DEFAULT 0,  -- Missing CHECK constraint!
    category_id INTEGER,  -- Missing foreign key constraint!
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS orders (
    id SERIAL PRIMARY KEY,
    customer_id INTEGER REFERENCES customers(id),
    order_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    total_amount DECIMAL(10, 2),
    status VARCHAR(50) DEFAULT 'pending'
);

CREATE TABLE IF NOT EXISTS order_items (
    id SERIAL PRIMARY KEY,
    order_id INTEGER,  -- Missing foreign key constraint!
    product_id INTEGER,  -- Missing foreign key constraint!
    quantity INTEGER NOT NULL,
    price DECIMAL(10, 2) NOT NULL
);

-- Note: Intentionally NOT creating indexes on frequently queried columns
-- This will cause slow queries!

EOF

echo "✓ Schema created (with intentional issues)"
echo ""

# Generate sample data
echo "Generating sample data (this may take a minute)..."

docker exec -i techshop-db psql -U postgres -d techshop << 'EOF'

-- Insert categories
INSERT INTO categories (name, parent_id) VALUES
    ('Electronics', NULL),
    ('Computers', 1),
    ('Phones', 1),
    ('Accessories', 1),
    ('Clothing', NULL),
    ('Books', NULL)
ON CONFLICT DO NOTHING;

-- Insert customers (some with duplicate emails - intentional problem!)
INSERT INTO customers (email, first_name, last_name)
SELECT 
    'customer' || generate_series || '@email.com' as email,
    'First' || generate_series as first_name,
    'Last' || generate_series as last_name
FROM generate_series(1, 1000);

-- Insert duplicate emails (intentional problem!)
INSERT INTO customers (email, first_name, last_name) VALUES
    ('customer1@email.com', 'Duplicate', 'User'),
    ('customer5@email.com', 'Another', 'Duplicate');

-- Insert products (large dataset - 50,000 products for performance testing)
INSERT INTO products (name, sku, price, stock_quantity, category_id)
SELECT 
    'Product ' || generate_series || ' - ' || 
    CASE (random() * 5)::int
        WHEN 0 THEN 'Laptop'
        WHEN 1 THEN 'Phone'
        WHEN 2 THEN 'Tablet'
        WHEN 3 THEN 'Monitor'
        ELSE 'Keyboard'
    END as name,
    'SKU-' || LPAD(generate_series::text, 8, '0') as sku,
    (random() * 1000 + 10)::decimal(10, 2) as price,
    (random() * 100)::int as stock_quantity,
    CASE (random() * 5)::int
        WHEN 0 THEN 2  -- Computers
        WHEN 1 THEN 3  -- Phones
        WHEN 2 THEN 2  -- Computers
        WHEN 3 THEN 4  -- Accessories
        ELSE 4
    END as category_id
FROM generate_series(1, 50000);

-- Insert some products with negative stock (intentional problem!)
UPDATE products 
SET stock_quantity = -10 
WHERE id IN (SELECT id FROM products ORDER BY random() LIMIT 50);

-- Insert some products with NULL category_id (orphaned - intentional problem!)
UPDATE products 
SET category_id = NULL 
WHERE id IN (SELECT id FROM products ORDER BY random() LIMIT 100);

-- Insert orders
INSERT INTO orders (customer_id, order_date, total_amount, status)
SELECT 
    (random() * 1000 + 1)::int as customer_id,
    CURRENT_TIMESTAMP - (random() * 365 || ' days')::interval as order_date,
    (random() * 500 + 10)::decimal(10, 2) as total_amount,
    CASE (random() * 4)::int
        WHEN 0 THEN 'pending'
        WHEN 1 THEN 'completed'
        WHEN 2 THEN 'shipped'
        ELSE 'cancelled'
    END as status
FROM generate_series(1, 10000);

-- Insert order_items
INSERT INTO order_items (order_id, product_id, quantity, price)
SELECT 
    (random() * 10000 + 1)::int as order_id,
    (random() * 50000 + 1)::int as product_id,
    (random() * 5 + 1)::int as quantity,
    (random() * 200 + 10)::decimal(10, 2) as price
FROM generate_series(1, 30000);

-- Insert some orphaned order_items (order_id doesn't exist - intentional problem!)
INSERT INTO order_items (order_id, product_id, quantity, price)
SELECT 
    99999 + generate_series as order_id,  -- Non-existent order IDs
    (random() * 50000 + 1)::int as product_id,
    (random() * 5 + 1)::int as quantity,
    (random() * 200 + 10)::decimal(10, 2) as price
FROM generate_series(1, 15);

-- Insert some order_items with invalid product_id (intentional problem!)
INSERT INTO order_items (order_id, product_id, quantity, price)
SELECT 
    (random() * 10000 + 1)::int as order_id,
    99999 + generate_series as product_id,  -- Non-existent product IDs
    (random() * 5 + 1)::int as quantity,
    (random() * 200 + 10)::decimal(10, 2) as price
FROM generate_series(1, 10);

-- Create some orders with zero or negative totals (intentional problem!)
UPDATE orders 
SET total_amount = 0 
WHERE id IN (SELECT id FROM orders ORDER BY random() LIMIT 20);

UPDATE orders 
SET total_amount = -50 
WHERE id IN (SELECT id FROM orders ORDER BY random() LIMIT 5);

-- Delete some orders but leave order_items (creates orphaned records)
DELETE FROM orders 
WHERE id IN (SELECT id FROM orders ORDER BY random() LIMIT 25);

EOF

echo "✓ Sample data generated"
echo ""

# Create problems: outdated statistics and bloat
echo "Creating maintenance issues..."

docker exec -i techshop-db psql -U postgres -d techshop << 'EOF'

-- Update and delete some data to create dead tuples (bloat)
UPDATE products 
SET price = price * 1.1 
WHERE id IN (SELECT id FROM products ORDER BY random() LIMIT 10000);

DELETE FROM products 
WHERE id IN (SELECT id FROM products WHERE id > 40000 ORDER BY random() LIMIT 5000);

-- Update orders to create more dead tuples
UPDATE orders 
SET status = 'completed' 
WHERE status = 'pending' AND id IN (
    SELECT id FROM orders WHERE status = 'pending' ORDER BY random() LIMIT 2000
);

-- Intentionally NOT running VACUUM or ANALYZE
-- This leaves dead tuples and outdated statistics

EOF

echo "✓ Maintenance issues created (dead tuples, outdated stats)"
echo ""

# Summary
echo "=========================================="
echo "Database Setup Complete!"
echo "=========================================="
echo ""
echo "The database now has the following INTENTIONAL problems:"
echo ""
echo "🔴 PERFORMANCE ISSUES:"
echo "   - Missing indexes on frequently queried columns"
echo "   - Outdated table statistics (ANALYZE not run)"
echo "   - Table bloat (dead tuples from updates/deletes)"
echo ""
echo "🔴 DATA INTEGRITY ISSUES:"
echo "   - Duplicate customer emails (missing UNIQUE constraint)"
echo "   - Products with negative stock quantities"
echo "   - Orphaned order_items (referencing non-existent orders)"
echo "   - Order_items with invalid product_ids"
echo "   - Orders with zero or negative totals"
echo "   - Products with NULL category_id"
echo ""
echo "🔴 SCHEMA ISSUES:"
echo "   - Missing foreign key constraints"
echo "   - Missing UNIQUE constraints"
echo "   - Missing CHECK constraints"
echo ""
echo "📊 Database Statistics:"
docker exec techshop-db psql -U postgres -d techshop -c "
SELECT 
    'customers' as table_name, COUNT(*) as rows FROM customers
UNION ALL SELECT 'products', COUNT(*) FROM products
UNION ALL SELECT 'orders', COUNT(*) FROM orders
UNION ALL SELECT 'order_items', COUNT(*) FROM order_items;
"

echo ""
echo "=========================================="
echo "Next Steps:"
echo "=========================================="
echo "1. Connect to the database:"
echo "   docker exec -it techshop-db psql -U postgres -d techshop"
echo ""
echo "2. Start diagnosing issues using the queries in REAL_WORLD_SCENARIO.md"
echo ""
echo "3. Fix the problems you find!"
echo ""
echo "Good luck! 🚀"
echo ""

