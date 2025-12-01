# Exercise 3: Creating Tables

## Learning Objectives
- Understand what a table is and its structure
- Learn about common PostgreSQL data types
- Create tables with columns and data types
- Add constraints to ensure data integrity
- View table structure

## What is a Table?

A **table** is a collection of related data organized in rows and columns. Think of it like a spreadsheet:
- **Columns** (fields) define what type of data is stored
- **Rows** (records) contain the actual data
- Each column has a **data type** that defines what kind of data it can store

## Common PostgreSQL Data Types

Before creating tables, let's understand common data types:

| Data Type | Description | Example |
|-----------|-------------|---------|
| `INTEGER` or `INT` | Whole numbers | 42, -10, 0 |
| `BIGINT` | Large whole numbers | 999999999 |
| `DECIMAL(p,s)` or `NUMERIC` | Exact decimal numbers | 19.99, 3.14159 |
| `VARCHAR(n)` | Variable-length text (max n characters) | 'Hello', 'PostgreSQL' |
| `TEXT` | Unlimited length text | Long descriptions |
| `BOOLEAN` | True or false | TRUE, FALSE |
| `DATE` | Date only | '2024-01-15' |
| `TIMESTAMP` | Date and time | '2024-01-15 10:30:00' |
| `UUID` | Universally unique identifier | '550e8400-e29b-41d4-a716-446655440000' |

## Step-by-Step Instructions

### Step 1: Connect to Your Database

Connect to the ecommerce database we created earlier:

```bash
docker exec -it my-postgres psql -U postgres -d ecommerce
```

### Step 2: Create Your First Table

Let's create a simple table to store customer information:

```sql
CREATE TABLE customers (
    id INTEGER,
    first_name VARCHAR(50),
    last_name VARCHAR(50),
    email VARCHAR(100),
    age INTEGER
);
```

**Syntax Breakdown:**
- `CREATE TABLE` - command to create a table
- `customers` - table name
- `id INTEGER` - column named 'id' that stores integers
- `first_name VARCHAR(50)` - column for first name, max 50 characters
- Each column is separated by a comma

### Step 3: View Table Structure

Let's see the structure of the table we just created:

```sql
\d customers
```

This shows:
- Column names
- Data types
- Whether columns allow NULL values
- Default values
- Constraints

### Step 4: Create a Table with Constraints

Constraints help ensure data quality. Let's create a better version with constraints:

```sql
CREATE TABLE products (
    id INTEGER PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    description TEXT,
    price DECIMAL(10, 2) NOT NULL,
    in_stock BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

**Constraints Explained:**
- `PRIMARY KEY` - uniquely identifies each row (like a unique ID)
- `NOT NULL` - column cannot be empty
- `DEFAULT` - value used if none is provided
- `CURRENT_TIMESTAMP` - automatically sets to current date/time

### Step 5: Create a Table with Foreign Key

A foreign key links tables together. Let's create an orders table:

```sql
CREATE TABLE orders (
    id INTEGER PRIMARY KEY,
    customer_id INTEGER,
    product_id INTEGER,
    quantity INTEGER NOT NULL,
    order_date DATE DEFAULT CURRENT_DATE,
    FOREIGN KEY (customer_id) REFERENCES customers(id),
    FOREIGN KEY (product_id) REFERENCES products(id)
);
```

**Foreign Key Explained:**
- Links `customer_id` to `customers(id)`
- Links `product_id` to `products(id)`
- Ensures data integrity - you can't reference a customer or product that doesn't exist

### Step 6: List All Tables

See all tables in the current database:

```sql
\dt
```

Or using SQL:

```sql
SELECT table_name 
FROM information_schema.tables 
WHERE table_schema = 'public';
```

### Step 7: View Detailed Table Information

Get more details about a table:

```sql
\d+ products
```

The `+` shows additional information like storage parameters.

## Common Table Patterns

### Auto-incrementing ID (SERIAL)

Instead of manually setting IDs, use SERIAL:

```sql
CREATE TABLE employees (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    department VARCHAR(50)
);
```

`SERIAL` automatically generates unique numbers: 1, 2, 3, 4...

### Table with Check Constraint

Ensure values meet certain conditions:

```sql
CREATE TABLE students (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    age INTEGER CHECK (age >= 0 AND age <= 120),
    grade CHAR(1) CHECK (grade IN ('A', 'B', 'C', 'D', 'F'))
);
```

## Useful Commands

```sql
-- List all tables
\dt

-- Describe table structure
\d table_name

-- Describe table with details
\d+ table_name

-- List all columns in a table
SELECT column_name, data_type 
FROM information_schema.columns 
WHERE table_name = 'customers';

-- Rename a table
ALTER TABLE old_name RENAME TO new_name;

-- Add a column
ALTER TABLE customers ADD COLUMN phone VARCHAR(20);

-- Drop a column
ALTER TABLE customers DROP COLUMN phone;

-- Change column type
ALTER TABLE customers ALTER COLUMN age TYPE SMALLINT;
```

## Practice Tasks

1. Create a `books` table with:
   - `id` (SERIAL PRIMARY KEY)
   - `title` (VARCHAR, NOT NULL)
   - `author` (VARCHAR, NOT NULL)
   - `isbn` (VARCHAR, unique)
   - `price` (DECIMAL)
   - `published_date` (DATE)

2. Create a `authors` table with:
   - `id` (SERIAL PRIMARY KEY)
   - `first_name` (VARCHAR)
   - `last_name` (VARCHAR)
   - `birth_date` (DATE)
   - `nationality` (VARCHAR)

3. Modify the `books` table to add a foreign key linking to `authors`

4. Use `\d books` to view the final structure

5. List all tables in your database

## Key Concepts

- **Table**: Collection of rows and columns
- **Column**: A field in a table with a specific data type
- **Data Type**: Defines what kind of data a column can store
- **PRIMARY KEY**: Uniquely identifies each row
- **FOREIGN KEY**: Links data between tables
- **NOT NULL**: Prevents empty values
- **DEFAULT**: Provides a default value
- **SERIAL**: Auto-incrementing integer

## Common Issues

**Problem**: "relation already exists" error
- **Solution**: Table name already exists. Choose a different name or drop the existing table first

**Problem**: Foreign key constraint fails
- **Solution**: Make sure the referenced table and column exist first

**Problem**: Invalid data type
- **Solution**: Check PostgreSQL documentation for correct data type names

## Next Steps

Excellent! You can now create tables. In the next exercise, we'll learn how to insert data into tables and query it back.

