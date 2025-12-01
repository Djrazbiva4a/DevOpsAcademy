# Exercise 7: Dropping Tables

## Learning Objectives
- Understand what dropping a table means
- Learn how to safely drop tables
- Understand dependencies and foreign keys
- Learn about CASCADE and RESTRICT options
- Practice safe table management

## What Does "Drop" Mean?

**Dropping a table** means permanently deleting the table and all its data from the database. This is irreversible!

⚠️ **Warning**: 
- Dropping a table deletes the table structure AND all data
- This action cannot be undone (unless you have a backup)
- Always be careful with DROP commands!

## Step-by-Step Instructions

### Step 1: Connect to Database

```bash
docker exec -it my-postgres psql -U postgres -d ecommerce
```

### Step 2: Create Test Tables

Let's create some tables to practice with:

```sql
-- Create a customers table
CREATE TABLE customers (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100),
    email VARCHAR(100)
);

-- Create an orders table that references customers
CREATE TABLE orders (
    id SERIAL PRIMARY KEY,
    customer_id INTEGER REFERENCES customers(id),
    order_date DATE,
    total DECIMAL(10, 2)
);

-- Create a simple products table
CREATE TABLE products (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100),
    price DECIMAL(10, 2)
);

-- Insert some test data
INSERT INTO customers (name, email) VALUES
    ('John Doe', 'john@email.com'),
    ('Jane Smith', 'jane@email.com');

INSERT INTO orders (customer_id, order_date, total) VALUES
    (1, '2024-01-15', 99.99),
    (2, '2024-01-16', 149.50);
```

### Step 3: List All Tables

See what tables exist:

```sql
\dt
```

You should see: customers, orders, and products.

### Step 4: Drop a Simple Table

Drop the products table (it has no dependencies):

```sql
DROP TABLE products;
```

Verify it's gone:
```sql
\dt
```

The products table should no longer appear.

### Step 5: Try to Drop a Table with Dependencies

Try to drop the customers table:

```sql
DROP TABLE customers;
```

You should get an error like:
```
ERROR: cannot drop table customers because other objects depend on it
```

This is PostgreSQL protecting you! The `orders` table has a foreign key referencing `customers`, so you can't drop `customers` while `orders` still exists.

### Step 6: View Dependencies

See what depends on the customers table:

```sql
SELECT 
    tc.table_name, 
    kcu.column_name,
    ccu.table_name AS foreign_table_name,
    ccu.column_name AS foreign_column_name
FROM information_schema.table_constraints AS tc
JOIN information_schema.key_column_usage AS kcu
    ON tc.constraint_name = kcu.constraint_name
JOIN information_schema.constraint_column_usage AS ccu
    ON ccu.constraint_name = tc.constraint_name
WHERE tc.constraint_type = 'FOREIGN KEY' 
    AND ccu.table_name = 'customers';
```

This shows that `orders` depends on `customers`.

### Step 7: Drop Dependent Table First

To drop customers, we must drop orders first:

```sql
DROP TABLE orders;
DROP TABLE customers;
```

Now both tables are dropped. Verify:
```sql
\dt
```

### Step 8: Recreate Tables for CASCADE Example

Let's recreate the tables:

```sql
CREATE TABLE customers (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100),
    email VARCHAR(100)
);

CREATE TABLE orders (
    id SERIAL PRIMARY KEY,
    customer_id INTEGER REFERENCES customers(id),
    order_date DATE,
    total DECIMAL(10, 2)
);

INSERT INTO customers (name, email) VALUES ('John Doe', 'john@email.com');
INSERT INTO orders (customer_id, order_date, total) VALUES (1, '2024-01-15', 99.99);
```

### Step 9: Use CASCADE to Drop Everything

`CASCADE` automatically drops dependent objects:

```sql
DROP TABLE customers CASCADE;
```

This drops `customers` AND automatically drops `orders` (and any other dependent objects).

⚠️ **Be very careful with CASCADE!** It can delete more than you expect.

### Step 10: Use RESTRICT (Default Behavior)

`RESTRICT` prevents dropping if there are dependencies (this is the default):

```sql
-- Recreate tables
CREATE TABLE customers (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100)
);

CREATE TABLE orders (
    id SERIAL PRIMARY KEY,
    customer_id INTEGER REFERENCES customers(id)
);

-- This will fail (same as default behavior)
DROP TABLE customers RESTRICT;
```

### Step 11: Drop Multiple Tables

Drop several tables at once:

```sql
CREATE TABLE table1 (id SERIAL PRIMARY KEY);
CREATE TABLE table2 (id SERIAL PRIMARY KEY);
CREATE TABLE table3 (id SERIAL PRIMARY KEY);

-- Drop multiple tables
DROP TABLE table1, table2, table3;
```

### Step 12: Drop Table If Exists

Safely drop a table that might not exist:

```sql
DROP TABLE IF EXISTS non_existent_table;
```

This won't error if the table doesn't exist. Useful in scripts.

## Understanding Dependencies

### Types of Dependencies

Tables can depend on each other through:
1. **Foreign Keys** - Most common
2. **Views** - Views that query the table
3. **Functions** - Functions that reference the table
4. **Triggers** - Triggers on the table

### Finding All Dependencies

```sql
-- Find all objects depending on a table
SELECT 
    dependent_ns.nspname as dependent_schema,
    dependent_view.relname as dependent_view,
    source_ns.nspname as source_schema,
    source_table.relname as source_table
FROM pg_depend
JOIN pg_rewrite ON pg_depend.objid = pg_rewrite.oid
JOIN pg_class as dependent_view ON pg_rewrite.ev_class = dependent_view.oid
JOIN pg_class as source_table ON pg_depend.refobjid = source_table.oid
JOIN pg_namespace dependent_ns ON dependent_ns.oid = dependent_view.relnamespace
JOIN pg_namespace source_ns ON source_ns.oid = source_table.relnamespace
WHERE source_table.relname = 'customers';
```

## Safe Dropping Practices

### 1. Always Check Dependencies First

```sql
-- Before dropping, see what depends on it
\d+ table_name
```

### 2. Use IF EXISTS

```sql
DROP TABLE IF EXISTS table_name;
```

### 3. Test in Development First

Never drop tables in production without testing in development first!

### 4. Backup Before Dropping

Always backup your data before dropping tables in production.

### 5. Use Transactions

```sql
BEGIN;
DROP TABLE test_table;
-- Check everything is okay
-- If good: COMMIT; If bad: ROLLBACK;
```

## Useful Commands

```sql
-- Drop a table
DROP TABLE table_name;

-- Drop with CASCADE (drops dependencies too)
DROP TABLE table_name CASCADE;

-- Drop with RESTRICT (fails if dependencies exist - default)
DROP TABLE table_name RESTRICT;

-- Drop only if exists
DROP TABLE IF EXISTS table_name;

-- Drop multiple tables
DROP TABLE table1, table2, table3;

-- List all tables
\dt

-- Show table structure and dependencies
\d table_name
\d+ table_name
```

## Practice Tasks

1. Create three tables: `authors`, `books`, and `reviews` where:
   - `books` references `authors`
   - `reviews` references `books`

2. Try to drop `authors` - it should fail. Why?

3. Drop the tables in the correct order (drop dependent tables first)

4. Recreate the tables and use `CASCADE` to drop `authors` - what happens to the other tables?

5. Create a table, insert some data, then drop it

6. Try to drop a table that doesn't exist - see the error

7. Use `DROP TABLE IF EXISTS` on a non-existent table - no error should occur

8. Create a view that queries a table, then try to drop the table with and without CASCADE

9. List all tables before and after dropping to verify

10. Practice the safe drop procedure:
    - Check dependencies with `\d+ table_name`
    - Backup data (SELECT * INTO backup_table FROM original_table)
    - Drop the table
    - Verify it's gone

## Key Concepts

- **DROP TABLE**: Permanently deletes a table and all its data
- **Dependencies**: Other objects (tables, views, etc.) that reference the table
- **CASCADE**: Automatically drops dependent objects
- **RESTRICT**: Prevents dropping if dependencies exist (default)
- **IF EXISTS**: Prevents errors if table doesn't exist
- **Irreversible**: Dropped tables cannot be recovered without backup

## Common Issues

**Problem**: "cannot drop table because other objects depend on it"
- **Solution**: Drop dependent objects first, or use CASCADE (carefully!)

**Problem**: Dropped the wrong table
- **Solution**: Restore from backup. Always backup before dropping!

**Problem**: CASCADE deleted more than expected
- **Solution**: Check dependencies first with `\d+ table_name` before using CASCADE

## Next Steps

Excellent! You now understand how to safely drop tables. In the next exercise, we'll learn about creating users and managing database permissions.

