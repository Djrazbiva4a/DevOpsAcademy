# Exercise 4: Inserting and Querying Data

## Learning Objectives
- Insert data into tables using INSERT
- Query data using SELECT
- Filter data with WHERE clause
- Sort results with ORDER BY
- Limit results
- Understand basic SQL query structure

## What is SQL?

SQL (Structured Query Language) is the language we use to interact with databases. The main operations are:
- **INSERT** - Add new data
- **SELECT** - Retrieve data
- **UPDATE** - Modify existing data
- **DELETE** - Remove data

## Step-by-Step Instructions

### Step 1: Connect to Your Database

```bash
docker exec -it my-postgres psql -U postgres -d ecommerce
```

### Step 2: Prepare Tables

Let's create a simple table for practice:

```sql
CREATE TABLE customers (
    id SERIAL PRIMARY KEY,
    first_name VARCHAR(50) NOT NULL,
    last_name VARCHAR(50) NOT NULL,
    email VARCHAR(100) UNIQUE,
    age INTEGER,
    city VARCHAR(50)
);
```

### Step 3: Insert Single Row

Insert one customer:

```sql
INSERT INTO customers (first_name, last_name, email, age, city)
VALUES ('John', 'Doe', 'john.doe@email.com', 30, 'New York');
```

**Syntax Breakdown:**
- `INSERT INTO customers` - specifies the table
- `(first_name, last_name, ...)` - column names
- `VALUES (...)` - the actual data values
- Order of values must match order of columns

### Step 4: Insert Multiple Rows

Insert several customers at once:

```sql
INSERT INTO customers (first_name, last_name, email, age, city)
VALUES 
    ('Jane', 'Smith', 'jane.smith@email.com', 25, 'Los Angeles'),
    ('Bob', 'Johnson', 'bob.johnson@email.com', 35, 'Chicago'),
    ('Alice', 'Williams', 'alice.williams@email.com', 28, 'Houston'),
    ('Charlie', 'Brown', 'charlie.brown@email.com', 42, 'Phoenix');
```

### Step 5: Insert with Default Values

If a column has a default value or allows NULL, you can omit it:

```sql
INSERT INTO customers (first_name, last_name, email)
VALUES ('David', 'Lee', 'david.lee@email.com');
```

### Step 6: Query All Data

Retrieve all customers:

```sql
SELECT * FROM customers;
```

The `*` means "all columns". You should see all the customers you inserted.

### Step 7: Select Specific Columns

Get only specific columns:

```sql
SELECT first_name, last_name, email FROM customers;
```

### Step 8: Filter with WHERE

Find customers from a specific city:

```sql
SELECT * FROM customers WHERE city = 'New York';
```

### Step 9: Multiple Conditions

Use AND/OR for multiple conditions:

```sql
-- Customers older than 30
SELECT * FROM customers WHERE age > 30;

-- Customers from New York OR Los Angeles
SELECT * FROM customers WHERE city = 'New York' OR city = 'Los Angeles';

-- Customers older than 25 AND from Chicago
SELECT * FROM customers WHERE age > 25 AND city = 'Chicago';
```

### Step 10: Sort Results

Order results by a column:

```sql
-- Sort by age (ascending - youngest first)
SELECT * FROM customers ORDER BY age;

-- Sort by age (descending - oldest first)
SELECT * FROM customers ORDER BY age DESC;

-- Sort by multiple columns
SELECT * FROM customers ORDER BY city, last_name;
```

### Step 11: Limit Results

Get only the first few rows:

```sql
-- Get first 3 customers
SELECT * FROM customers LIMIT 3;

-- Get first 2 customers ordered by age
SELECT * FROM customers ORDER BY age LIMIT 2;
```

### Step 12: Count Records

Count how many records match:

```sql
-- Total number of customers
SELECT COUNT(*) FROM customers;

-- Count customers in a specific city
SELECT COUNT(*) FROM customers WHERE city = 'New York';
```

### Step 13: Search with LIKE

Find patterns in text:

```sql
-- Customers with email containing 'gmail'
SELECT * FROM customers WHERE email LIKE '%gmail%';

-- Customers with first name starting with 'J'
SELECT * FROM customers WHERE first_name LIKE 'J%';
```

**LIKE Patterns:**
- `%` - matches any sequence of characters
- `_` - matches a single character

## Common SELECT Patterns

### Aggregate Functions

```sql
-- Average age
SELECT AVG(age) FROM customers;

-- Maximum age
SELECT MAX(age) FROM customers;

-- Minimum age
SELECT MIN(age) FROM customers;

-- Sum of ages
SELECT SUM(age) FROM customers;
```

### Group By

Group results by a column:

```sql
-- Count customers per city
SELECT city, COUNT(*) 
FROM customers 
GROUP BY city;

-- Average age per city
SELECT city, AVG(age) 
FROM customers 
GROUP BY city;
```

### Distinct Values

Get unique values:

```sql
-- All unique cities
SELECT DISTINCT city FROM customers;
```

## Useful Commands

```sql
-- View all data
SELECT * FROM table_name;

-- Count rows
SELECT COUNT(*) FROM table_name;

-- Check if table has data
SELECT EXISTS(SELECT 1 FROM table_name);

-- View first few rows
SELECT * FROM table_name LIMIT 10;
```

## Practice Tasks

1. Insert 5 more customers with different cities and ages

2. Find all customers older than 30

3. Find customers whose last name starts with 'S'

4. List all unique cities in the database

5. Count how many customers are in each city

6. Find the oldest customer

7. Get the first name and email of customers from 'Los Angeles', ordered by last name

8. Insert a customer with only first_name and last_name (other fields should be NULL)

9. Find customers with NULL age values

10. Get the average age of all customers

## Key Concepts

- **INSERT**: Adds new rows to a table
- **SELECT**: Retrieves data from tables
- **WHERE**: Filters rows based on conditions
- **ORDER BY**: Sorts results
- **LIMIT**: Restricts number of rows returned
- **COUNT()**: Counts rows
- **LIKE**: Pattern matching in text
- **GROUP BY**: Groups rows for aggregation

## Common Issues

**Problem**: "duplicate key value violates unique constraint"
- **Solution**: You're trying to insert a value that already exists in a UNIQUE column (like email)

**Problem**: "null value in column violates not-null constraint"
- **Solution**: You're trying to insert NULL into a column marked as NOT NULL

**Problem**: "column does not exist"
- **Solution**: Check column name spelling - it's case-sensitive in some contexts

## Next Steps

Great! You can now add and retrieve data. In the next exercise, we'll learn about indexes and why they're crucial for database performance.

