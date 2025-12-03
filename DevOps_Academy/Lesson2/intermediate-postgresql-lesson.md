# Intermediate PostgreSQL: Joins, Transactions, and Advanced Queries
## 90-Minute Hands-On Lesson

**Target Level:** Junior to Mid-Level  
**Duration:** 90 minutes  
**Prerequisites:** Basic SQL knowledge (SELECT, INSERT, UPDATE, DELETE, WHERE, ORDER BY)

---

## Table of Contents

1. [Introduction & Setup](#introduction--setup) (5 minutes)
2. [Understanding Joins](#understanding-joins) (30 minutes)
3. [Subqueries and CTEs](#subqueries-and-ctes) (20 minutes)
4. [Transactions and ACID Properties](#transactions-and-acid-properties) (20 minutes)
5. [Window Functions Basics](#window-functions-basics) (10 minutes)
6. [Practical Exercise](#practical-exercise) (5 minutes)

---

## Introduction & Setup (5 minutes)

### Learning Objectives

By the end of this lesson, you will be able to:
- Write complex queries using JOINs to combine data from multiple tables
- Use subqueries and Common Table Expressions (CTEs) to organize complex queries
- Understand and use transactions to ensure data integrity
- Apply basic window functions for advanced data analysis
- Optimize queries for better performance

### Setup Instructions

First, let's set up our practice database:

```bash
# Start PostgreSQL container (if not already running)
docker run --name my-postgres -e POSTGRES_PASSWORD=postgres -d -p 5432:5432 postgres:15

# Wait a few seconds for PostgreSQL to start
sleep 5

# Connect to PostgreSQL
docker exec -it my-postgres psql -U postgres
```

Now, let's create our practice database and tables:

```sql
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
SELECT 'Customers:' as info, COUNT(*) as count FROM customers
UNION ALL
SELECT 'Products:', COUNT(*) FROM products
UNION ALL
SELECT 'Orders:', COUNT(*) FROM orders
UNION ALL
SELECT 'Order Items:', COUNT(*) FROM order_items;
```

Great! Now we have a realistic e-commerce database to work with.

---

## Understanding Joins (30 minutes)

### What Are Joins?

**Joins** allow you to combine data from multiple tables based on a related column. Think of it like merging two spreadsheets based on a common ID.

### Why Do We Need Joins?

In our database:
- `customers` table has customer information
- `orders` table has order information
- They're connected by `customer_id`

**Without joins:** You'd need to run separate queries and combine results manually  
**With joins:** PostgreSQL does it automatically in one query!

### Types of Joins

#### 1. INNER JOIN (Most Common)

**What it does:** Returns only rows that have matching values in both tables.

**Visual representation:**
```
Table A          Table B
┌─────┐         ┌─────┐
│  1  │────────│  1  │  ← Match: Included
│  2  │        │  3  │  ← No match: Excluded
│  3  │────────│  3  │  ← Match: Included
└─────┘         └─────┘
```

**Example:** Get all orders with customer information

```sql
SELECT 
    o.id as order_id,
    o.order_date,
    o.status,
    c.first_name || ' ' || c.last_name as customer_name,
    c.email
FROM orders o
INNER JOIN customers c ON o.customer_id = c.id;
```

**Key points:**
- `INNER JOIN` is the default - you can just write `JOIN`
- `o` and `c` are table aliases (shortcuts)
- `ON` specifies the join condition
- Only orders with valid customer_id are returned

**Exercise 1:** Write a query to show all order items with product names and prices.

<details>
<summary>Click for solution</summary>

```sql
SELECT 
    oi.id,
    oi.order_id,
    p.name as product_name,
    oi.quantity,
    oi.unit_price,
    oi.subtotal
FROM order_items oi
INNER JOIN products p ON oi.product_id = p.id;
```
</details>

#### 2. LEFT JOIN (LEFT OUTER JOIN)

**What it does:** Returns all rows from the left table, plus matching rows from the right table. If no match, right table columns are NULL.

**Visual representation:**
```
Table A          Table B
┌─────┐         ┌─────┐
│  1  │────────│  1  │  ← Match: Included
│  2  │        │     │  ← No match: Included (NULL)
│  3  │────────│  3  │  ← Match: Included
└─────┘         └─────┘
```

**Example:** Get all customers and their orders (even if they have no orders)

```sql
SELECT 
    c.id,
    c.first_name || ' ' || c.last_name as customer_name,
    o.id as order_id,
    o.order_date,
    o.total_amount
FROM customers c
LEFT JOIN orders o ON c.id = o.customer_id
ORDER BY c.id, o.order_date;
```

**Notice:** Customer Eve (id=5) appears with NULL order columns because she has no orders.

**Real-world use case:** "Show me all customers and how many orders they've placed"

```sql
SELECT 
    c.first_name || ' ' || c.last_name as customer_name,
    COUNT(o.id) as order_count,
    COALESCE(SUM(o.total_amount), 0) as total_spent
FROM customers c
LEFT JOIN orders o ON c.id = o.customer_id
GROUP BY c.id, c.first_name, c.last_name
ORDER BY total_spent DESC;
```

**Exercise 2:** Find all products and show how many times each has been ordered (including products never ordered).

<details>
<summary>Click for solution</summary>

```sql
SELECT 
    p.name,
    p.category,
    COUNT(oi.id) as times_ordered,
    COALESCE(SUM(oi.quantity), 0) as total_quantity_sold
FROM products p
LEFT JOIN order_items oi ON p.id = oi.product_id
GROUP BY p.id, p.name, p.category
ORDER BY times_ordered DESC;
```
</details>

#### 3. RIGHT JOIN (RIGHT OUTER JOIN)

**What it does:** Returns all rows from the right table, plus matching rows from the left table. If no match, left table columns are NULL.

**Note:** RIGHT JOIN is less commonly used. You can usually rewrite it as a LEFT JOIN by swapping table order.

**Example:**

```sql
-- RIGHT JOIN
SELECT 
    o.id as order_id,
    c.first_name || ' ' || c.last_name as customer_name
FROM orders o
RIGHT JOIN customers c ON o.customer_id = c.id;

-- Equivalent LEFT JOIN (preferred)
SELECT 
    o.id as order_id,
    c.first_name || ' ' || c.last_name as customer_name
FROM customers c
LEFT JOIN orders o ON c.id = o.customer_id;
```

#### 4. FULL OUTER JOIN

**What it does:** Returns all rows from both tables. If no match, missing columns are NULL.

**Visual representation:**
```
Table A          Table B
┌─────┐         ┌─────┐
│  1  │────────│  1  │  ← Match: Included
│  2  │        │     │  ← No match: Included (NULL)
│  3  │────────│  3  │  ← Match: Included
│     │        │  4  │  ← No match: Included (NULL)
└─────┘         └─────┘
```

**Example:** Show all customers and all orders, matching where possible

```sql
SELECT 
    c.first_name || ' ' || c.last_name as customer_name,
    o.id as order_id,
    o.order_date
FROM customers c
FULL OUTER JOIN orders o ON c.id = o.customer_id;
```

**Use case:** Rare, but useful for data reconciliation or finding orphaned records.

#### 5. CROSS JOIN (Cartesian Product)

**What it does:** Returns every combination of rows from both tables. **Use with caution!**

**Example:**

```sql
-- This creates 5 customers × 6 products = 30 rows!
SELECT 
    c.first_name,
    p.name as product_name
FROM customers c
CROSS JOIN products p;
```

**When to use:** Very rarely - usually when you need all combinations (like generating test data).

### Multiple Joins

You can join multiple tables in one query:

**Example:** Get complete order details (customer, order, items, products)

```sql
SELECT 
    c.first_name || ' ' || c.last_name as customer_name,
    o.id as order_id,
    o.order_date,
    p.name as product_name,
    oi.quantity,
    oi.unit_price,
    oi.subtotal,
    o.total_amount as order_total
FROM orders o
INNER JOIN customers c ON o.customer_id = c.id
INNER JOIN order_items oi ON o.id = oi.order_id
INNER JOIN products p ON oi.product_id = p.id
ORDER BY o.id, oi.id;
```

**Exercise 3:** Write a query showing customer name, order date, product name, and quantity for all completed orders.

<details>
<summary>Click for solution</summary>

```sql
SELECT 
    c.first_name || ' ' || c.last_name as customer_name,
    o.order_date,
    p.name as product_name,
    oi.quantity
FROM orders o
INNER JOIN customers c ON o.customer_id = c.id
INNER JOIN order_items oi ON o.id = oi.order_id
INNER JOIN products p ON oi.product_id = p.id
WHERE o.status = 'completed'
ORDER BY o.order_date, c.last_name;
```
</details>

### Join Performance Tips

1. **Always join on indexed columns** (foreign keys are usually indexed)
2. **Use INNER JOIN when possible** (faster than OUTER JOINs)
3. **Filter early** - use WHERE clauses before joins when possible
4. **Be careful with multiple joins** - can get slow with many tables

### Common Join Mistakes

❌ **Wrong:** Forgetting the ON clause
```sql
SELECT * FROM orders JOIN customers;  -- ERROR!
```

✅ **Correct:** Always specify join condition
```sql
SELECT * FROM orders JOIN customers ON orders.customer_id = customers.id;
```

❌ **Wrong:** Joining on wrong columns
```sql
SELECT * FROM orders o JOIN customers c ON o.id = c.id;  -- Wrong!
```

✅ **Correct:** Join on the foreign key relationship
```sql
SELECT * FROM orders o JOIN customers c ON o.customer_id = c.id;
```

---

## Subqueries and CTEs (20 minutes)

### What Are Subqueries?

A **subquery** is a query nested inside another query. It's like asking a question to answer another question.

### Types of Subqueries

#### 1. Scalar Subquery (Returns Single Value)

**Example:** Find orders above the average order amount

```sql
SELECT 
    id,
    customer_id,
    total_amount
FROM orders
WHERE total_amount > (
    SELECT AVG(total_amount) FROM orders
);
```

**How it works:**
1. Inner query runs first: `SELECT AVG(total_amount) FROM orders` → returns 400.00
2. Outer query uses that value: `WHERE total_amount > 400.00`

#### 2. Subquery in WHERE with IN

**Example:** Find all customers who have placed orders

```sql
SELECT *
FROM customers
WHERE id IN (
    SELECT DISTINCT customer_id FROM orders
);
```

**Alternative with JOIN:**
```sql
SELECT DISTINCT c.*
FROM customers c
INNER JOIN orders o ON c.id = o.customer_id;
```

**When to use subquery vs JOIN:**
- **Subquery:** When you only need to check existence
- **JOIN:** When you need data from both tables

#### 3. Subquery in SELECT

**Example:** Show each order with customer's total lifetime orders

```sql
SELECT 
    o.id,
    o.order_date,
    o.total_amount,
    (
        SELECT COUNT(*) 
        FROM orders o2 
        WHERE o2.customer_id = o.customer_id
    ) as customer_total_orders
FROM orders o;
```

**Note:** This is a **correlated subquery** - it references the outer query (`o.customer_id`).

### Common Table Expressions (CTEs)

**CTEs** (WITH clauses) make complex queries more readable by breaking them into named parts.

**Syntax:**
```sql
WITH cte_name AS (
    SELECT ...
)
SELECT ... FROM cte_name;
```

**Example:** Find customers who spent more than average

```sql
WITH customer_totals AS (
    SELECT 
        customer_id,
        SUM(total_amount) as total_spent
    FROM orders
    GROUP BY customer_id
),
average_spending AS (
    SELECT AVG(total_spent) as avg_amount
    FROM customer_totals
)
SELECT 
    c.first_name || ' ' || c.last_name as customer_name,
    ct.total_spent
FROM customer_totals ct
INNER JOIN customers c ON ct.customer_id = c.id
CROSS JOIN average_spending av
WHERE ct.total_spent > av.avg_amount
ORDER BY ct.total_spent DESC;
```

**Benefits of CTEs:**
- ✅ More readable than nested subqueries
- ✅ Can reference the same CTE multiple times
- ✅ Easier to debug (test each CTE separately)

**Exercise 4:** Use a CTE to find products that have never been ordered.

<details>
<summary>Click for solution</summary>

```sql
WITH ordered_products AS (
    SELECT DISTINCT product_id
    FROM order_items
)
SELECT 
    p.id,
    p.name,
    p.category,
    p.price
FROM products p
LEFT JOIN ordered_products op ON p.id = op.product_id
WHERE op.product_id IS NULL;
```
</details>

### Recursive CTEs (Advanced)

**Recursive CTEs** can reference themselves - useful for hierarchical data.

**Example:** Generate a number series

```sql
WITH RECURSIVE numbers AS (
    SELECT 1 as n
    UNION ALL
    SELECT n + 1 FROM numbers WHERE n < 10
)
SELECT * FROM numbers;
```

**Real-world use:** Finding all managers in an employee hierarchy, traversing tree structures.

---

## Transactions and ACID Properties (20 minutes)

### What Is a Transaction?

A **transaction** is a sequence of database operations that are treated as a single unit. Either all operations succeed, or all fail.

**Real-world analogy:** Transferring money between bank accounts:
1. Debit $100 from Account A
2. Credit $100 to Account B

Both must succeed together, or both must fail together.

### ACID Properties

**ACID** stands for:
- **Atomicity:** All or nothing
- **Consistency:** Database remains valid
- **Isolation:** Transactions don't interfere
- **Durability:** Changes persist

### Basic Transaction Syntax

```sql
BEGIN;  -- Start transaction

-- Your SQL statements here
UPDATE accounts SET balance = balance - 100 WHERE id = 1;
UPDATE accounts SET balance = balance + 100 WHERE id = 2;

COMMIT;  -- Save changes (or ROLLBACK; to cancel)
```

### Practical Example: Processing an Order

Let's create a transaction that:
1. Creates an order
2. Adds order items
3. Updates product stock
4. Updates order total

```sql
BEGIN;

-- Step 1: Create order
INSERT INTO orders (customer_id, order_date, status)
VALUES (1, CURRENT_DATE, 'pending')
RETURNING id;  -- Get the new order ID

-- Let's say the returned ID is 6
-- Step 2: Add order items
INSERT INTO order_items (order_id, product_id, quantity, unit_price)
VALUES 
    (6, 1, 1, 999.99),  -- Laptop
    (6, 2, 2, 29.99);   -- 2x Mouse

-- Step 3: Update product stock
UPDATE products SET stock_quantity = stock_quantity - 1 WHERE id = 1;
UPDATE products SET stock_quantity = stock_quantity - 2 WHERE id = 2;

-- Step 4: Calculate and update order total
UPDATE orders 
SET total_amount = (
    SELECT SUM(subtotal) 
    FROM order_items 
    WHERE order_id = 6
)
WHERE id = 6;

-- Check everything looks good
SELECT * FROM orders WHERE id = 6;
SELECT * FROM order_items WHERE order_id = 6;
SELECT id, name, stock_quantity FROM products WHERE id IN (1, 2);

-- If everything looks good:
COMMIT;
-- OR if something's wrong:
-- ROLLBACK;
```

### Transaction Isolation Levels

PostgreSQL supports different isolation levels:

1. **Read Committed** (Default)
   - See only committed data
   - Most common, good for most cases

2. **Repeatable Read**
   - Same data throughout transaction
   - Prevents non-repeatable reads

3. **Serializable**
   - Strictest isolation
   - Prevents all anomalies

**Example:**

```sql
BEGIN TRANSACTION ISOLATION LEVEL REPEATABLE READ;

SELECT * FROM orders WHERE customer_id = 1;
-- ... do some work ...
SELECT * FROM orders WHERE customer_id = 1;
-- This will see the same data, even if other transactions modified it

COMMIT;
```

### Savepoints (Nested Transactions)

**Savepoints** allow you to rollback part of a transaction:

```sql
BEGIN;

INSERT INTO orders (customer_id) VALUES (1);
SAVEPOINT after_order;

INSERT INTO order_items (order_id, product_id, quantity, unit_price)
VALUES (LASTVAL(), 1, 1, 999.99);

-- Oops, made a mistake!
ROLLBACK TO SAVEPOINT after_order;

-- Order is still there, but order_items insert was rolled back
-- Continue with corrected code...

COMMIT;
```

**Exercise 5:** Create a transaction that:
1. Creates a new order for customer 2
2. Adds 2 products to the order
3. Updates stock quantities
4. If any product is out of stock, rollback everything

<details>
<summary>Click for solution</summary>

```sql
BEGIN;

-- Create order
INSERT INTO orders (customer_id, order_date, status)
VALUES (2, CURRENT_DATE, 'pending')
RETURNING id;

-- Check stock before adding items
DO $$
DECLARE
    order_id_val INTEGER;
    product1_stock INTEGER;
    product2_stock INTEGER;
BEGIN
    order_id_val := LASTVAL();
    
    -- Check stock
    SELECT stock_quantity INTO product1_stock FROM products WHERE id = 1;
    SELECT stock_quantity INTO product2_stock FROM products WHERE id = 2;
    
    IF product1_stock < 1 OR product2_stock < 2 THEN
        RAISE EXCEPTION 'Insufficient stock';
    END IF;
    
    -- Add items
    INSERT INTO order_items (order_id, product_id, quantity, unit_price)
    VALUES 
        (order_id_val, 1, 1, 999.99),
        (order_id_val, 2, 2, 29.99);
    
    -- Update stock
    UPDATE products SET stock_quantity = stock_quantity - 1 WHERE id = 1;
    UPDATE products SET stock_quantity = stock_quantity - 2 WHERE id = 2;
END $$;

-- Update order total
UPDATE orders 
SET total_amount = (
    SELECT SUM(subtotal) FROM order_items WHERE order_id = LASTVAL()
)
WHERE id = LASTVAL();

COMMIT;
```
</details>

### Common Transaction Patterns

**Pattern 1: Explicit Transaction**
```sql
BEGIN;
-- operations
COMMIT;
```

**Pattern 2: Auto-commit (Default)**
```sql
-- Each statement is its own transaction
UPDATE orders SET status = 'completed' WHERE id = 1;
```

**Pattern 3: Error Handling**
```sql
BEGIN;
-- operations
-- If error occurs, PostgreSQL automatically rolls back
COMMIT;
```

---

## Window Functions Basics (10 minutes)

### What Are Window Functions?

**Window functions** perform calculations across a set of rows related to the current row, without collapsing rows like GROUP BY does.

### Basic Syntax

```sql
SELECT 
    column1,
    column2,
    WINDOW_FUNCTION() OVER (PARTITION BY column ORDER BY column)
FROM table;
```

### Common Window Functions

#### 1. ROW_NUMBER()

Assigns a sequential number to each row:

```sql
SELECT 
    first_name || ' ' || last_name as customer_name,
    order_date,
    total_amount,
    ROW_NUMBER() OVER (ORDER BY order_date) as row_num
FROM orders o
INNER JOIN customers c ON o.customer_id = c.id;
```

#### 2. RANK() and DENSE_RANK()

Rank rows based on a value:

```sql
SELECT 
    first_name || ' ' || last_name as customer_name,
    total_amount,
    RANK() OVER (ORDER BY total_amount DESC) as rank,
    DENSE_RANK() OVER (ORDER BY total_amount DESC) as dense_rank
FROM orders o
INNER JOIN customers c ON o.customer_id = c.id;
```

**Difference:**
- **RANK():** Gaps in ranking (1, 2, 2, 4)
- **DENSE_RANK():** No gaps (1, 2, 2, 3)

#### 3. SUM() OVER (Running Total)

```sql
SELECT 
    order_date,
    total_amount,
    SUM(total_amount) OVER (ORDER BY order_date) as running_total
FROM orders
ORDER BY order_date;
```

#### 4. PARTITION BY

Calculate within groups:

```sql
SELECT 
    c.first_name || ' ' || c.last_name as customer_name,
    o.order_date,
    o.total_amount,
    SUM(o.total_amount) OVER (PARTITION BY o.customer_id ORDER BY o.order_date) as customer_running_total
FROM orders o
INNER JOIN customers c ON o.customer_id = c.id
ORDER BY o.customer_id, o.order_date;
```

**Exercise 6:** Use a window function to show each order with the average order amount for that customer.

<details>
<summary>Click for solution</summary>

```sql
SELECT 
    c.first_name || ' ' || c.last_name as customer_name,
    o.id as order_id,
    o.total_amount,
    AVG(o.total_amount) OVER (PARTITION BY o.customer_id) as customer_avg_order
FROM orders o
INNER JOIN customers c ON o.customer_id = c.id;
```
</details>

### When to Use Window Functions

✅ **Use window functions when:**
- You need to compare rows to other rows
- You want running totals or moving averages
- You need rankings without collapsing rows
- You want to see both detail and aggregate data

❌ **Don't use window functions when:**
- Simple GROUP BY is sufficient
- You only need totals, not per-row calculations

---

## Practical Exercise (5 minutes)

### Final Challenge

Write a comprehensive query that:

1. Shows all customers with their order statistics
2. Includes: customer name, total orders, total spent, average order amount
3. Shows their most recent order date
4. Ranks customers by total spent
5. Only includes customers who have placed at least one order

**Bonus:** Use CTEs to make it more readable.

<details>
<summary>Click for solution</summary>

```sql
WITH customer_stats AS (
    SELECT 
        c.id,
        c.first_name || ' ' || c.last_name as customer_name,
        COUNT(o.id) as total_orders,
        SUM(o.total_amount) as total_spent,
        AVG(o.total_amount) as avg_order_amount,
        MAX(o.order_date) as most_recent_order
    FROM customers c
    INNER JOIN orders o ON c.id = o.customer_id
    GROUP BY c.id, c.first_name, c.last_name
)
SELECT 
    customer_name,
    total_orders,
    total_spent,
    ROUND(avg_order_amount::numeric, 2) as avg_order_amount,
    most_recent_order,
    RANK() OVER (ORDER BY total_spent DESC) as spending_rank
FROM customer_stats
ORDER BY total_spent DESC;
```
</details>

---

## Summary

### Key Takeaways

1. **JOINs** combine data from multiple tables:
   - `INNER JOIN`: Matching rows only
   - `LEFT JOIN`: All left rows + matches
   - Use joins to avoid multiple queries

2. **Subqueries and CTEs** organize complex queries:
   - Subqueries: Simple nested queries
   - CTEs: More readable, reusable parts
   - Use CTEs for complex multi-step queries

3. **Transactions** ensure data integrity:
   - `BEGIN` / `COMMIT` / `ROLLBACK`
   - ACID properties guarantee consistency
   - Use for multi-step operations

4. **Window Functions** provide advanced analysis:
   - Calculate across rows without GROUP BY
   - Useful for rankings, running totals
   - `PARTITION BY` groups calculations

### Next Steps

1. Practice writing JOIN queries with your own data
2. Experiment with CTEs to refactor complex queries
3. Use transactions in your applications
4. Explore more window functions: `LAG()`, `LEAD()`, `FIRST_VALUE()`, `LAST_VALUE()`

### Additional Resources

- PostgreSQL Documentation: https://www.postgresql.org/docs/
- SQL Tutorial: https://www.postgresqltutorial.com/
- Practice on: https://www.hackerrank.com/domains/sql

---

## Quick Reference

### JOIN Syntax
```sql
SELECT * FROM table1
[INNER|LEFT|RIGHT|FULL] JOIN table2
ON table1.id = table2.foreign_id;
```

### CTE Syntax
```sql
WITH cte_name AS (
    SELECT ...
)
SELECT * FROM cte_name;
```

### Transaction Syntax
```sql
BEGIN;
-- SQL statements
COMMIT;  -- or ROLLBACK;
```

### Window Function Syntax
```sql
SELECT 
    column,
    FUNCTION() OVER (PARTITION BY col ORDER BY col)
FROM table;
```

---

**Congratulations!** You've completed the Intermediate PostgreSQL lesson. Keep practicing and building on these concepts! 🎉

