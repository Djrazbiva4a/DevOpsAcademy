# Exercise 8: Creating Users and Managing Permissions

## Learning Objectives
- Understand the difference between users and roles in PostgreSQL
- Create new database users
- Grant and revoke permissions
- Understand different privilege levels
- Create roles for managing groups of users
- Understand security best practices

## Users and Roles in PostgreSQL

In PostgreSQL, **users** and **roles** are essentially the same thing. A role can:
- Log in to the database (then it's called a "user")
- Own database objects
- Have privileges (permissions)

**Key Concepts:**
- **Superuser**: Has all privileges (like the `postgres` user)
- **Regular User**: Limited privileges, needs explicit permissions
- **Role**: Can be assigned to multiple users for easier permission management

## Why Create Users?

- **Security**: Limit access to only what's needed
- **Multi-user environments**: Different people need different access
- **Application access**: Applications should use dedicated users, not superuser
- **Audit trail**: Track who did what

## Step-by-Step Instructions

### Step 1: Connect as Superuser

```bash
docker exec -it my-postgres psql -U postgres -d postgres
```

### Step 2: List Existing Users/Roles

See all users in the system:

```sql
\du
```

Or using SQL:

```sql
SELECT usename FROM pg_user;
```

You should see at least the `postgres` user.

### Step 3: Create a New User

Create a user for a developer:

```sql
CREATE USER developer WITH PASSWORD 'devpassword123';
```

**Syntax:**
- `CREATE USER` - creates a new user (same as `CREATE ROLE ... WITH LOGIN`)
- `developer` - username
- `WITH PASSWORD` - sets the password

### Step 4: Verify User Creation

```sql
\du
```

You should see the new `developer` user.

### Step 5: Test User Connection

Try connecting as the new user:

```bash
docker exec -it my-postgres psql -U developer -d postgres
```

You'll be able to connect, but you won't have many permissions yet.

### Step 6: Try to Create a Database (Will Fail)

While connected as `developer`, try:

```sql
CREATE DATABASE testdb;
```

This will fail with a permission error because `developer` doesn't have the `CREATEDB` privilege.

Exit and reconnect as postgres:
```sql
\q
```

```bash
docker exec -it my-postgres psql -U postgres -d postgres
```

### Step 7: Grant Privileges

Give the developer permission to create databases:

```sql
ALTER USER developer WITH CREATEDB;
```

Or grant specific privileges:

```sql
GRANT CREATE ON DATABASE postgres TO developer;
```

### Step 8: Grant Table Permissions

Let's create a table and grant permissions:

```sql
-- Connect to ecommerce database
\c ecommerce

-- Create a table
CREATE TABLE products (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100),
    price DECIMAL(10, 2)
);

-- Grant SELECT permission (read-only)
GRANT SELECT ON products TO developer;

-- Grant all permissions
GRANT ALL PRIVILEGES ON products TO developer;
```

### Step 9: Test Permissions

Connect as developer and test:

```bash
docker exec -it my-postgres psql -U developer -d ecommerce
```

```sql
-- This should work (SELECT granted)
SELECT * FROM products;

-- Try to insert (may fail if only SELECT was granted)
INSERT INTO products (name, price) VALUES ('Test', 10.00);
```

### Step 10: Grant Schema Permissions

Grant permissions on all tables in a schema:

```sql
-- As postgres user
\c ecommerce

-- Grant all privileges on all tables in public schema
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO developer;

-- Grant privileges on future tables too
ALTER DEFAULT PRIVILEGES IN SCHEMA public 
    GRANT ALL ON TABLES TO developer;
```

### Step 11: Create a Role for Groups

Create a role that multiple users can share:

```sql
-- Create a role
CREATE ROLE app_readonly;

-- Grant SELECT on all tables
GRANT SELECT ON ALL TABLES IN SCHEMA public TO app_readonly;

-- Create users and assign them to the role
CREATE USER app_user1 WITH PASSWORD 'pass1';
CREATE USER app_user2 WITH PASSWORD 'pass2';

-- Grant the role to users
GRANT app_readonly TO app_user1;
GRANT app_readonly TO app_user2;
```

Now both `app_user1` and `app_user2` have read-only access.

### Step 12: Revoke Permissions

Remove permissions:

```sql
-- Revoke specific permission
REVOKE INSERT ON products FROM developer;

-- Revoke all permissions
REVOKE ALL PRIVILEGES ON products FROM developer;
```

### Step 13: View User Permissions

See what permissions a user has:

```sql
-- List all privileges
SELECT 
    grantee, 
    table_schema, 
    table_name, 
    privilege_type
FROM information_schema.role_table_grants
WHERE grantee = 'developer';
```

## Common Privileges

### Database-Level Privileges

```sql
-- Allow user to create databases
ALTER USER username WITH CREATEDB;

-- Allow user to create roles
ALTER USER username WITH CREATEROLE;

-- Make user a superuser (dangerous!)
ALTER USER username WITH SUPERUSER;
```

### Table-Level Privileges

```sql
-- Read data
GRANT SELECT ON table_name TO username;

-- Insert data
GRANT INSERT ON table_name TO username;

-- Update data
GRANT UPDATE ON table_name TO username;

-- Delete data
GRANT DELETE ON table_name TO username;

-- All operations
GRANT ALL PRIVILEGES ON table_name TO username;
```

### Column-Level Privileges

Grant permissions on specific columns:

```sql
-- Allow SELECT on specific columns only
GRANT SELECT (name, price) ON products TO developer;

-- Allow UPDATE on specific columns
GRANT UPDATE (price) ON products TO developer;
```

## Best Practices

### 1. Principle of Least Privilege

Give users only the minimum permissions they need:

```sql
-- ✅ GOOD: Only what's needed
GRANT SELECT ON products TO app_user;

-- ❌ BAD: Too much access
GRANT ALL PRIVILEGES ON DATABASE mydb TO app_user;
```

### 2. Use Roles for Groups

Instead of granting to each user individually:

```sql
-- Create role
CREATE ROLE sales_team;

-- Grant to role
GRANT SELECT, INSERT ON orders TO sales_team;

-- Assign users to role
GRANT sales_team TO user1, user2, user3;
```

### 3. Application Users

Applications should have dedicated users with limited privileges:

```sql
CREATE USER myapp WITH PASSWORD 'secure_password';
GRANT SELECT, INSERT, UPDATE ON ALL TABLES IN SCHEMA public TO myapp;
```

### 4. Read-Only Users

For reporting/analytics:

```sql
CREATE USER readonly_user WITH PASSWORD 'readonly_pass';
GRANT SELECT ON ALL TABLES IN SCHEMA public TO readonly_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA public 
    GRANT SELECT ON TABLES TO readonly_user;
```

## Useful Commands

```sql
-- List all users
\du

-- Create user
CREATE USER username WITH PASSWORD 'password';

-- Create role
CREATE ROLE role_name;

-- Grant privileges
GRANT privilege ON object TO user;

-- Revoke privileges
REVOKE privilege ON object FROM user;

-- Alter user
ALTER USER username WITH option;

-- Grant role to user
GRANT role_name TO username;

-- View permissions
\dp table_name

-- View user permissions
SELECT * FROM information_schema.role_table_grants 
WHERE grantee = 'username';
```

## Practice Tasks

1. Create a user called `analyst` with password `analyst123`

2. Grant the analyst SELECT permission on all tables in the ecommerce database

3. Create a role called `readonly` and grant it SELECT on all tables

4. Create two users and assign them to the `readonly` role

5. Connect as one of the readonly users and try to SELECT from a table (should work)

6. Try to INSERT as the readonly user (should fail)

7. Create a user `app_user` and grant it SELECT, INSERT, and UPDATE on a specific table

8. Revoke UPDATE permission from `app_user`

9. View all permissions for a specific user

10. Create a user with CREATEDB privilege and verify they can create databases

## Key Concepts

- **User/Role**: Can log in and have permissions
- **Superuser**: Has all privileges (postgres user)
- **GRANT**: Gives permissions
- **REVOKE**: Removes permissions
- **Role**: Can be assigned to multiple users
- **Principle of Least Privilege**: Give minimum necessary permissions
- **Schema**: Container for database objects (default is 'public')

## Common Issues

**Problem**: "permission denied" error
- **Solution**: User doesn't have the required privilege. Grant it with GRANT command.

**Problem**: User can't connect
- **Solution**: Check if user exists and password is correct. Verify pg_hba.conf settings.

**Problem**: User can't see tables
- **Solution**: Grant USAGE on schema: `GRANT USAGE ON SCHEMA public TO username;`

**Problem**: Permissions not working on new tables
- **Solution**: Use `ALTER DEFAULT PRIVILEGES` to set permissions for future objects

## Security Considerations

- **Strong Passwords**: Always use strong, unique passwords
- **Limit Superusers**: Very few users should be superusers
- **Regular Audits**: Review user permissions regularly
- **Application Users**: Use dedicated users for applications, not personal accounts
- **Network Security**: Use SSL connections in production

## Next Steps

Great! You now understand user management and permissions. In the next exercise, we'll learn about VACUUM operations and database maintenance.

