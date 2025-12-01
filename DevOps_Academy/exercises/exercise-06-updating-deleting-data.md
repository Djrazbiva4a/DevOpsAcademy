# Exercise 6: Updating and Deleting Data

## Learning Objectives
- Update existing data using UPDATE
- Delete data using DELETE
- Understand the difference between DELETE and TRUNCATE
- Use WHERE clauses to target specific rows
- Understand transaction safety

## Modifying Data

So far we've learned to:
- **INSERT** - Add new data
- **SELECT** - Read data

Now we'll learn to:
- **UPDATE** - Modify existing data
- **DELETE** - Remove data

⚠️ **Important**: Always use WHERE clauses! Without them, you'll update/delete ALL rows!

## Step-by-Step Instructions

### Step 1: Connect to Database

```bash
docker exec -it my-postgres psql -U postgres -d ecommerce
```

### Step 2: Prepare Test Data

Let's create and populate a table:

```sql
CREATE TABLE employees (
    id SERIAL PRIMARY KEY,
    first_name VARCHAR(50),
    last_name VARCHAR(50),
    email VARCHAR(100),
    department VARCHAR(50),
    salary DECIMAL(10, 2),
    hire_date DATE
);

INSERT INTO employees (first_name, last_name, email, department, salary, hire_date)
VALUES 
    ('John', 'Doe', 'john.doe@company.com', 'Engineering', 75000, '2020-01-15'),
    ('Jane', 'Smith', 'jane.smith@company.com', 'Marketing', 65000, '2021-03-20'),
    ('Bob', 'Johnson', 'bob.johnson@company.com', 'Engineering', 80000, '2019-06-10'),
    ('Alice', 'Williams', 'alice.williams@company.com', 'Sales', 70000, '2022-01-05'),
    ('Charlie', 'Brown', 'charlie.brown@company.com', 'Engineering', 72000, '2021-11-30');
```

### Step 3: View Current Data

```sql
SELECT * FROM employees;
```

### Step 4: Update a Single Row

Update John's salary:

```sql
UPDATE employees
SET salary = 80000
WHERE id = 1;
```

**Syntax:**
- `UPDATE employees` - table to update
- `SET salary = 80000` - column and new value
- `WHERE id = 1` - condition to identify the row

Verify the change:
```sql
SELECT * FROM employees WHERE id = 1;
```

### Step 5: Update Multiple Columns

Update multiple columns at once:

```sql
UPDATE employees
SET salary = 85000,
    department = 'Senior Engineering'
WHERE id = 1;
```

### Step 6: Update Multiple Rows

Give all Engineering employees a raise:

```sql
UPDATE employees
SET salary = salary * 1.1
WHERE department = 'Engineering';
```

This increases salary by 10% for all Engineering employees.

### Step 7: Update with Conditions

Update based on multiple conditions:

```sql
UPDATE employees
SET salary = salary + 5000
WHERE department = 'Sales' AND salary < 75000;
```

This gives a $5000 raise to Sales employees earning less than $75,000.

### Step 8: Update Using Subquery

Update based on data from another query:

```sql
-- First, let's see what we're working with
SELECT * FROM employees ORDER BY salary;

-- Update the lowest paid employee
UPDATE employees
SET salary = salary + 10000
WHERE salary = (SELECT MIN(salary) FROM employees);
```

### Step 9: Delete a Single Row

Delete a specific employee:

```sql
DELETE FROM employees
WHERE id = 5;
```

**Syntax:**
- `DELETE FROM employees` - table to delete from
- `WHERE id = 5` - condition to identify the row

⚠️ **Warning**: This permanently removes the row!

### Step 10: Delete Multiple Rows

Delete all employees in a department:

```sql
DELETE FROM employees
WHERE department = 'Marketing';
```

### Step 11: Delete with Conditions

Delete employees based on criteria:

```sql
DELETE FROM employees
WHERE salary < 70000 AND department = 'Sales';
```

### Step 12: Delete All Rows (Dangerous!)

```sql
-- ⚠️ DANGER: This deletes ALL rows!
DELETE FROM employees;
```

**Never run this without a WHERE clause unless you really want to delete everything!**

### Step 13: TRUNCATE vs DELETE

`TRUNCATE` is faster for deleting all rows:

```sql
-- Delete all rows (faster than DELETE)
TRUNCATE TABLE employees;
```

**Differences:**
- `TRUNCATE` - Faster, resets auto-increment, can't use WHERE
- `DELETE` - Slower, keeps auto-increment, can use WHERE

### Step 14: Safe Updates with Transactions

Use transactions to test changes safely:

```sql
-- Start a transaction
BEGIN;

-- Make your changes
UPDATE employees SET salary = 90000 WHERE id = 1;

-- Check the result
SELECT * FROM employees WHERE id = 1;

-- If you like it, commit (save)
COMMIT;

-- If you don't like it, rollback (undo)
-- ROLLBACK;
```

## Common Update Patterns

### Increment/Decrement Values

```sql
-- Increase by fixed amount
UPDATE products SET price = price + 10 WHERE id = 1;

-- Decrease by percentage
UPDATE products SET price = price * 0.9 WHERE id = 1;
```

### Update Based on Current Value

```sql
-- Set to a calculated value
UPDATE employees 
SET salary = salary * 1.05 
WHERE department = 'Engineering';
```

### Update with CASE Statement

```sql
UPDATE employees
SET salary = CASE
    WHEN department = 'Engineering' THEN salary * 1.1
    WHEN department = 'Sales' THEN salary * 1.05
    ELSE salary * 1.02
END;
```

## Useful Commands

```sql
-- Update single row
UPDATE table_name SET column = value WHERE id = 1;

-- Update multiple columns
UPDATE table_name 
SET col1 = val1, col2 = val2 
WHERE condition;

-- Update multiple rows
UPDATE table_name SET column = value WHERE condition;

-- Delete specific rows
DELETE FROM table_name WHERE condition;

-- Delete all rows (slow)
DELETE FROM table_name;

-- Delete all rows (fast)
TRUNCATE TABLE table_name;

-- Start transaction
BEGIN;

-- Commit transaction
COMMIT;

-- Rollback transaction
ROLLBACK;
```

## Practice Tasks

1. Update Jane's department to 'Senior Marketing'

2. Give all employees a 5% salary increase

3. Update employees hired before 2021 to have a salary increase of $3000

4. Delete the employee with id = 3

5. Delete all employees in the 'Sales' department

6. Use a transaction to:
   - Update an employee's salary
   - Check the result
   - Rollback the change
   - Verify the original value is restored

7. Update employees' emails to lowercase:
   ```sql
   UPDATE employees SET email = LOWER(email);
   ```

8. Delete employees with salary less than 70000

9. Update the hire_date for all employees to add 1 year (research DATE functions)

10. Practice safe deletion: Use SELECT first to see what will be deleted:
    ```sql
    -- First, see what will be deleted
    SELECT * FROM employees WHERE condition;
    
    -- Then delete
    DELETE FROM employees WHERE condition;
    ```

## Safety Best Practices

### 1. Always Use WHERE (Unless You Mean It!)

```sql
-- ❌ BAD - Updates everything!
UPDATE employees SET salary = 100000;

-- ✅ GOOD - Updates specific rows
UPDATE employees SET salary = 100000 WHERE id = 1;
```

### 2. Test with SELECT First

```sql
-- See what will be updated
SELECT * FROM employees WHERE department = 'Engineering';

-- Then update
UPDATE employees SET salary = salary * 1.1 WHERE department = 'Engineering';
```

### 3. Use Transactions for Important Changes

```sql
BEGIN;
UPDATE employees SET salary = 100000 WHERE id = 1;
-- Review the change
SELECT * FROM employees WHERE id = 1;
-- If good: COMMIT; If bad: ROLLBACK;
```

### 4. Backup Before Major Changes

Always backup your data before running UPDATE or DELETE on production!

## Key Concepts

- **UPDATE**: Modifies existing rows
- **DELETE**: Removes rows
- **WHERE**: Essential for targeting specific rows
- **SET**: Specifies new values in UPDATE
- **TRUNCATE**: Fast way to delete all rows
- **Transaction**: Group operations that can be committed or rolled back
- **Safety**: Always test with SELECT first!

## Common Issues

**Problem**: Updated/deleted too many rows
- **Solution**: Use transactions (BEGIN/ROLLBACK) to undo, or restore from backup

**Problem**: "0 rows affected" message
- **Solution**: Check your WHERE condition - it might not match any rows

**Problem**: Can't delete row due to foreign key constraint
- **Solution**: Delete related rows first, or update the foreign key references

## Next Steps

Great! You can now modify and delete data safely. In the next exercise, we'll learn how to drop tables and manage database schema.

