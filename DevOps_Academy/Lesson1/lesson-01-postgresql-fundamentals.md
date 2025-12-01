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

### Detailed Directory Explanations

This section provides detailed explanations of each directory. Think of these directories as different departments in a company - each has a specific job to do.

#### `base/` - Your Database Files (The Main Storage)

**What it is:** This is where all your actual data lives - every table, every row, every index.

**What's inside:**
- One subdirectory for each database, named by its Object ID (OID)
- Inside each database directory: files for tables, indexes, and other objects
- Each table gets its own file (or multiple files if it's large)
- Files are numbered (like `16385`, `16386`) - these are "relfilenodes"

**Real-world analogy:** Like a filing cabinet where each drawer is a database, and each folder inside is a table.

**Example:**
```
base/
├── 1/          # template1 database
├── 4/          # template0 database  
├── 5/          # postgres database
└── 16384/      # your 'mydb' database
    ├── 16385   # file for your 'customers' table
    ├── 16386   # file for your 'orders' table
    └── 16387   # file for an index
```

**When you interact with it:** Every time you create a table, insert data, or query data, PostgreSQL reads/writes files in this directory.

**Size:** This is usually the largest directory - it contains all your actual data.

---

#### `global/` - Cluster-Wide System Information

**What it is:** Stores information that applies to the entire PostgreSQL cluster (all databases), not just one database.

**What's inside:**
- System catalogs (metadata about users, roles, databases)
- Information about all databases in the cluster
- User and role definitions
- Database templates

**Real-world analogy:** Like a company-wide employee directory that all departments share.

**Key files:**
- `pg_database` - List of all databases
- `pg_authid` - User accounts and passwords
- `pg_tablespace` - Tablespace definitions

**When you interact with it:** When you create a new user, create a database, or check who has access to what - PostgreSQL reads from here.

**Important:** This is system data - don't modify these files directly! Always use SQL commands.

---

#### `pg_wal/` - Write-Ahead Log (Transaction Log)

**What it is:** A log of every change made to the database. Before any change is written to the actual data files, it's first written here.

**What's inside:**
- WAL segment files (named like `000000010000000000000001`)
- Each file is 16MB by default
- Contains a record of every INSERT, UPDATE, DELETE, and DDL change

**Why it exists:**
1. **Crash recovery:** If PostgreSQL crashes, it can replay these logs to recover
2. **Point-in-time recovery:** Restore to any moment in time
3. **Replication:** Changes can be sent to standby servers
4. **Performance:** Allows faster commits (write to log first, update data files later)

**Real-world analogy:** Like a detailed diary that records every transaction before updating the main ledger.

**How it works:**
1. User executes: `UPDATE customers SET name='John' WHERE id=1`
2. PostgreSQL writes to WAL: "Update row in customers table, id=1, change name to 'John'"
3. Then updates the actual data file in `base/`
4. If crash happens between steps 2-3, WAL can replay the change

**When you interact with it:** 
- During backups (WAL files are archived)
- During recovery (WAL files are replayed)
- PostgreSQL automatically manages this - you rarely touch it directly

**Size:** Can grow large if you have many transactions. Old WAL files are automatically removed after checkpoint.

---

#### `pg_xact/` - Transaction Commit Status

**What it is:** Tracks whether each transaction has been committed (saved) or is still in progress.

**What's inside:**
- Status bits for each transaction
- Information about which transactions are committed, aborted, or in progress

**Why it exists:** 
- Other transactions need to know if data they're reading is committed or not
- Prevents reading uncommitted (dirty) data
- Helps with transaction isolation

**Real-world analogy:** Like a status board showing which orders are confirmed vs. pending.

**Example scenario:**
- Transaction A starts, updates a row
- Transaction B tries to read that row
- PostgreSQL checks `pg_xact/` to see if Transaction A is committed
- If not committed, Transaction B might wait or read the old value (depending on isolation level)

**When you interact with it:** PostgreSQL uses this automatically - you never directly access it.

**Technical note:** This is also called "pg_clog" (commit log) in older PostgreSQL versions.

---

#### `pg_multixact/` - Multi-Transaction Lock Information

**What it is:** Stores information about locks that involve multiple transactions working together.

**What are locks?** 
A lock prevents multiple transactions from modifying the same data at the same time, which could cause data corruption. Think of it like a "Do Not Disturb" sign on a hotel room door - it prevents others from entering while someone is inside.

**What is a multi-transaction lock?**
When multiple transactions need to lock the same row, PostgreSQL groups them together for efficiency. Instead of creating separate lock entries for each transaction, it creates one "multi-transaction" (multixact) entry that represents all of them together.

**Real-world analogy:** 
- **Single lock:** One person has the key to a room
- **Multi-transaction lock:** Multiple people need access, so they form a group and share the key

**Example scenario:**
```sql
-- Three different transactions all want to read the same row with a shared lock
Transaction 1: SELECT * FROM customers WHERE id=1 FOR SHARE;
Transaction 2: SELECT * FROM customers WHERE id=1 FOR SHARE;
Transaction 3: SELECT * FROM customers WHERE id=1 FOR SHARE;
```

Instead of creating three separate lock entries, PostgreSQL creates one "multixact" entry that says "Transactions 1, 2, and 3 all have a shared lock on this row."

**What's inside:**
- Multi-transaction IDs (unique identifiers for each group)
- Lists of which transactions are part of each multi-transaction
- Status information about each multi-transaction

**When you interact with it:** 
- Automatically used when multiple transactions lock the same row
- You might see it in error messages if there are lock conflicts
- Can grow if you have many concurrent transactions with shared locks

**Common issues:**
- If this directory grows very large, it can slow down the database
- Usually happens with high concurrency and long-running transactions
- Can be cleaned up with VACUUM

**For beginners:** You rarely need to worry about this unless you're running high-concurrency applications. PostgreSQL handles it automatically. If you're just learning, you probably won't encounter this until you're working with applications that have many users accessing the database simultaneously.

---

#### `pg_subtrans/` - Subtransaction Status

**What it is:** Tracks information about subtransactions (transactions within transactions).

**What is a subtransaction?**
A subtransaction is a transaction that happens inside another transaction. If the subtransaction fails, you can rollback just that part without rolling back the entire parent transaction.

**Real-world analogy:** 
- **Main transaction:** "Process this entire order"
- **Subtransaction:** "Charge the credit card" (if this fails, you might want to retry without canceling the whole order)

**Example:**
```sql
BEGIN;  -- Main transaction starts

-- Do some work
INSERT INTO orders (customer_id, total) VALUES (1, 100);

SAVEPOINT before_payment;  -- Create a subtransaction checkpoint
-- Try to process payment
INSERT INTO payments (order_id, amount) VALUES (1, 100);
-- If payment fails:
ROLLBACK TO SAVEPOINT before_payment;  -- Rollback just the payment part
-- Main transaction continues, order is still there

COMMIT;  -- Main transaction completes
```

**What's inside:**
- Status of each subtransaction
- Parent-child relationships between transactions
- Information needed to rollback to savepoints

**When you interact with it:**
- When you use `SAVEPOINT` and `ROLLBACK TO SAVEPOINT`
- When using stored procedures with exception handling
- PostgreSQL uses it automatically

**For beginners:** You'll use this when you want to create "checkpoints" in a transaction that you can rollback to if something goes wrong. It's like having multiple undo points in a video game.

---

#### `pg_twophase/` - Two-Phase Commit State

**What it is:** Stores state information for two-phase commit transactions.

**What is two-phase commit?**
A protocol that ensures transactions across multiple databases or systems either all succeed or all fail together. It has two phases:
1. **Prepare phase:** "Are you ready to commit?" (all must say yes)
2. **Commit phase:** "Actually commit now" (all commit together)

**Real-world analogy:** 
Like a group decision where everyone must agree before anything happens:
- Phase 1: "Can everyone commit to this plan?" (prepare)
- Phase 2: "Okay, everyone execute the plan now" (commit)

**Example scenario:**
You're transferring money between two different databases:
- Database A: Debit $100 from account
- Database B: Credit $100 to account

Both must succeed or both must fail. Two-phase commit ensures this.

**What's inside:**
- Prepared transaction state files
- Information about transactions waiting in "prepared" state
- Used for distributed transactions

**When you interact with it:**
- When using `PREPARE TRANSACTION` and `COMMIT PREPARED`
- In distributed database systems
- With transaction managers (like XA transactions)

**For beginners:** This is an advanced feature. You won't use it unless you're working with distributed systems or specific enterprise applications. Most beginners can skip this for now.

**Common commands:**
```sql
PREPARE TRANSACTION 'my_transaction_id';
-- Later, on another connection or after restart:
COMMIT PREPARED 'my_transaction_id';
-- Or:
ROLLBACK PREPARED 'my_transaction_id';
```

---

#### `pg_commit_ts/` - Commit Timestamps

**What it is:** Stores the exact timestamp when each transaction was committed.

**What's inside:**
- Timestamp for each committed transaction
- Used for tracking when data changes occurred

**Why it exists:**
- **Auditing:** Know exactly when data was changed
- **Replication:** Determine order of changes
- **Point-in-time recovery:** Restore to a specific time
- **Conflict resolution:** In multi-master replication

**Real-world analogy:** Like a timestamp on every receipt showing exactly when a purchase was made.

**Example use case:**
```sql
-- Enable commit timestamps (requires restart)
ALTER SYSTEM SET track_commit_timestamp = on;

-- Later, you can see when a transaction committed
SELECT pg_xact_commit_timestamp(xmin) as committed_at, *
FROM my_table;
```

**When you interact with it:**
- Must be enabled with `track_commit_timestamp = on`
- Used automatically once enabled
- Can query commit times using `pg_xact_commit_timestamp()`

**For beginners:** This is optional and off by default. Enable it if you need to track when changes happened. Most beginners don't need this initially.

**Performance note:** Enabling this has a small performance cost, so only enable if you need it.

---

#### `pg_logical/` - Logical Replication Data

**What it is:** Stores data for logical decoding, which is used for logical replication and change data capture.

**What is logical replication?**
A method of replicating data by sending the logical changes (INSERT, UPDATE, DELETE) rather than copying the physical files.

**Difference from physical replication:**
- **Physical replication:** Copies the actual data files (like `pg_basebackup`)
- **Logical replication:** Sends the SQL changes (like "INSERT INTO customers...")

**What's inside:**
- Logical decoding data
- Information about changes that need to be replicated
- Used by logical replication slots

**Real-world analogy:**
- **Physical replication:** Copying an entire book
- **Logical replication:** Sending a list of edits ("change page 5, line 3 to...")

**When you interact with it:**
- When setting up logical replication
- When using change data capture (CDC) tools
- When streaming changes to other systems

**For beginners:** This is an advanced feature for replication. You'll learn about it when setting up database replication. Most beginners can skip this for now.

**Common use cases:**
- Replicating specific tables (not entire database)
- Upgrading PostgreSQL versions
- Streaming changes to data warehouses
- Change data capture for analytics

---

#### `pg_replslot/` - Replication Slots

**What it is:** Stores information about replication slots, which ensure that WAL files needed for replication are not deleted.

**What is a replication slot?**
A named slot that tracks how much WAL data a replica (standby server) needs. PostgreSQL won't delete WAL files until the replica has received them.

**Why it exists:**
- Prevents WAL files from being deleted before replicas receive them
- Ensures reliable replication
- Allows replicas to be temporarily disconnected without losing data

**Real-world analogy:** Like a reservation system - "Reserve these WAL files for replica X until it confirms it has them."

**What's inside:**
- Replication slot definitions
- Information about which WAL files each slot needs
- Status of each replication slot

**When you interact with it:**
- When setting up streaming replication
- When creating replication slots: `SELECT pg_create_physical_replication_slot('my_slot');`
- When monitoring replication: `SELECT * FROM pg_replication_slots;`

**For beginners:** You'll use this when setting up database replication (having a backup database that stays in sync). This is an advanced topic.

**Important:** If a replica disconnects and doesn't reconnect, the slot will prevent WAL cleanup, which can fill up your disk! Monitor slots regularly.

---

#### `pg_stat/` - Permanent Statistics

**What it is:** Stores permanent statistics about database activity that survive server restarts.

**What's inside:**
- Statistics about table access (how many times scanned, rows read, etc.)
- Index usage statistics
- Database activity metrics
- Information used by the query planner to optimize queries

**Why it exists:**
- Helps PostgreSQL choose the best query execution plan
- Tracks database usage patterns
- Used for performance monitoring

**Real-world analogy:** Like a detailed logbook of how often each room in a building is used, helping decide where to put resources.

**Example statistics tracked:**
- How many times a table has been scanned
- How many rows have been inserted/updated/deleted
- How many times each index has been used
- Last time statistics were updated

**When you interact with it:**
- Automatically updated by PostgreSQL
- You can view statistics: `SELECT * FROM pg_stat_user_tables;`
- You can manually update: `ANALYZE table_name;`

**For beginners:** PostgreSQL uses this automatically to make queries faster. You can query these views to see how your database is being used. This is useful for understanding database performance.

**Common views:**
- `pg_stat_user_tables` - Statistics about your tables
- `pg_stat_user_indexes` - Statistics about your indexes
- `pg_stat_database` - Statistics about databases

---

#### `pg_stat_tmp/` - Temporary Statistics

**What it is:** Stores temporary statistics that are reset when the server restarts.

**What's inside:**
- Current session statistics
- Temporary query execution statistics
- Information that doesn't need to persist

**Difference from `pg_stat/`:**
- `pg_stat/` - Permanent, survives restarts
- `pg_stat_tmp/` - Temporary, cleared on restart

**When you interact with it:**
- PostgreSQL uses it automatically
- You can query current statistics: `SELECT * FROM pg_stat_activity;`

**For beginners:** This is internal - you don't directly interact with it, but you can query the statistics views that use it.

---

#### `pg_snapshots/` - Exported Snapshots

**What it is:** Stores exported transaction snapshots that can be shared between database sessions.

**What is a transaction snapshot?**
A snapshot defines which transactions are visible to a query. It ensures consistent reads - you see the database as it was at a specific point in time.

**What is an exported snapshot?**
A snapshot that can be shared with other transactions, allowing them to see the same view of the database.

**Real-world analogy:** Like taking a photo of a scene - everyone who gets a copy of that photo sees the same thing, even if the actual scene changes.

**Example use case:**
```sql
-- Transaction 1: Export a snapshot
BEGIN TRANSACTION ISOLATION LEVEL REPEATABLE READ;
SELECT pg_export_snapshot();  -- Returns: '00000003-00000001-1'

-- Transaction 2: Use that snapshot
BEGIN TRANSACTION ISOLATION LEVEL REPEATABLE READ;
SET TRANSACTION SNAPSHOT '00000003-00000001-1';
-- Now Transaction 2 sees the same data as Transaction 1 did
```

**What's inside:**
- Exported snapshot files
- Information about which transactions are visible in each snapshot

**When you interact with it:**
- When using `pg_export_snapshot()` and `SET TRANSACTION SNAPSHOT`
- For advanced transaction isolation scenarios
- When coordinating reads across multiple sessions

**For beginners:** This is an advanced feature. You'll use it when you need multiple transactions to see exactly the same view of the database. Most beginners can skip this for now.

---

#### `pg_serial/` - Serializable Transaction Information

**What it is:** Stores information needed for serializable transaction isolation level.

**What is serializable isolation?**
The strictest transaction isolation level. It ensures that transactions execute as if they ran one at a time, in some order, even though they actually run concurrently.

**Isolation levels (from least to most strict):**
1. **Read Uncommitted** - Can see uncommitted changes (PostgreSQL doesn't actually allow this)
2. **Read Committed** - Default, sees only committed data
3. **Repeatable Read** - Sees same data throughout transaction
4. **Serializable** - Strictest, prevents all anomalies

**Real-world analogy:** Like a single-file line - everyone must wait their turn, no cutting in line.

**What's inside:**
- Information about serializable transactions
- Conflict detection data
- Used to detect and prevent serialization conflicts

**When you interact with it:**
- When using `SET TRANSACTION ISOLATION LEVEL SERIALIZABLE`
- PostgreSQL uses it automatically to detect conflicts
- If conflicts are detected, transactions are rolled back

**Example:**
```sql
-- Transaction 1
BEGIN TRANSACTION ISOLATION LEVEL SERIALIZABLE;
SELECT * FROM accounts WHERE id = 1;
-- ... do some work based on that data ...
UPDATE accounts SET balance = balance - 100 WHERE id = 1;
COMMIT;

-- Transaction 2 (running at same time)
BEGIN TRANSACTION ISOLATION LEVEL SERIALIZABLE;
SELECT * FROM accounts WHERE id = 1;
-- If Transaction 1 commits first, Transaction 2 will be rolled back
-- with error: "could not serialize access"
```

**For beginners:** Most applications use the default "Read Committed" level. Use Serializable only when you need the strictest consistency guarantees. This is an advanced topic.

**Performance note:** Serializable isolation can cause more transaction rollbacks and slower performance due to conflict detection.

---

#### `pg_tblspc/` - Tablespace Symbolic Links

**What it is:** Contains symbolic links (shortcuts) pointing to tablespace directories.

**What is a tablespace?**
A location on disk where PostgreSQL can store database objects. By default, everything goes in the main data directory, but you can create additional tablespaces on different disks.

**What's inside:**
- Symbolic links named with tablespace OIDs
- Each link points to the actual tablespace directory location

**Example:**
```
pg_tblspc/
├── 16385 -> /var/lib/postgresql/tablespaces/fast_disk
└── 16386 -> /var/lib/postgresql/tablespaces/archive_disk
```

**Real-world analogy:** Like shortcuts on your desktop that point to folders in different locations.

**When you interact with it:**
- When creating tablespaces: `CREATE TABLESPACE fast_disk LOCATION '/path/to/directory';`
- When creating objects in specific tablespaces: `CREATE TABLE mytable (...) TABLESPACE fast_disk;`
- PostgreSQL automatically creates the symbolic links

**For beginners:** You'll use tablespaces when you want to:
- Store frequently accessed data on fast SSDs
- Store old/archive data on slower, cheaper disks
- Distribute data across multiple disks for performance

**Common use case:**
```sql
-- Create tablespace on fast SSD
CREATE TABLESPACE fast_ssd LOCATION '/mnt/fast_ssd/postgres';

-- Create index on fast SSD for better performance
CREATE INDEX idx_customer_email ON customers(email) TABLESPACE fast_ssd;
```

---

#### `pg_notify/` - LISTEN/NOTIFY Status Files

**What it is:** Stores status information for PostgreSQL's LISTEN/NOTIFY messaging system.

**What is LISTEN/NOTIFY?**
A simple messaging system that allows one database session to send notifications to other sessions listening for them.

**How it works:**
1. Session A: `LISTEN channel_name;` (starts listening)
2. Session B: `NOTIFY channel_name, 'message';` (sends notification)
3. Session A: Receives the notification

**Real-world analogy:** Like a walkie-talkie system - one person broadcasts, others who are tuned in receive the message.

**Example:**
```sql
-- Session 1: Listen for notifications
LISTEN order_updates;

-- Session 2: Send a notification
NOTIFY order_updates, 'New order #12345 received';

-- Session 1: Will receive the notification
-- (In psql, you'll see: Asynchronous notification "order_updates" with payload "New order #12345 received")
```

**What's inside:**
- Status files tracking which sessions are listening
- Pending notifications
- Channel information

**When you interact with it:**
- When using `LISTEN` and `NOTIFY` commands
- For real-time notifications between database sessions
- In applications that need event notifications

**For beginners:** This is useful when you want one part of your application to notify another part when something happens in the database. It's a simple way to get real-time updates.

**Common use cases:**
- Notify application when new orders arrive
- Trigger cache invalidation
- Real-time dashboard updates
- Inter-process communication

**Note:** For more advanced messaging, consider using message queues (RabbitMQ, Kafka) or PostgreSQL's logical replication.

---

### Summary Table

| Directory | Purpose | When You Use It | Beginner Level |
|-----------|---------|-----------------|----------------|
| `base/` | Your actual data files | Always (automatic) | Essential |
| `global/` | System-wide information | Creating users/databases | Essential |
| `pg_wal/` | Transaction log | Backups, recovery | Important |
| `pg_xact/` | Transaction status | Always (automatic) | Advanced |
| `pg_multixact/` | Multi-transaction locks | High concurrency | Advanced |
| `pg_subtrans/` | Subtransactions | Using SAVEPOINT | Intermediate |
| `pg_twophase/` | Two-phase commit | Distributed transactions | Expert |
| `pg_commit_ts/` | Commit timestamps | Auditing, replication | Intermediate |
| `pg_logical/` | Logical replication | Replication setup | Expert |
| `pg_replslot/` | Replication slots | Replication setup | Expert |
| `pg_stat/` | Permanent statistics | Performance monitoring | Intermediate |
| `pg_stat_tmp/` | Temporary statistics | Always (automatic) | Advanced |
| `pg_snapshots/` | Exported snapshots | Advanced isolation | Expert |
| `pg_serial/` | Serializable transactions | Strict isolation | Expert |
| `pg_tblspc/` | Tablespace links | Using tablespaces | Intermediate |
| `pg_notify/` | LISTEN/NOTIFY | Real-time notifications | Intermediate |

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

### Why Are Backups Critical?

**Backups are not optional - they are essential!** Here's why:

#### 1. **Data Loss Prevention**
- **Hardware failures:** Disks can fail, servers can crash
- **Accidental deletion:** Human errors happen - someone might delete important data
- **Corruption:** Data files can become corrupted
- **Natural disasters:** Fire, flood, or other disasters can destroy servers

**Real-world example:** A developer accidentally runs `DELETE FROM customers;` instead of `DELETE FROM customers WHERE id = 123;`. Without a backup, all customer data is lost forever.

#### 2. **Business Continuity**
- **Minimize downtime:** Restore quickly and get back to business
- **Meet SLAs:** Service Level Agreements often require specific recovery times
- **Customer trust:** Losing customer data destroys trust

#### 3. **Compliance and Legal Requirements**
- **Regulations:** Many industries require data retention and backup policies
- **Audit trails:** Need to prove data existed at certain points in time
- **Legal protection:** Backups can be used as evidence

#### 4. **Testing and Development**
- **Safe testing:** Test changes on a backup copy, not production
- **Development environments:** Create test databases from production backups
- **Training:** Use backups for training without affecting live data

#### 5. **Migration and Upgrades**
- **Version upgrades:** Backup before upgrading PostgreSQL
- **Server migration:** Move data to new servers safely
- **Schema changes:** Test major changes on backup copies first

**The Golden Rule:** If you don't have a backup, you WILL lose data. It's not a matter of "if" but "when".

**Backup Best Practices:**
- ✅ **3-2-1 Rule:** 3 copies, 2 different media types, 1 off-site
- ✅ **Test restores regularly:** A backup you can't restore is useless
- ✅ **Automate backups:** Don't rely on manual processes
- ✅ **Monitor backup success:** Know immediately if backups fail
- ✅ **Document restore procedures:** When disaster strikes, you need clear steps

### Types of Backups in PostgreSQL

#### 1. **SQL Dump (pg_dump)** - Most Common

Creates a text file with SQL commands to recreate your database.

**Why We Need SQL Dumps:**
- **Portability:** Works across different PostgreSQL versions and operating systems
- **Human-readable:** You can open and inspect the backup file
- **Selective restore:** Restore only specific tables or schemas
- **Editable:** Modify the SQL before restoring (useful for data migration)
- **Version control:** Can be stored in Git for schema versioning
- **Cross-platform:** Works on any system that can run PostgreSQL

**Advantages:**
- Human-readable (you can open and read it)
- Portable (works across PostgreSQL versions)
- Can restore specific tables
- Can edit before restoring
- Small file size for schema-only backups
- Easy to compress with gzip

**Disadvantages:**
- Slower for very large databases
- Larger file size for data backups (uncompressed)
- Requires PostgreSQL to be running
- Can't restore individual objects easily (need to edit SQL)

**Step-by-Step: How to Create SQL Dump Backup**

**Step 1: Connect to your database and verify it exists**
```bash
# Check if database exists
docker exec my-postgres psql -U postgres -c "\l mydb"
```

**Step 2: Create a full database backup**
```bash
# Basic backup - saves to current directory
docker exec my-postgres pg_dump -U postgres -d mydb > mydb_backup.sql

# With timestamp for organization
docker exec my-postgres pg_dump -U postgres -d mydb > mydb_backup_$(date +%Y%m%d_%H%M%S).sql

# Verbose output (see what's happening)
docker exec my-postgres pg_dump -U postgres -d mydb -v > mydb_backup.sql
```

**Step 3: Create schema-only backup (structure without data)**
```bash
# Useful for version control or creating empty test databases
docker exec my-postgres pg_dump -U postgres -d mydb --schema-only > schema.sql
```

**Step 4: Create data-only backup (data without structure)**
```bash
# Useful when you only need to restore data to existing tables
docker exec my-postgres pg_dump -U postgres -d mydb --data-only > data.sql
```

**Step 5: Backup specific tables**
```bash
# Backup only one table
docker exec my-postgres pg_dump -U postgres -d mydb -t customers > customers_backup.sql

# Backup multiple tables
docker exec my-postgres pg_dump -U postgres -d mydb -t customers -t orders > tables_backup.sql
```

**Step 6: Backup all databases (including users)**
```bash
# Backs up all databases and user accounts
docker exec my-postgres pg_dumpall -U postgres > all_databases_backup.sql
```

**Step 7: Compress the backup**
```bash
# Compress to save space
docker exec my-postgres pg_dump -U postgres -d mydb | gzip > mydb_backup.sql.gz

# Or compress after creation
gzip mydb_backup.sql
```

**Step-by-Step: How to Restore SQL Dump**

**Step 1: Verify the backup file exists**
```bash
ls -lh mydb_backup.sql
```

**Step 2: Restore to existing database**
```bash
# Restore to existing database (will add to existing data)
docker exec -i my-postgres psql -U postgres -d mydb < mydb_backup.sql
```

**Step 3: Restore to new database**
```bash
# Create new database first
docker exec my-postgres psql -U postgres -c "CREATE DATABASE mydb_restored;"

# Restore to new database
docker exec -i my-postgres psql -U postgres -d mydb_restored < mydb_backup.sql
```

**Step 4: Restore compressed backup**
```bash
# Decompress and restore in one step
gunzip -c mydb_backup.sql.gz | docker exec -i my-postgres psql -U postgres -d mydb
```

**Step 5: Verify restore worked**
```bash
# Check tables were restored
docker exec my-postgres psql -U postgres -d mydb_restored -c "\dt"

# Check data was restored
docker exec my-postgres psql -U postgres -d mydb_restored -c "SELECT COUNT(*) FROM customers;"
```

**When to Use SQL Dumps:**
- ✅ Daily backups of small to medium databases
- ✅ Schema versioning and migration scripts
- ✅ Cross-version upgrades
- ✅ Creating test databases from production
- ✅ Selective table backups
- ✅ When you need human-readable backups

#### 2. **Custom Format (pg_dump -Fc)** - Compressed

Creates a compressed, binary-format backup. This is the recommended format for production databases.

**Why We Need Custom Format Backups:**
- **Efficiency:** Compressed format saves disk space and transfer time
- **Speed:** Faster backup and restore operations
- **Flexibility:** Can restore specific tables, indexes, or other objects
- **Parallel restore:** Can restore multiple objects simultaneously
- **Production-ready:** Best choice for large production databases
- **Selective restore:** Restore only what you need, not everything

**Advantages:**
- Smaller file size (compressed automatically)
- Faster backup/restore operations
- Can restore specific objects (tables, indexes, functions, etc.)
- Can restore in parallel (multiple workers)
- Can list contents before restoring
- More efficient for large databases

**Disadvantages:**
- Not human-readable (binary format)
- Requires `pg_restore` tool (not just `psql`)
- Less portable than SQL dumps (but still works across versions)

**Step-by-Step: How to Create Custom Format Backup**

**Step 1: Create the backup**
```bash
# Basic custom format backup
docker exec my-postgres pg_dump -U postgres -d mydb -Fc -f /tmp/mydb_backup.dump

# With verbose output to see progress
docker exec my-postgres pg_dump -U postgres -d mydb -Fc -f /tmp/mydb_backup.dump -v

# With compression level (1-9, 9 = maximum compression, slower)
docker exec my-postgres pg_dump -U postgres -d mydb -Fc -Z 9 -f /tmp/mydb_backup.dump
```

**Step 2: Copy backup to host machine**
```bash
# Copy from container to your computer
docker cp my-postgres:/tmp/mydb_backup.dump ./mydb_backup.dump

# Verify file was copied
ls -lh mydb_backup.dump
```

**Step 3: List backup contents (optional)**
```bash
# See what's inside the backup without restoring
docker exec my-postgres pg_restore -l /tmp/mydb_backup.dump

# Save contents list to file
docker exec my-postgres pg_restore -l /tmp/mydb_backup.dump > backup_contents.txt
```

**Step 4: Create backup with specific options**
```bash
# Exclude specific tables
docker exec my-postgres pg_dump -U postgres -d mydb -Fc -T old_table -f /tmp/mydb_backup.dump

# Include only specific schemas
docker exec my-postgres pg_dump -U postgres -d mydb -Fc -n public -f /tmp/mydb_backup.dump
```

**Step-by-Step: How to Restore Custom Format Backup**

**Step 1: Copy backup into container**
```bash
# Copy backup file into container
docker cp mydb_backup.dump my-postgres:/tmp/mydb_backup.dump

# Verify it's there
docker exec my-postgres ls -lh /tmp/mydb_backup.dump
```

**Step 2: List what will be restored**
```bash
# See contents before restoring
docker exec my-postgres pg_restore -l /tmp/mydb_backup.dump
```

**Step 3: Restore entire database**
```bash
# Restore to existing database (will add to existing data)
docker exec my-postgres pg_restore -U postgres -d mydb /tmp/mydb_backup.dump

# Clean restore (drops objects before recreating)
docker exec my-postgres pg_restore -U postgres -d mydb -c /tmp/mydb_backup.dump

# Verbose output to see progress
docker exec my-postgres pg_restore -U postgres -d mydb -v /tmp/mydb_backup.dump
```

**Step 4: Restore to new database**
```bash
# Create new database
docker exec my-postgres psql -U postgres -c "CREATE DATABASE mydb_restored;"

# Restore to new database
docker exec my-postgres pg_restore -U postgres -d mydb_restored /tmp/mydb_backup.dump
```

**Step 5: Restore specific objects only**
```bash
# Restore only specific table
docker exec my-postgres pg_restore -U postgres -d mydb -t customers /tmp/mydb_backup.dump

# Restore only schema (structure)
docker exec my-postgres pg_restore -U postgres -d mydb --schema-only /tmp/mydb_backup.dump

# Restore only data
docker exec my-postgres pg_restore -U postgres -d mydb --data-only /tmp/mydb_backup.dump
```

**Step 6: Parallel restore (faster for large backups)**
```bash
# Restore using 4 parallel workers
docker exec my-postgres pg_restore -U postgres -d mydb -j 4 /tmp/mydb_backup.dump
```

**Step 7: Verify restore**
```bash
# Check tables
docker exec my-postgres psql -U postgres -d mydb_restored -c "\dt"

# Check data
docker exec my-postgres psql -U postgres -d mydb_restored -c "SELECT COUNT(*) FROM customers;"
```

**When to Use Custom Format:**
- ✅ Production database backups (recommended)
- ✅ Large databases (better performance)
- ✅ When you need selective restore
- ✅ Automated backup scripts
- ✅ When disk space is a concern (compression)
- ✅ When you need fast restore times

#### 3. **File System Backup (pg_basebackup)** - Physical Copy

Creates a complete copy of all database files at the filesystem level. This is a "physical" backup that copies the actual data files.

**Why We Need File System Backups:**
- **Speed:** Fastest backup method for very large databases
- **Exact copy:** Bit-for-bit copy of database files
- **Replication:** Required for setting up streaming replication
- **Full server backup:** Backs up entire PostgreSQL cluster (all databases)
- **Consistency:** Guaranteed consistent snapshot
- **Recovery speed:** Fastest restore method

**Advantages:**
- Fastest backup method (especially for large databases)
- Exact copy of files (bit-for-bit identical)
- Can be used for replication setup
- Backs up entire cluster (all databases at once)
- Consistent snapshot guaranteed
- Fastest restore method

**Disadvantages:**
- Requires database to be running
- Larger backup size (no compression by default)
- Less flexible than SQL dumps (can't restore individual tables easily)
- Must restore entire cluster
- Requires more disk space
- Platform-specific (files are OS-specific)

**Step-by-Step: How to Create File System Backup**

**Step 1: Ensure PostgreSQL is running**
```bash
# Check if PostgreSQL is running
docker ps | grep my-postgres
```

**Step 2: Create basic base backup**
```bash
# Basic backup (creates directory with all files)
docker exec my-postgres pg_basebackup -U postgres -D /tmp/base_backup -P

# -D: destination directory
# -P: show progress
```

**Step 3: Create compressed tar backup**
```bash
# Create compressed tar archive (recommended)
docker exec my-postgres pg_basebackup -U postgres -D /tmp/base_backup -Ft -z -P

# -Ft: tar format
# -z: compress with gzip
# -P: show progress
```

**Step 4: Create backup with WAL streaming**
```bash
# Include WAL files in backup (for point-in-time recovery)
docker exec my-postgres pg_basebackup -U postgres -D /tmp/base_backup -Ft -z -P -X stream

# -X stream: include WAL files
```

**Step 5: Create backup with specific label**
```bash
# Add label to backup (useful for identification)
docker exec my-postgres pg_basebackup -U postgres -D /tmp/base_backup -Ft -z -P -l "Backup_$(date +%Y%m%d)"
```

**Step 6: Copy backup to host**
```bash
# Copy entire backup directory to host
docker cp my-postgres:/tmp/base_backup ./base_backup

# Or if using tar format, copy the tar file
docker cp my-postgres:/tmp/base_backup.tar.gz ./base_backup.tar.gz
```

**Step 7: Verify backup**
```bash
# Check backup directory contents
docker exec my-postgres ls -lh /tmp/base_backup/

# Check backup size
docker exec my-postgres du -sh /tmp/base_backup
```

**Step-by-Step: How to Restore File System Backup**

**Important:** Restoring a file system backup requires stopping PostgreSQL and replacing the data directory. This is more complex than SQL restore.

**Step 1: Stop PostgreSQL**
```bash
# Stop the container
docker stop my-postgres
```

**Step 2: Backup current data (safety measure)**
```bash
# Rename current data directory (backup)
docker exec my-postgres mv /var/lib/postgresql/data /var/lib/postgresql/data.old
```

**Step 3: Restore from tar backup**
```bash
# Extract tar backup
docker exec my-postgres mkdir -p /var/lib/postgresql/data
docker exec my-postgres bash -c "cd /var/lib/postgresql/data && tar -xzf /tmp/base_backup.tar.gz"
```

**Step 4: Restore from directory backup**
```bash
# Copy backup directory to data location
docker exec my-postgres cp -r /tmp/base_backup/* /var/lib/postgresql/data/
```

**Step 5: Set correct permissions**
```bash
# Ensure PostgreSQL user owns the files
docker exec my-postgres chown -R postgres:postgres /var/lib/postgresql/data
```

**Step 6: Start PostgreSQL**
```bash
# Start the container
docker start my-postgres

# Check logs to ensure it started correctly
docker logs my-postgres
```

**Step 7: Verify restore**
```bash
# Connect and verify databases exist
docker exec my-postgres psql -U postgres -c "\l"

# Verify data
docker exec my-postgres psql -U postgres -d mydb -c "SELECT COUNT(*) FROM customers;"
```

**When to Use File System Backups:**
- ✅ Very large databases (faster than SQL dumps)
- ✅ Setting up streaming replication
- ✅ Full cluster backups (all databases)
- ✅ Disaster recovery scenarios
- ✅ When you need fastest possible restore
- ✅ Migration to new server with same PostgreSQL version

#### 4. **Continuous Archiving (WAL Archiving)** - Point-in-Time Recovery

Saves Write-Ahead Log (WAL) files continuously for point-in-time recovery. This is the most advanced backup method that allows recovery to any specific moment in time.

**Why We Need WAL Archiving:**
- **Point-in-time recovery:** Restore to any specific moment, not just backup time
- **Minimal data loss:** Recover to seconds before a disaster
- **Continuous protection:** No gaps in backup coverage
- **Production critical:** Essential for production databases with strict RTO/RPO requirements
- **Compliance:** Meet regulatory requirements for data recovery
- **Flexibility:** Choose exactly when to recover to

**Real-world scenario:**
- You have a backup from 2:00 AM
- At 2:30 PM, someone accidentally deletes critical data
- With WAL archiving, you can recover to 2:29 PM - just before the mistake!
- Without WAL archiving, you'd lose all data from 2:00 AM to 2:30 PM

**Advantages:**
- Can recover to any point in time (not just backup time)
- Minimal data loss (can recover to seconds before disaster)
- Continuous protection (no gaps)
- Works with base backups for complete solution
- Industry standard for production databases

**Disadvantages:**
- More complex to set up and manage
- Requires ongoing maintenance
- Needs storage for WAL files
- Requires base backup + WAL files for recovery
- More complex restore process

**How It Works:**
1. **Base Backup:** Create a full backup (using `pg_basebackup`)
2. **WAL Archiving:** Continuously save WAL files to archive location
3. **Recovery:** Restore base backup + replay WAL files up to target time

**Step-by-Step: How to Set Up WAL Archiving**

**Step 1: Create archive directory**
```bash
# Create directory for archived WAL files
mkdir -p ~/wal_archive

# Or in Docker, create inside container
docker exec my-postgres mkdir -p /var/lib/postgresql/wal_archive
```

**Step 2: Configure PostgreSQL for WAL archiving**
```bash
# Connect to PostgreSQL
docker exec -it my-postgres psql -U postgres
```

```sql
-- Enable WAL archiving
ALTER SYSTEM SET wal_level = 'replica';
ALTER SYSTEM SET archive_mode = 'on';
ALTER SYSTEM SET archive_command = 'test ! -f /var/lib/postgresql/wal_archive/%f && cp %p /var/lib/postgresql/wal_archive/%f';

-- Reload configuration
SELECT pg_reload_conf();
```

**Step 3: Restart PostgreSQL (some settings require restart)**
```bash
# Restart container
docker restart my-postgres

# Wait for it to start
sleep 5

# Verify archiving is enabled
docker exec my-postgres psql -U postgres -c "SHOW archive_mode;"
```

**Step 4: Create base backup**
```bash
# Create base backup (this is your starting point)
docker exec my-postgres pg_basebackup -U postgres -D /tmp/base_backup -Ft -z -P -X stream

# Copy to safe location
docker cp my-postgres:/tmp/base_backup.tar.gz ~/base_backup_$(date +%Y%m%d).tar.gz
```

**Step 5: Verify WAL files are being archived**
```bash
# Check archive directory
docker exec my-postgres ls -lh /var/lib/postgresql/wal_archive/

# Make some changes to generate WAL files
docker exec my-postgres psql -U postgres -d mydb -c "INSERT INTO test_table VALUES (1);"

# Check again - should see new WAL files
docker exec my-postgres ls -lh /var/lib/postgresql/wal_archive/
```

**Step-by-Step: How to Perform Point-in-Time Recovery**

**Step 1: Identify recovery target time**
```sql
-- Find when the mistake happened
SELECT 
    'Recovery target: ' || 
    (SELECT MAX(created_at) FROM important_table) - INTERVAL '1 minute' 
    AS recovery_time;
```

**Step 2: Stop PostgreSQL**
```bash
docker stop my-postgres
```

**Step 3: Restore base backup**
```bash
# Remove current data
docker exec my-postgres rm -rf /var/lib/postgresql/data/*

# Extract base backup
docker exec my-postgres mkdir -p /var/lib/postgresql/data
docker exec my-postgres bash -c "cd /var/lib/postgresql/data && tar -xzf /tmp/base_backup.tar.gz"
```

**Step 4: Configure recovery**
```bash
# Create recovery configuration
docker exec my-postgres bash -c "cat > /var/lib/postgresql/data/postgresql.auto.conf << 'EOF'
restore_command = 'cp /var/lib/postgresql/wal_archive/%f %p'
recovery_target_time = '2024-12-01 14:29:00'
EOF"

# Create recovery signal file
docker exec my-postgres touch /var/lib/postgresql/data/recovery.signal
```

**Step 5: Start PostgreSQL (it will enter recovery mode)**
```bash
# Start container
docker start my-postgres

# Monitor recovery progress
docker logs -f my-postgres
```

**Step 6: Verify recovery**
```bash
# Once recovery completes, verify data
docker exec my-postgres psql -U postgres -d mydb -c "SELECT * FROM important_table;"
```

**When to Use WAL Archiving:**
- ✅ Production databases with strict recovery requirements
- ✅ When you need point-in-time recovery capability
- ✅ Compliance requirements for data recovery
- ✅ Critical business applications
- ✅ When minimal data loss is required (RPO < 1 hour)
- ✅ High-availability setups with replication

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

