# Exercise 2: Creating Your First Database

## Learning Objectives
- Understand what a database is in PostgreSQL
- Learn how to create a new database
- Connect to different databases
- List existing databases
- Understand the difference between databases and schemas

## What is a Database?

In PostgreSQL, a **database** is a collection of related data organized in a structured way. Think of it as a container that holds tables, views, functions, and other database objects.

**Key Points:**
- A PostgreSQL server can have multiple databases
- Each database is isolated from others
- You can only be connected to one database at a time
- Databases are useful for separating different applications or projects

## Step-by-Step Instructions

### Step 1: Start Your PostgreSQL Container

If your container isn't running, start it:

```bash
docker start my-postgres
```

### Step 2: Connect to PostgreSQL

Connect to PostgreSQL (this connects to the default database 'postgres'):

```bash
docker exec -it my-postgres psql -U postgres
```

### Step 3: List Existing Databases

Let's see what databases already exist:

```sql
\l
```

Or using SQL:

```sql
SELECT datname FROM pg_database;
```

You should see at least:
- `postgres` - the default database
- `mydb` - the database we created when starting the container
- `template0` and `template1` - system databases used as templates

### Step 4: Create a New Database

Let's create a database for a sample e-commerce application:

```sql
CREATE DATABASE ecommerce;
```

**Syntax Explanation:**
- `CREATE DATABASE` - the SQL command to create a database
- `ecommerce` - the name of the database (must be unique)

### Step 5: Verify Database Creation

List databases again to confirm:

```sql
\l
```

You should now see `ecommerce` in the list.

### Step 6: Connect to the New Database

To work with a specific database, you need to connect to it. Exit the current session:

```sql
\q
```

Then connect to the new database:

```bash
docker exec -it my-postgres psql -U postgres -d ecommerce
```

Notice the `-d ecommerce` parameter specifies which database to connect to.

### Step 7: Check Current Database

Verify you're connected to the correct database:

```sql
SELECT current_database();
```

This should return `ecommerce`.

### Step 8: Create Another Database with Options

Let's create a database with specific settings:

```sql
CREATE DATABASE testdb 
    WITH 
    OWNER = postgres
    ENCODING = 'UTF8'
    LC_COLLATE = 'en_US.utf8'
    LC_CTYPE = 'en_US.utf8';
```

**Options Explained:**
- `OWNER` - the user who owns the database
- `ENCODING` - character encoding (UTF8 is standard)
- `LC_COLLATE` - sorting rules
- `LC_CTYPE` - character classification

## Useful Commands

```sql
-- List all databases
\l

-- List databases with more details
\l+

-- Connect to a different database (from within psql)
\c database_name

-- Show current database
SELECT current_database();

-- Show current user
SELECT current_user;

-- Drop (delete) a database (be careful!)
DROP DATABASE database_name;
```

## Practice Tasks

1. Create a database called `school` for managing student records
2. Create a database called `library` with UTF8 encoding
3. List all databases and identify which ones you created
4. Connect to the `school` database
5. Try to drop the `testdb` database (you'll need to connect to a different database first, as you can't drop the database you're currently connected to)

## Understanding Database vs Schema

**Database**: A collection of schemas
**Schema**: A collection of tables, views, functions, etc. (default schema is `public`)

Think of it like:
- **Database** = A building
- **Schema** = A floor in the building
- **Table** = A room on that floor

We'll learn more about schemas in later exercises.

## Common Issues

**Problem**: "database already exists" error
- **Solution**: Choose a different name or drop the existing database first

**Problem**: Can't drop a database
- **Solution**: You can't drop a database you're connected to. Connect to a different database first (like `postgres`)

**Problem**: Permission denied
- **Solution**: Make sure you're connected as a user with CREATEDB privilege (postgres user has this by default)

## Key Concepts

- **CREATE DATABASE**: Creates a new database
- **DROP DATABASE**: Deletes a database (permanent!)
- **\l**: Lists all databases
- **\c**: Connects to a different database
- **current_database()**: Shows the database you're currently connected to

## Next Steps

Great! You now know how to create and manage databases. In the next exercise, we'll learn how to create tables to store your data.

