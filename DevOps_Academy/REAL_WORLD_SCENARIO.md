# Real-World Scenario: E-Commerce Database Incident

## Scenario Overview

You are a DevOps engineer at **TechShop**, an online electronics retailer. The company's e-commerce platform uses PostgreSQL as its primary database. You've been called in to handle a critical database incident and need to apply your PostgreSQL knowledge to resolve it.

---

## The Situation

**Date**: Monday, 9:00 AM  
**Incident**: Database performance degradation and data integrity concerns

### Background

TechShop's e-commerce platform has been experiencing:
- Slow page load times (especially product search)
- Reports of missing order data
- Customer complaints about incorrect inventory counts
- Application errors related to database connections

The development team suspects database issues but needs your help to diagnose and fix them.

---

## Your Mission

You need to:
1. **Diagnose** the database issues
2. **Fix** performance problems
3. **Verify** data integrity
4. **Document** your findings and solutions
5. **Prevent** future issues

---

## The Database Schema

TechShop's database has the following structure:

```sql
-- Customers table
CREATE TABLE customers (
    id SERIAL PRIMARY KEY,
    email VARCHAR(255) UNIQUE NOT NULL,
    first_name VARCHAR(100),
    last_name VARCHAR(100),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Products table
CREATE TABLE products (
    id SERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    sku VARCHAR(50) UNIQUE NOT NULL,
    price DECIMAL(10, 2) NOT NULL,
    stock_quantity INTEGER DEFAULT 0,
    category_id INTEGER,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Categories table
CREATE TABLE categories (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    parent_id INTEGER REFERENCES categories(id)
);

-- Orders table
CREATE TABLE orders (
    id SERIAL PRIMARY KEY,
    customer_id INTEGER REFERENCES customers(id),
    order_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    total_amount DECIMAL(10, 2),
    status VARCHAR(50) DEFAULT 'pending'
);

-- Order items table
CREATE TABLE order_items (
    id SERIAL PRIMARY KEY,
    order_id INTEGER REFERENCES orders(id),
    product_id INTEGER REFERENCES products(id),
    quantity INTEGER NOT NULL,
    price DECIMAL(10, 2) NOT NULL
);
```

---

## Incident Timeline

### Phase 1: Initial Investigation (9:00 AM - 9:30 AM)

**Task 1.1: Connect and Assess**
- Connect to the database using Docker
- Check database size and table counts
- Identify any obvious issues

**Task 1.2: Check Active Connections**
- How many connections are active?
- Are there any long-running queries?
- Any connection errors in logs?

**Task 1.3: Review Recent Changes**
- Check when tables were last modified
- Review any recent schema changes
- Check backup status

### Phase 2: Performance Investigation (9:30 AM - 10:30 AM)

**Task 2.1: Identify Slow Queries**
- Find queries taking longer than 1 second
- Check for missing indexes
- Analyze query execution plans

**Task 2.2: Check Index Usage**
- Which tables are missing indexes?
- Are existing indexes being used?
- Identify unused indexes

**Task 2.3: Check Table Statistics**
- When was ANALYZE last run?
- Are statistics up to date?
- Check for table bloat

**Discovery**: 
- The `products` table has 100,000+ rows but no index on `name` or `category_id`
- The `order_items` table has no index on `order_id` or `product_id`
- Last VACUUM was 2 weeks ago
- Table statistics are outdated

### Phase 3: Data Integrity Check (10:30 AM - 11:00 AM)

**Task 3.1: Check for Orphaned Records**
- Find order_items without valid orders
- Find orders without customers
- Find products without categories

**Task 3.2: Verify Constraints**
- Check for duplicate emails in customers
- Check for negative stock quantities
- Verify order totals match order_items sums

**Task 3.3: Check for Data Anomalies**
- Orders with zero or negative amounts
- Products with NULL critical fields
- Inconsistent timestamps

**Discovery**:
- 15 order_items reference non-existent orders (orphaned records)
- 3 products have negative stock_quantity
- 2 customers have duplicate emails (constraint violation somehow occurred)

### Phase 4: Fix Issues (11:00 AM - 12:00 PM)

**Task 4.1: Create Missing Indexes**
```sql
-- Create indexes to improve query performance
CREATE INDEX idx_products_name ON products(name);
CREATE INDEX idx_products_category ON products(category_id);
CREATE INDEX idx_order_items_order_id ON order_items(order_id);
CREATE INDEX idx_order_items_product_id ON order_items(product_id);
CREATE INDEX idx_orders_customer_id ON orders(customer_id);
CREATE INDEX idx_orders_status ON orders(status);
```

**Task 4.2: Clean Up Data Issues**
- Remove or fix orphaned order_items
- Fix negative stock quantities
- Resolve duplicate customer emails

**Task 4.3: Run Maintenance**
```sql
-- Update statistics
ANALYZE;

-- Clean up dead tuples
VACUUM ANALYZE products;
VACUUM ANALYZE orders;
VACUUM ANALYZE order_items;
```

**Task 4.4: Verify Fixes**
- Re-run slow queries and check performance
- Verify data integrity again
- Check index usage

### Phase 5: Prevention and Documentation (12:00 PM - 12:30 PM)

**Task 5.1: Set Up Monitoring**
- Create a view for database health metrics
- Document key queries for monitoring
- Set up regular maintenance schedule

**Task 5.2: Create Backup Strategy**
- Verify backup is working
- Test restore procedure
- Document backup/restore process

**Task 5.3: Document Findings**
- Create incident report
- Document all fixes applied
- Recommend preventive measures

---

## Detailed Tasks Breakdown

### Task 1: Initial Database Assessment

**Connect to Database:**
```bash
docker exec -it techshop-db psql -U postgres -d techshop
```

**Check Database Health:**
```sql
-- Database size
SELECT pg_size_pretty(pg_database_size('techshop')) AS database_size;

-- Table sizes
SELECT 
    schemaname,
    tablename,
    pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) AS size
FROM pg_tables
WHERE schemaname = 'public'
ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC;

-- Row counts
SELECT 
    'customers' as table_name, COUNT(*) as row_count FROM customers
UNION ALL
SELECT 'products', COUNT(*) FROM products
UNION ALL
SELECT 'orders', COUNT(*) FROM orders
UNION ALL
SELECT 'order_items', COUNT(*) FROM order_items;
```

**Check Active Connections:**
```sql
SELECT 
    pid,
    usename,
    application_name,
    client_addr,
    state,
    query_start,
    state_change,
    LEFT(query, 50) as current_query
FROM pg_stat_activity
WHERE datname = 'techshop'
ORDER BY query_start;
```

### Task 2: Performance Analysis

**Find Slow Queries:**
```sql
-- Enable pg_stat_statements (if available)
-- Or check for long-running queries
SELECT 
    pid,
    now() - query_start AS duration,
    state,
    query
FROM pg_stat_activity
WHERE state = 'active'
  AND now() - query_start > interval '1 second'
ORDER BY duration DESC;
```

**Check Missing Indexes:**
```sql
-- Check which columns are frequently used in WHERE clauses but not indexed
-- Products table - check name searches
EXPLAIN ANALYZE SELECT * FROM products WHERE name LIKE '%laptop%';

-- Check category filtering
EXPLAIN ANALYZE SELECT * FROM products WHERE category_id = 5;

-- Check order lookups
EXPLAIN ANALYZE SELECT * FROM order_items WHERE order_id = 12345;
```

**Check Table Bloat:**
```sql
SELECT 
    schemaname,
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

### Task 3: Data Integrity Checks

**Find Orphaned Records:**
```sql
-- Order items without valid orders
SELECT oi.* 
FROM order_items oi
LEFT JOIN orders o ON oi.order_id = o.id
WHERE o.id IS NULL;

-- Orders without valid customers
SELECT o.*
FROM orders o
LEFT JOIN customers c ON o.customer_id = c.id
WHERE c.id IS NULL;

-- Products without valid categories (if category_id is set)
SELECT p.*
FROM products p
LEFT JOIN categories cat ON p.category_id = cat.id
WHERE p.category_id IS NOT NULL AND cat.id IS NULL;
```

**Check Data Quality:**
```sql
-- Negative stock quantities
SELECT id, name, stock_quantity 
FROM products 
WHERE stock_quantity < 0;

-- Duplicate customer emails (shouldn't happen with UNIQUE constraint)
SELECT email, COUNT(*) 
FROM customers 
GROUP BY email 
HAVING COUNT(*) > 1;

-- Orders with zero or negative totals
SELECT id, customer_id, total_amount, order_date
FROM orders
WHERE total_amount <= 0;

-- Verify order totals match order_items sums
SELECT 
    o.id as order_id,
    o.total_amount as order_total,
    COALESCE(SUM(oi.quantity * oi.price), 0) as calculated_total,
    o.total_amount - COALESCE(SUM(oi.quantity * oi.price), 0) as difference
FROM orders o
LEFT JOIN order_items oi ON o.id = oi.order_id
GROUP BY o.id, o.total_amount
HAVING ABS(o.total_amount - COALESCE(SUM(oi.quantity * oi.price), 0)) > 0.01;
```

### Task 4: Apply Fixes

**Create Indexes:**
```sql
-- Performance indexes
CREATE INDEX CONCURRENTLY idx_products_name ON products(name);
CREATE INDEX CONCURRENTLY idx_products_category ON products(category_id);
CREATE INDEX CONCURRENTLY idx_order_items_order_id ON order_items(order_id);
CREATE INDEX CONCURRENTLY idx_order_items_product_id ON order_items(product_id);
CREATE INDEX CONCURRENTLY idx_orders_customer_id ON orders(customer_id);
CREATE INDEX CONCURRENTLY idx_orders_status ON orders(status);
CREATE INDEX CONCURRENTLY idx_orders_date ON orders(order_date);
```

**Fix Data Issues:**
```sql
-- Fix negative stock (set to 0, but in real scenario might need investigation)
UPDATE products 
SET stock_quantity = 0 
WHERE stock_quantity < 0;

-- Remove orphaned order_items (after investigation)
-- First, check what they are:
SELECT oi.*, 'Orphaned - order does not exist' as issue
FROM order_items oi
LEFT JOIN orders o ON oi.order_id = o.id
WHERE o.id IS NULL;

-- If confirmed safe to delete:
DELETE FROM order_items 
WHERE order_id NOT IN (SELECT id FROM orders);

-- Fix duplicate emails (merge or update)
-- This requires business logic - example: keep the oldest record
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
```

**Run Maintenance:**
```sql
-- Update all statistics
ANALYZE;

-- Vacuum critical tables
VACUUM ANALYZE products;
VACUUM ANALYZE orders;
VACUUM ANALYZE order_items;
VACUUM ANALYZE customers;
```

### Task 5: Create Monitoring Views

**Database Health View:**
```sql
CREATE OR REPLACE VIEW db_health_summary AS
SELECT 
    'Table Sizes' as metric_type,
    tablename as item,
    pg_size_pretty(pg_total_relation_size('public.'||tablename)) as value
FROM pg_tables
WHERE schemaname = 'public'
UNION ALL
SELECT 
    'Dead Tuples',
    tablename,
    n_dead_tup::text || ' (' || 
    ROUND(n_dead_tup * 100.0 / NULLIF(n_live_tup + n_dead_tup, 0), 1) || '%)'
FROM pg_stat_user_tables
WHERE schemaname = 'public' AND n_dead_tup > 0
UNION ALL
SELECT 
    'Last Vacuum',
    tablename,
    COALESCE(last_autovacuum::text, last_vacuum::text, 'Never')
FROM pg_stat_user_tables
WHERE schemaname = 'public';
```

**Query the health view:**
```sql
SELECT * FROM db_health_summary ORDER BY metric_type, item;
```

---

## Expected Outcomes

After completing this scenario, you should have:

1. ✅ **Identified** performance bottlenecks (missing indexes)
2. ✅ **Fixed** data integrity issues (orphaned records, negative values)
3. ✅ **Improved** query performance (created indexes)
4. ✅ **Maintained** database health (VACUUM, ANALYZE)
5. ✅ **Documented** findings and solutions
6. ✅ **Established** monitoring and maintenance procedures

---

## Success Criteria

- All slow queries now execute in < 100ms
- No orphaned records exist
- All data integrity checks pass
- Database maintenance is automated
- Monitoring is in place
- Documentation is complete

---

## Real-World Considerations

This scenario teaches:

1. **Troubleshooting Methodology**: Systematic approach to diagnosing issues
2. **Performance Tuning**: Identifying and fixing slow queries
3. **Data Integrity**: Finding and fixing data quality issues
4. **Maintenance**: Regular database upkeep
5. **Documentation**: Critical for team knowledge sharing
6. **Prevention**: Setting up monitoring to catch issues early

---

## How to Use This Scenario

1. **As a Capstone Exercise**: After completing all 10 exercises, work through this scenario
2. **As a Practice Lab**: Use it to reinforce concepts learned
3. **As a Team Exercise**: Work through it with colleagues
4. **As a Assessment**: Test your PostgreSQL knowledge

---

## Setup Instructions

To set up this scenario, you'll need to:

1. Create the database schema (provided above)
2. Insert sample data (you can generate this)
3. Intentionally create some issues (missing indexes, orphaned data)
4. Work through the tasks to fix them

Would you like me to create:
1. A setup script to create this scenario?
2. Sample data generation scripts?
3. A step-by-step walkthrough guide?
4. All of the above?

This scenario combines concepts from:
- Exercise 3 (Creating Tables)
- Exercise 4 (Querying Data)
- Exercise 5 (Indexes)
- Exercise 6 (Updating/Deleting)
- Exercise 9 (VACUUM)
- Exercise 10 (Backup/Restore)
- Plus JOINs, constraints, and monitoring concepts

