# Lesson 1: PostgreSQL Fundamentals - Understanding the Database Structure

## Learning Objectives

By the end of this lesson, you will understand:
- What database files are and where they're located
- Different types of backups and how they're taken
- What a user is in PostgreSQL
- What a schema is
- What a database directory is
- Where database files are stored and what they contain
- Where logs are located
- Where configuration files are
- What a table is
- How user activity is logged
- What a tablespace is
- How to create users with different ownerships and test permissions

---

## Part 1: Understanding Database Files

### What Are Database Files?

Database files are the physical storage where PostgreSQL stores all your data. Every table, index, and database object is stored as files on disk.

### Where Are Database Files Located?

In our Docker setup, all database files are stored in:
```
/var/lib/postgresql/data/
```

This is the **data directory** - the heart of your PostgreSQL installation.

### Exploring the Database Directory Structure

Let's explore the actual files in your database:

```bash
# Connect to PostgreSQL and find the data directory
docker exec my-postgres psql -U postgres -c "SHOW data_directory;"
```

You should see: `/var/lib/postgresql/data`

Now let's see what's inside:

```bash
# List all directories and files in the data directory
docker exec my-postgres ls -la /var/lib/postgresql/data/
```

### Key Directories Explained

| Directory | Purpose | What's Inside |
|-----------|---------|---------------|
| `base/` | **Database files** | One subdirectory per database (named by OID) containing all table and index files |
| `global/` | **Cluster-wide data** | System catalogs shared across all databases |
| `pg_wal/` | **Write-Ahead Log** | Transaction log files (WAL) - records all changes |
| `pg_xact/` | **Transaction status** | Commit status for transactions |
| `pg_multixact/` | **Multi-transaction data** | Information about multi-transaction locks |
| `pg_subtrans/` | **Subtransaction data** | Subtransaction status information |
| `pg_twophase/` | **Two-phase commit** | State files for prepared transactions |
| `pg_commit_ts/` | **Commit timestamps** | Transaction commit timestamps |
| `pg_logical/` | **Logical replication** | Data for logical decoding |
| `pg_replslot/` | **Replication slots** | Replication slot data |
| `pg_stat/` | **Statistics** | Permanent statistics files |
| `pg_stat_tmp/` | **Temporary statistics** | Temporary statistics files |
| `pg_snapshots/` | **Snapshots** | Exported snapshots |
| `pg_serial/` | **Serializable transactions** | Serializable transaction information |
| `pg_tblspc/` | **Tablespaces** | Symbolic links to tablespace directories |
| `pg_notify/` | **Notifications** | LISTEN/NOTIFY status files |

### Finding Your Database Files

Each database has its own subdirectory in `base/` named after its Object ID (OID):

```bash
# Find database OIDs and their file locations
docker exec my-postgres psql -U postgres -c "
SELECT 
    datname as database_name,
    oid as database_oid,
    '/var/lib/postgresql/data/base/' || oid as file_location,
    pg_size_pretty(pg_database_size(datname)) as size
FROM pg_database
ORDER BY oid;"
```

**Example Output:**
```
 database_name | database_oid | file_location                          |  size   
---------------+--------------+----------------------------------------+---------
 template1     |            1 | /var/lib/postgresql/data/base/1       | 7557 kB
 template0     |            4 | /var/lib/postgresql/data/base/4       | 7329 kB
 postgres      |            5 | /var/lib/postgresql/data/base/5       | 7485 kB
 mydb          |        16384 | /var/lib/postgresql/data/base/16384   | 7485 kB
```

### What Files Are Inside a Database Directory?

Let's look at the actual files in a database directory:

```bash
# List files in your mydb database directory
docker exec my-postgres bash -c "ls -lh /var/lib/postgresql/data/base/16384/ | head -20"
```

You'll see files like:
- `11874` - System catalog files
- `11875` - More system files
- Numbers like `16385`, `16386` - These are your tables and indexes!

Each table and index gets a file number (called a "relfilenode"). Let's see which files belong to which tables:

```bash
# Connect and see table file mappings
docker exec my-postgres psql -U postgres -d mydb -c "
SELECT 
    schemaname,
    tablename,
    pg_relation_filepath(schemaname||'.'||tablename) as filepath,
    pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) as size
FROM pg_tables
WHERE schemaname = 'public'
ORDER BY tablename;"
```

**Note**: If you haven't created tables yet, you won't see any user tables, only system tables.

---

## Part 2: Understanding Backups

### What is a Backup?

A backup is a copy of your database that you can use to restore data if something goes wrong. Think of it as insurance for your data.

### Types of Backups in PostgreSQL

#### 1. **SQL Dump (pg_dump)** - Most Common

Creates a text file with SQL commands to recreate your database.

**Advantages:**
- Human-readable (you can open and read it)
- Portable (works across PostgreSQL versions)
- Can restore specific tables
- Can edit before restoring

**How to create:**
```bash
# Backup a single database
docker exec my-postgres pg_dump -U postgres -d mydb > mydb_backup.sql

# Backup all databases
docker exec my-postgres pg_dumpall -U postgres > all_databases_backup.sql

# Backup only schema (structure, no data)
docker exec my-postgres pg_dump -U postgres -d mydb --schema-only > schema.sql

# Backup only data (no structure)
docker exec my-postgres pg_dump -U postgres -d mydb --data-only > data.sql
```

**How to restore:**
```bash
# Restore from SQL dump
docker exec -i my-postgres psql -U postgres -d mydb < mydb_backup.sql
```

#### 2. **Custom Format (pg_dump -Fc)** - Compressed

Creates a compressed, binary-format backup.

**Advantages:**
- Smaller file size (compressed)
- Faster backup/restore
- Can restore specific objects
- Can restore in parallel

**How to create:**
```bash
# Create custom format backup
docker exec my-postgres pg_dump -U postgres -d mydb -Fc -f /tmp/mydb_backup.dump

# Copy to host
docker cp my-postgres:/tmp/mydb_backup.dump ./mydb_backup.dump
```

**How to restore:**
```bash
# Copy back to container
docker cp mydb_backup.dump my-postgres:/tmp/

# Restore using pg_restore
docker exec my-postgres pg_restore -U postgres -d mydb -c /tmp/mydb_backup.dump
```

#### 3. **File System Backup (pg_basebackup)** - Physical Copy

Creates a complete copy of all database files.

**Advantages:**
- Fastest backup method
- Exact copy of files
- Can be used for replication

**Disadvantages:**
- Requires database to be running
- Larger backup size
- Less flexible than SQL dumps

**How to create:**
```bash
# Create base backup
docker exec my-postgres pg_basebackup -U postgres -D /tmp/base_backup -Ft -z -P
```

#### 4. **Continuous Archiving (WAL Archiving)** - Point-in-Time Recovery

Saves Write-Ahead Log (WAL) files continuously for point-in-time recovery.

**Advantages:**
- Can recover to any point in time
- Minimal data loss
- Continuous protection

**How it works:**
- Base backup + WAL files = recover to any time
- Requires configuration (see Exercise 10 for details)

### Backup Comparison Table

| Backup Type | Command | Format | Size | Speed | Use Case |
|------------|---------|--------|------|-------|----------|
| SQL Dump | `pg_dump` | Text SQL | Large | Medium | General purpose, portable |
| Custom Format | `pg_dump -Fc` | Binary | Medium | Fast | Production backups |
| File System | `pg_basebackup` | Binary files | Large | Very Fast | Full server backup |
| WAL Archiving | `archive_mode` | WAL files | Small (incremental) | Continuous | Point-in-time recovery |

### Practical Backup Exercise

Let's create a database, add data, and practice backups:

```bash
# Connect to PostgreSQL
docker exec -it my-postgres psql -U postgres
```

```sql
-- Create a test database
CREATE DATABASE backup_test;

-- Connect to it
\c backup_test

-- Create a table
CREATE TABLE employees (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100),
    department VARCHAR(50),
    salary DECIMAL(10, 2)
);

-- Insert some data
INSERT INTO employees (name, department, salary) VALUES
    ('Alice Johnson', 'Engineering', 75000),
    ('Bob Smith', 'Marketing', 65000),
    ('Carol White', 'Engineering', 80000);

-- Verify data
SELECT * FROM employees;
```

Now let's create different types of backups:

```sql
\q
```

```bash
# 1. SQL Dump backup
docker exec my-postgres pg_dump -U postgres -d backup_test > backup_test.sql

# 2. Custom format backup
docker exec my-postgres pg_dump -U postgres -d backup_test -Fc -f /tmp/backup_test.dump
docker cp my-postgres:/tmp/backup_test.dump ./backup_test.dump

# View the SQL backup
head -30 backup_test.sql

# List backup files
ls -lh backup_test.*
```

---

## Part 3: Understanding Users

### What is a User in PostgreSQL?

A **user** (also called a "role" with login capability) is an account that can connect to PostgreSQL and perform actions based on their permissions.

### Key Concepts

- **Superuser**: Has all privileges (like `postgres` user)
- **Regular User**: Limited privileges, needs explicit permissions
- **Role**: Can be assigned to multiple users for easier management
- **User = Role with LOGIN**: In PostgreSQL, users and roles are the same thing

### Viewing Users

```bash
# Connect to PostgreSQL
docker exec -it my-postgres psql -U postgres
```

```sql
-- List all users/roles
\du

-- Or using SQL
SELECT 
    usename as username,
    usesuper as is_superuser,
    usecreatedb as can_create_db
FROM pg_user;

-- More detailed view
SELECT 
    rolname as role_name,
    rolsuper as is_superuser,
    rolcreaterole as can_create_roles,
    rolcreatedb as can_create_db,
    rolcanlogin as can_login
FROM pg_roles;
```

### Creating Users

```sql
-- Create a basic user
CREATE USER alice WITH PASSWORD 'password123';

-- Create user with specific privileges
CREATE USER bob WITH 
    PASSWORD 'password123'
    CREATEDB
    CREATEROLE;

-- Create a role (without login)
CREATE ROLE readonly_role;

-- Grant login to a role (making it a user)
ALTER ROLE readonly_role WITH LOGIN;
```

### User Permissions

Users can have different privileges:
- `LOGIN` - Can connect to database
- `CREATEDB` - Can create databases
- `CREATEROLE` - Can create other users/roles
- `SUPERUSER` - Has all privileges (dangerous!)
- `REPLICATION` - Can replicate data

---

## Part 4: Understanding Schemas

### What is a Schema?

A **schema** is a namespace that contains database objects (tables, views, functions, etc.). Think of it as a folder that organizes your database objects.

### Key Concepts

- **Default Schema**: `public` - where your tables go by default
- **Multiple Schemas**: You can have many schemas in one database
- **Schema = Namespace**: Prevents naming conflicts
- **Schema Search Path**: PostgreSQL looks in schemas in order

### Understanding Schema Structure

```
Database (mydb)
├── Schema: public
│   ├── Table: customers
│   ├── Table: orders
│   └── View: sales_summary
├── Schema: hr
│   ├── Table: employees
│   └── Table: departments
└── Schema: finance
    ├── Table: transactions
    └── Function: calculate_tax
```

### Viewing Schemas

```sql
-- List all schemas
\dn

-- Or using SQL
SELECT schema_name 
FROM information_schema.schemata
WHERE schema_name NOT IN ('pg_catalog', 'information_schema', 'pg_toast');

-- Show current schema
SHOW search_path;

-- Show all objects in a schema
\dt public.*
```

### Creating and Using Schemas

```sql
-- Create a new schema
CREATE SCHEMA hr;

-- Create a table in a specific schema
CREATE TABLE hr.employees (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100)
);

-- Set search path (where PostgreSQL looks for objects)
SET search_path TO hr, public;

-- Now you can reference tables without schema prefix
SELECT * FROM employees;  -- Looks in hr schema first

-- Create schema with owner
CREATE SCHEMA finance AUTHORIZATION alice;
```

### Practical Schema Exercise

```sql
-- Create multiple schemas
CREATE SCHEMA sales;
CREATE SCHEMA inventory;

-- Create tables in different schemas
CREATE TABLE sales.customers (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100)
);

CREATE TABLE inventory.products (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100),
    price DECIMAL(10, 2)
);

-- View tables in each schema
\dt sales.*
\dt inventory.*

-- Query across schemas
SELECT * FROM sales.customers;
SELECT * FROM inventory.products;
```

---

## Part 5: Understanding Tables

### What is a Table?

A **table** is a collection of related data organized in rows and columns. It's the fundamental storage structure in a relational database.

### Table Structure

```
Table: employees
┌────┬──────────────┬─────────────┬────────┐
│ id │ name         │ department  │ salary │
├────┼──────────────┼─────────────┼────────┤
│  1 │ Alice        │ Engineering │ 75000  │
│  2 │ Bob          │ Marketing   │ 65000  │
│  3 │ Carol        │ Engineering │ 80000  │
└────┴──────────────┴─────────────┴────────┘
```

- **Rows** (tuples): Individual records
- **Columns** (attributes): Data fields
- **Primary Key**: Unique identifier (like `id`)

### Viewing Tables

```sql
-- List all tables in current database
\dt

-- List tables with more details
\dt+

-- List tables in all schemas
\dt *.*

-- Using SQL
SELECT 
    schemaname,
    tablename,
    tableowner
FROM pg_tables
WHERE schemaname NOT IN ('pg_catalog', 'information_schema')
ORDER BY schemaname, tablename;
```

### Table Files on Disk

Each table is stored as one or more files in the database directory:

```sql
-- Find where a table's files are stored
SELECT 
    schemaname,
    tablename,
    pg_relation_filepath(schemaname||'.'||tablename) as filepath,
    pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) as total_size,
    pg_size_pretty(pg_relation_size(schemaname||'.'||tablename)) as table_size,
    pg_size_pretty(pg_indexes_size(schemaname||'.'||tablename)) as indexes_size
FROM pg_tables
WHERE schemaname = 'public';
```

---

## Part 6: Understanding Logs

### Where Are Logs Located?

PostgreSQL logs can be in different places depending on configuration:

#### 1. Docker Logs (Default in Our Setup)

```bash
# View all logs
docker logs my-postgres

# Follow logs in real-time
docker logs -f my-postgres

# View last 100 lines
docker logs --tail 100 my-postgres

# View logs with timestamps
docker logs -t my-postgres
```

#### 2. Log Files in Data Directory

If configured to log to files:

```bash
# Check log directory setting
docker exec my-postgres psql -U postgres -c "SHOW log_directory;"

# List log files (if any)
docker exec my-postgres bash -c "ls -lh /var/lib/postgresql/data/log/ 2>/dev/null || echo 'Logs going to stdout/stderr'"
```

#### 3. System Logs

Check PostgreSQL log settings:

```sql
-- View logging configuration
SELECT name, setting 
FROM pg_settings 
WHERE name LIKE '%log%' 
ORDER BY name;
```

### What Gets Logged?

PostgreSQL can log:
- **Connections**: Who connected and when
- **Queries**: SQL statements executed
- **Errors**: Error messages and warnings
- **Checkpoints**: Database maintenance events
- **Slow queries**: Queries taking too long
- **DDL changes**: Schema modifications

### Configuring Logging

```sql
-- Enable connection logging
ALTER SYSTEM SET log_connections = 'on';

-- Enable query logging (be careful - can be verbose!)
ALTER SYSTEM SET log_statement = 'all';  -- 'none', 'ddl', 'mod', 'all'

-- Enable slow query logging
ALTER SYSTEM SET log_min_duration_statement = 1000;  -- Log queries > 1 second

-- Reload configuration (no restart needed)
SELECT pg_reload_conf();
```

### Viewing Logged Activity

```bash
# View recent connections
docker logs my-postgres 2>&1 | grep "connection"

# View errors
docker logs my-postgres 2>&1 | grep -i error

# View all activity
docker logs my-postgres 2>&1 | tail -50
```

---

## Part 7: Understanding Configuration Files

### Where Are Config Files?

Configuration files are in the data directory:

```bash
# Main configuration file
docker exec my-postgres psql -U postgres -c "SHOW config_file;"

# HBA (authentication) file
docker exec my-postgres psql -U postgres -c "SHOW hba_file;"

# List all config files
docker exec my-postgres bash -c "ls -lh /var/lib/postgresql/data/*.conf"
```

### Key Configuration Files

| File | Purpose | Location |
|------|---------|----------|
| `postgresql.conf` | Main configuration | `/var/lib/postgresql/data/postgresql.conf` |
| `postgresql.auto.conf` | Auto-generated settings | `/var/lib/postgresql/data/postgresql.auto.conf` |
| `pg_hba.conf` | Host-based authentication | `/var/lib/postgresql/data/pg_hba.conf` |
| `pg_ident.conf` | User name mapping | `/var/lib/postgresql/data/pg_ident.conf` |

### Viewing Configuration

```bash
# View main config file
docker exec my-postgres cat /var/lib/postgresql/data/postgresql.conf | head -50

# View HBA config (who can connect)
docker exec my-postgres cat /var/lib/postgresql/data/pg_hba.conf

# View current settings
docker exec my-postgres psql -U postgres -c "SHOW ALL;" | head -30
```

### Changing Configuration

```sql
-- View a specific setting
SHOW max_connections;
SHOW shared_buffers;

-- Change a setting (session level)
SET work_mem = '16MB';

-- Change a setting (database level)
ALTER DATABASE mydb SET work_mem = '32MB';

-- Change a setting (system level - requires reload)
ALTER SYSTEM SET max_connections = 200;
SELECT pg_reload_conf();  -- Apply without restart

-- Some settings require restart
ALTER SYSTEM SET shared_buffers = '256MB';
-- Need to restart: docker restart my-postgres
```

---

## Part 8: Understanding Tablespaces

### What is a Tablespace?

A **tablespace** is a location on disk where PostgreSQL stores database objects. It allows you to control where data is physically stored.

### Why Use Tablespaces?

- **Performance**: Store frequently accessed data on fast disks (SSD)
- **Organization**: Separate data by purpose (e.g., indexes on different disk)
- **Disk Management**: Distribute data across multiple disks
- **Backup**: Backup specific tablespaces separately

### Default Tablespace

PostgreSQL has a default tablespace called `pg_default` where all objects are stored unless specified otherwise.

### Viewing Tablespaces

```sql
-- List all tablespaces
\db

-- Or using SQL
SELECT 
    spcname as tablespace_name,
    pg_tablespace_location(oid) as location,
    spcowner::regrole as owner
FROM pg_tablespace;

-- Show default tablespace
SHOW default_tablespace;
```

### Creating Tablespaces

**Note**: In Docker, we need to create directories first and mount them, or create them inside the container.

```sql
-- Create a tablespace (requires directory to exist)
-- First, create directory in container
-- docker exec my-postgres mkdir -p /var/lib/postgresql/tablespaces/fast_disk

-- Then create tablespace
CREATE TABLESPACE fast_disk 
    LOCATION '/var/lib/postgresql/tablespaces/fast_disk';

-- Create table in specific tablespace
CREATE TABLE fast_table (
    id SERIAL PRIMARY KEY,
    data TEXT
) TABLESPACE fast_disk;

-- Create index in different tablespace
CREATE INDEX idx_fast_table_data ON fast_table(data) 
    TABLESPACE fast_disk;
```

### Practical Tablespace Exercise

```bash
# Create directory for tablespace
docker exec my-postgres mkdir -p /var/lib/postgresql/tablespaces/archive_data
```

```sql
-- Create tablespace
CREATE TABLESPACE archive_data 
    LOCATION '/var/lib/postgresql/tablespaces/archive_data';

-- Verify it was created
\db

-- Create a table in the new tablespace
CREATE TABLE old_records (
    id SERIAL PRIMARY KEY,
    record_data TEXT,
    archived_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) TABLESPACE archive_data;

-- Verify table location
SELECT 
    tablename,
    tablespace
FROM pg_tables
WHERE tablename = 'old_records';
```

---

## Part 9: How Users Are Logged

### Connection Logging

PostgreSQL logs user connections when `log_connections` is enabled:

```sql
-- Enable connection logging
ALTER SYSTEM SET log_connections = 'on';
SELECT pg_reload_conf();
```

Now when users connect, you'll see in logs:

```bash
docker logs my-postgres 2>&1 | grep "connection"
```

Output example:
```
LOG:  connection received: host=172.17.0.1 port=5432
LOG:  connection authorized: user=alice database=mydb
```

### Query Logging

Log all SQL statements:

```sql
-- Log all statements (DDL and DML)
ALTER SYSTEM SET log_statement = 'all';
SELECT pg_reload_conf();

-- Or log only data modifications
ALTER SYSTEM SET log_statement = 'mod';
SELECT pg_reload_conf();
```

### Viewing User Activity

```sql
-- See current connections
SELECT 
    pid,
    usename,
    application_name,
    client_addr,
    state,
    query_start,
    state_change
FROM pg_stat_activity
WHERE datname = 'mydb';

-- See what queries are running
SELECT 
    pid,
    usename,
    query,
    state
FROM pg_stat_activity
WHERE state = 'active';
```

### Audit Logging (Advanced)

For detailed audit trails, you may need extensions like `pg_audit` or application-level logging.

---

## Part 10: Hands-On Exercise - Users, Ownership, and Permissions

### Exercise: Create Two Users and Test Ownership

Let's create two users, give them different objects, and test if they can delete each other's objects.

#### Step 1: Create Two Users

```sql
-- Connect as superuser
docker exec -it my-postgres psql -U postgres

-- Create user alice
CREATE USER alice WITH PASSWORD 'alice123';

-- Create user bob
CREATE USER bob WITH PASSWORD 'bob123';

-- Verify users were created
\du
```

#### Step 2: Create Databases for Each User

```sql
-- Create database owned by alice
CREATE DATABASE alice_db OWNER alice;

-- Create database owned by bob
CREATE DATABASE bob_db OWNER bob;

-- Verify ownership
\l
```

#### Step 3: Create Tables as Each User

```sql
-- Connect as alice
\c alice_db alice

-- Create a table as alice
CREATE TABLE alice_products (
    id SERIAL PRIMARY KEY,
    product_name VARCHAR(100),
    price DECIMAL(10, 2)
);

-- Insert some data
INSERT INTO alice_products (product_name, price) VALUES
    ('Alice Product 1', 19.99),
    ('Alice Product 2', 29.99);

-- Verify
SELECT * FROM alice_products;
```

```sql
-- Now connect as bob
\c bob_db bob

-- Create a table as bob
CREATE TABLE bob_customers (
    id SERIAL PRIMARY KEY,
    customer_name VARCHAR(100),
    email VARCHAR(100)
);

-- Insert some data
INSERT INTO bob_customers (customer_name, email) VALUES
    ('Bob Customer 1', 'customer1@example.com'),
    ('Bob Customer 2', 'customer2@example.com');

-- Verify
SELECT * FROM bob_customers;
```

#### Step 4: Test Cross-Database Access

```sql
-- As bob, try to access alice's database
\c alice_db bob

-- Try to see alice's table
\dt

-- Try to SELECT from alice's table (will fail - no permission)
SELECT * FROM alice_products;
-- ERROR: permission denied for table alice_products
```

#### Step 5: Grant Permissions and Test

```sql
-- Connect as alice (owner)
\c alice_db alice

-- Grant SELECT permission to bob
GRANT SELECT ON alice_products TO bob;

-- Now connect as bob and try again
\c alice_db bob

-- This should work now
SELECT * FROM alice_products;

-- But bob still can't INSERT, UPDATE, or DELETE
INSERT INTO alice_products (product_name, price) VALUES ('Test', 10.00);
-- ERROR: permission denied for table alice_products
```

#### Step 6: Test Deletion Permissions

```sql
-- As bob, try to delete alice's table
\c alice_db bob

DROP TABLE alice_products;
-- ERROR: must be owner of table alice_products

-- Try to delete data
DELETE FROM alice_products;
-- ERROR: permission denied for table alice_products
```

#### Step 7: Grant Full Permissions and Test Again

```sql
-- Connect as alice
\c alice_db alice

-- Grant ALL privileges to bob
GRANT ALL PRIVILEGES ON alice_products TO bob;

-- Now connect as bob
\c alice_db bob

-- Bob can now modify data
UPDATE alice_products SET price = 99.99 WHERE id = 1;
SELECT * FROM alice_products;

-- But bob STILL can't drop the table (only owner can)
DROP TABLE alice_products;
-- ERROR: must be owner of table alice_products
```

#### Step 8: Transfer Ownership

```sql
-- Connect as alice (current owner)
\c alice_db alice

-- Transfer table ownership to bob
ALTER TABLE alice_products OWNER TO bob;

-- Verify ownership changed
\dt

-- Now connect as bob
\c alice_db bob

-- Bob can now drop the table!
DROP TABLE alice_products;
-- SUCCESS! (because bob is now the owner)
```

#### Step 9: Test Schema-Level Ownership

```sql
-- Connect as alice
\c alice_db alice

-- Create a new schema
CREATE SCHEMA alice_schema;

-- Create table in the schema
CREATE TABLE alice_schema.secret_data (
    id SERIAL PRIMARY KEY,
    secret_info TEXT
);

-- Connect as bob
\c alice_db bob

-- Bob can't see tables in alice's schema
\dt alice_schema.*

-- Bob can't access the schema
SELECT * FROM alice_schema.secret_data;
-- ERROR: permission denied for schema alice_schema

-- Connect as alice and grant usage
\c alice_db alice
GRANT USAGE ON SCHEMA alice_schema TO bob;
GRANT SELECT ON alice_schema.secret_data TO bob;

-- Now bob can access
\c alice_db bob
SELECT * FROM alice_schema.secret_data;
```

#### Step 10: Comprehensive Permission Test

```sql
-- Create a comprehensive test scenario
\c alice_db alice

-- Create multiple objects
CREATE TABLE shared_table (id SERIAL PRIMARY KEY, data TEXT);
CREATE TABLE private_table (id SERIAL PRIMARY KEY, data TEXT);
CREATE VIEW shared_view AS SELECT * FROM shared_table;

-- Grant different permissions
GRANT SELECT, INSERT ON shared_table TO bob;
GRANT SELECT ON shared_view TO bob;
-- private_table: no permissions for bob

-- Test as bob
\c alice_db bob

-- Can SELECT from shared_table
SELECT * FROM shared_table;  -- ✓ Works

-- Can INSERT into shared_table
INSERT INTO shared_table (data) VALUES ('Bob inserted this');  -- ✓ Works

-- Can SELECT from shared_view
SELECT * FROM shared_view;  -- ✓ Works

-- Cannot SELECT from private_table
SELECT * FROM private_table;  -- ✗ ERROR: permission denied

-- Cannot UPDATE shared_table (not granted)
UPDATE shared_table SET data = 'changed' WHERE id = 1;  -- ✗ ERROR

-- Cannot DROP shared_table (not owner)
DROP TABLE shared_table;  -- ✗ ERROR: must be owner
```

### Summary of Ownership and Permissions

| Action | Owner | User with ALL privileges | User with SELECT only |
|--------|-------|-------------------------|----------------------|
| SELECT | ✓ | ✓ | ✓ |
| INSERT | ✓ | ✓ | ✗ |
| UPDATE | ✓ | ✓ | ✗ |
| DELETE | ✓ | ✓ | ✗ |
| DROP TABLE | ✓ | ✗ | ✗ |
| ALTER TABLE | ✓ | ✗ | ✗ |
| GRANT permissions | ✓ | ✗ | ✗ |

**Key Points:**
- **Owner** has all privileges and can grant/revoke permissions
- **GRANT ALL** gives data modification but NOT structural changes (DROP, ALTER)
- **Only owner** can drop or alter table structure
- **Schema permissions** are separate from table permissions

---

## Practice Exercises

1. **Explore Database Files**
   - Find your database OID
   - List files in your database directory
   - Create a table and find its file location

2. **Practice Backups**
   - Create a SQL dump backup
   - Create a custom format backup
   - Restore from both types

3. **Work with Users**
   - Create 3 different users with different privileges
   - Test what each user can do

4. **Work with Schemas**
   - Create 2 schemas
   - Create tables in each schema
   - Test accessing tables across schemas

5. **Test Ownership**
   - Create two users
   - Give each user their own database
   - Try to access each other's objects
   - Grant permissions and test again
   - Try to delete each other's tables

6. **Explore Logs**
   - Enable connection logging
   - Connect as different users
   - View the connection logs

7. **Configuration**
   - View current configuration
   - Change a setting
   - Reload configuration

---

## Key Concepts Summary

| Concept | Definition | Location/Example |
|---------|------------|------------------|
| **Database Files** | Physical storage of data | `/var/lib/postgresql/data/base/{OID}/` |
| **Backup** | Copy of database for recovery | `pg_dump`, `pg_basebackup`, WAL archiving |
| **User** | Account that can connect to PostgreSQL | `CREATE USER alice WITH PASSWORD 'pass'` |
| **Schema** | Namespace organizing database objects | `CREATE SCHEMA hr;` |
| **Table** | Collection of rows and columns | `CREATE TABLE employees (...)` |
| **Tablespace** | Physical location for storing data | `CREATE TABLESPACE fast_disk LOCATION '/path'` |
| **Logs** | Record of database activity | `docker logs my-postgres` |
| **Config Files** | Settings for PostgreSQL | `postgresql.conf`, `pg_hba.conf` |
| **Ownership** | Who controls an object | `ALTER TABLE mytable OWNER TO alice;` |
| **Permissions** | What actions users can perform | `GRANT SELECT ON table TO user;` |

---

## Next Steps

Now that you understand the fundamentals:
- Practice creating and managing users
- Experiment with different backup types
- Explore your database file structure
- Test permissions and ownership scenarios
- Review logs to see what's being recorded

Continue to the next exercises to learn more about:
- Creating and managing tables
- Inserting and querying data
- Understanding indexes
- Database maintenance

Happy learning! 🚀

