#!/bin/bash

# Setup script for Intermediate PostgreSQL Lesson
# This script creates the practice database and sample data

set -e  # Exit on error

echo "🚀 Setting up Intermediate PostgreSQL Lesson Database..."
echo ""

# Check if PostgreSQL container is running
if ! docker ps | grep -q my-postgres; then
    echo "⚠️  PostgreSQL container 'my-postgres' is not running."
    echo "Starting container..."
    docker run --name my-postgres -e POSTGRES_PASSWORD=postgres -d -p 5432:5432 postgres:15
    echo "⏳ Waiting for PostgreSQL to start..."
    sleep 5
else
    echo "✅ PostgreSQL container is running"
fi

echo ""
echo "📦 Creating database and tables..."

# Create database and tables
docker exec -i my-postgres psql -U postgres << 'EOF'
-- Drop database if exists (for clean restart)
DROP DATABASE IF EXISTS ecommerce_advanced;

-- Create database
CREATE DATABASE ecommerce_advanced;
\c ecommerce_advanced

-- Create customers table
CREATE TABLE customers (
    id SERIAL PRIMARY KEY,
    first_name VARCHAR(50) NOT NULL,
    last_name VARCHAR(50) NOT NULL,
    email VARCHAR(100) UNIQUE NOT NULL,
    city VARCHAR(50),
    registration_date DATE DEFAULT CURRENT_DATE
);

-- Create products table
CREATE TABLE products (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    category VARCHAR(50),
    price DECIMAL(10, 2) NOT NULL,
    stock_quantity INTEGER DEFAULT 0
);

-- Create orders table
CREATE TABLE orders (
    id SERIAL PRIMARY KEY,
    customer_id INTEGER REFERENCES customers(id) ON DELETE CASCADE,
    order_date DATE DEFAULT CURRENT_DATE,
    status VARCHAR(20) DEFAULT 'pending',
    total_amount DECIMAL(10, 2)
);

-- Create order_items table (junction table)
CREATE TABLE order_items (
    id SERIAL PRIMARY KEY,
    order_id INTEGER REFERENCES orders(id) ON DELETE CASCADE,
    product_id INTEGER REFERENCES products(id) ON DELETE RESTRICT,
    quantity INTEGER NOT NULL CHECK (quantity > 0),
    unit_price DECIMAL(10, 2) NOT NULL,
    subtotal DECIMAL(10, 2) GENERATED ALWAYS AS (quantity * unit_price) STORED
);

-- Insert sample data
INSERT INTO customers (first_name, last_name, email, city, registration_date) VALUES
('Alice', 'Johnson', 'alice.j@email.com', 'New York', '2024-01-15'),
('Bob', 'Smith', 'bob.smith@email.com', 'Los Angeles', '2024-02-20'),
('Carol', 'Williams', 'carol.w@email.com', 'Chicago', '2024-01-10'),
('David', 'Brown', 'david.b@email.com', 'Houston', '2024-03-05'),
('Eve', 'Davis', 'eve.d@email.com', 'New York', '2024-02-28');

INSERT INTO products (name, category, price, stock_quantity) VALUES
('Laptop', 'Electronics', 999.99, 15),
('Mouse', 'Electronics', 29.99, 50),
('Keyboard', 'Electronics', 79.99, 30),
('Desk Chair', 'Furniture', 199.99, 20),
('Monitor', 'Electronics', 299.99, 25),
('Notebook', 'Office Supplies', 9.99, 100);

INSERT INTO orders (customer_id, order_date, status, total_amount) VALUES
(1, '2024-03-10', 'completed', 1029.98),
(2, '2024-03-11', 'pending', 379.98),
(3, '2024-03-12', 'completed', 199.99),
(1, '2024-03-15', 'pending', 79.99),
(4, '2024-03-16', 'completed', 309.98);

INSERT INTO order_items (order_id, product_id, quantity, unit_price) VALUES
(1, 1, 1, 999.99),  -- Alice: Laptop
(1, 2, 1, 29.99),   -- Alice: Mouse
(2, 5, 1, 299.99),  -- Bob: Monitor
(2, 2, 2, 29.99),   -- Bob: 2x Mouse
(2, 6, 1, 9.99),    -- Bob: Notebook
(3, 4, 1, 199.99),  -- Carol: Desk Chair
(4, 3, 1, 79.99),   -- Alice: Keyboard
(5, 5, 1, 299.99),  -- David: Monitor
(5, 2, 1, 29.99);   -- David: Mouse

-- Verify data
SELECT '✅ Setup complete!' as status;
SELECT 'Customers:' as info, COUNT(*) as count FROM customers
UNION ALL
SELECT 'Products:', COUNT(*) FROM products
UNION ALL
SELECT 'Orders:', COUNT(*) FROM orders
UNION ALL
SELECT 'Order Items:', COUNT(*) FROM order_items;
EOF

echo ""
echo "✅ Database setup complete!"
echo ""
echo "📊 Database Statistics:"
docker exec my-postgres psql -U postgres -d ecommerce_advanced -c "
SELECT 'Customers:' as info, COUNT(*)::text as count FROM customers
UNION ALL
SELECT 'Products:', COUNT(*)::text FROM products
UNION ALL
SELECT 'Orders:', COUNT(*)::text FROM orders
UNION ALL
SELECT 'Order Items:', COUNT(*)::text FROM order_items;
"

echo ""
echo "🔗 To connect to the database, run:"
echo "   docker exec -it my-postgres psql -U postgres -d ecommerce_advanced"
echo ""
echo "📖 Follow along with the lesson in: intermediate-postgresql-lesson.md"
echo ""

