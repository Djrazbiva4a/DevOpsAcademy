# Exercise 5: Understanding Indexes

## Learning Objectives
- Understand what indexes are and why we need them
- See how indexes improve query performance
- Create different types of indexes
- Understand when to use indexes
- Learn about index trade-offs

## What is an Index?

Think of a database index like an index in a book. Instead of reading every page to find a topic, you look it up in the index and go directly to the right page.

**In databases:**
- An **index** is a data structure that improves the speed of data retrieval
- Without an index, PostgreSQL must scan every row (called a "full table scan")
- With an index, PostgreSQL can quickly find the rows you need

## Why Do We Need Indexes?

### Performance Problem

Imagine a table with 1 million customer records. To find a customer by email:

```sql
SELECT * FROM customers WHERE email = 'john.doe@email.com';
```

**Without an index:**
- PostgreSQL checks every single row (1 million checks!)
- This is called a "sequential scan" or "full table scan"
- Very slow for large tables

**With an index:**
- PostgreSQL uses the index to jump directly to the row
- Only a few operations needed
- Much faster!

### Real-World Analogy

- **No index**: Like finding a word in a dictionary by reading every page
- **With index**: Like using the dictionary's alphabetical index

## Step-by-Step Instructions

### Step 1: Connect and Create Test Data

```bash
docker exec -it my-postgres psql -U postgres -d ecommerce
```

Create a table and insert test data:

```sql
CREATE TABLE products (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100),
    category VARCHAR(50),
    price DECIMAL(10, 2),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Insert sample data (this simulates a larger dataset)
INSERT INTO products (name, category, price)
SELECT 
    'Product ' || generate_series(1, 10000),
    CASE (random() * 4)::int
        WHEN 0 THEN 'Electronics'
        WHEN 1 THEN 'Clothing'
        WHEN 2 THEN 'Books'
        ELSE 'Food'
    END,
    (random() * 1000)::decimal(10, 2);
```

This creates 10,000 products with random categories and prices.

### Step 2: Query Without Index (Slow)

Let's see how long a query takes without an index:

```sql
-- Enable timing to see query duration
\timing

-- Search for a specific product (this will be slow)
SELECT * FROM products WHERE name = 'Product 5000';
```

Note the execution time. On my system, this takes about 10-20ms.

### Step 3: Create an Index

Now let's create an index on the `name` column:

```sql
CREATE INDEX idx_products_name ON products(name);
```

**Syntax:**
- `CREATE INDEX` - command to create an index
- `idx_products_name` - name of the index (descriptive name)
- `ON products(name)` - index on the `name` column of `products` table

### Step 4: Query With Index (Fast)

Run the same query again:

```sql
SELECT * FROM products WHERE name = 'Product 5000';
```

Notice how much faster it is! The index allows PostgreSQL to find the row almost instantly.

### Step 5: View Index Information

See what indexes exist on a table:

```sql
\d products
```

Or get detailed index information:

```sql
SELECT 
    indexname,
    indexdef
FROM pg_indexes
WHERE tablename = 'products';
```

### Step 6: Create Index on Multiple Columns

Indexes can span multiple columns:

```sql
CREATE INDEX idx_products_category_price ON products(category, price);
```

This index helps queries that filter by both category and price:

```sql
SELECT * FROM products 
WHERE category = 'Electronics' AND price < 100;
```

### Step 7: Create Unique Index

Ensure values are unique:

```sql
-- First, let's add an email column to products (for demonstration)
ALTER TABLE products ADD COLUMN sku VARCHAR(50);

-- Create unique index
CREATE UNIQUE INDEX idx_products_sku ON products(sku);
```

Now you can't insert duplicate SKU values.

### Step 8: Explain Query Plan

See how PostgreSQL executes a query:

```sql
EXPLAIN ANALYZE SELECT * FROM products WHERE name = 'Product 5000';
```

**Key terms in output:**
- **Seq Scan** (Sequential Scan) - reading all rows (slow, no index used)
- **Index Scan** - using index to find rows (fast!)
- **Execution Time** - how long the query took

### Step 9: When Indexes Are Used

Indexes are automatically used when:
- Filtering with WHERE on indexed column
- Joining tables on indexed columns
- Sorting with ORDER BY on indexed column

```sql
-- This will use the index
SELECT * FROM products WHERE name LIKE 'Product 5%';

-- This will use the index for sorting
SELECT * FROM products ORDER BY name LIMIT 10;
```

## Types of Indexes

### B-tree Index (Default)
Most common, good for most cases:
```sql
CREATE INDEX idx_name ON table_name(column_name);
```

### Partial Index
Index only part of the data:
```sql
CREATE INDEX idx_active_products ON products(name) 
WHERE category = 'Electronics';
```

### Expression Index
Index on a computed value:
```sql
CREATE INDEX idx_lower_name ON products(LOWER(name));
```

## When to Use Indexes

### ✅ Good Candidates for Indexing:
- Primary keys (automatically indexed)
- Foreign keys
- Columns frequently used in WHERE clauses
- Columns used in JOINs
- Columns used for sorting (ORDER BY)

### ❌ Don't Index:
- Small tables (index overhead not worth it)
- Columns rarely used in queries
- Columns with very few unique values (like boolean)
- Columns frequently updated (indexes slow down INSERT/UPDATE)

## Trade-offs

**Benefits:**
- ✅ Faster SELECT queries
- ✅ Faster JOINs
- ✅ Faster sorting

**Costs:**
- ❌ Slower INSERT/UPDATE/DELETE (index must be updated)
- ❌ Uses additional disk space
- ❌ Maintenance overhead

## Practice Tasks

1. Create an index on the `category` column of products

2. Run `EXPLAIN ANALYZE` on a query filtering by category and compare the execution time

3. Create a composite index on `(category, price)` and test queries that use both columns

4. List all indexes on the products table

5. Create a unique index on a column and try inserting duplicate values (it should fail)

6. Drop an index:
   ```sql
   DROP INDEX idx_products_name;
   ```
   Then run the same query and see how it's slower

7. Create an index on the `created_at` column and test queries that order by date

## Useful Commands

```sql
-- Create index
CREATE INDEX index_name ON table_name(column_name);

-- Create unique index
CREATE UNIQUE INDEX index_name ON table_name(column_name);

-- Create composite index
CREATE INDEX index_name ON table_name(col1, col2);

-- Drop index
DROP INDEX index_name;

-- List all indexes
\di

-- View index details
\d table_name

-- Explain query plan
EXPLAIN SELECT ...;
EXPLAIN ANALYZE SELECT ...;
```

## Key Concepts

- **Index**: Data structure that speeds up data retrieval
- **Full Table Scan**: Reading every row (slow)
- **Index Scan**: Using index to find rows (fast)
- **B-tree**: Most common index type
- **Composite Index**: Index on multiple columns
- **Unique Index**: Ensures no duplicate values
- **Trade-off**: Faster reads, slower writes

## Common Issues

**Problem**: Index not being used
- **Solution**: Check if the query actually benefits from an index. Sometimes PostgreSQL decides a full scan is faster for small tables.

**Problem**: Too many indexes slowing down writes
- **Solution**: Only create indexes on columns that are frequently queried

**Problem**: Index taking up too much space
- **Solution**: Consider partial indexes or removing unused indexes

## Next Steps

Excellent! You now understand indexes and their importance. In the next exercise, we'll learn how to update and delete data from tables.

