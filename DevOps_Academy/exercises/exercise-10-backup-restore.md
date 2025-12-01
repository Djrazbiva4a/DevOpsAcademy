# Exercise 10: Backup and Restore

## Learning Objectives
- Understand why backups are essential
- Learn different backup methods in PostgreSQL
- Create database backups using pg_dump
- Restore databases from backups
- Understand backup strategies
- Learn about Point-in-Time Recovery (PITR)
- Configure WAL archiving for continuous backups
- Restore database to a specific point in time
- Verify that restore worked correctly

## Why Backups Are Critical

**Backups are your safety net!** Without backups:
- Data loss is permanent
- Accidental deletions can't be undone
- Hardware failures mean lost data
- Human errors have no recovery

**Always have backups!** Especially before:
- Major changes
- Dropping tables
- Running UPDATE/DELETE on large datasets
- Schema changes

## Types of Backups

1. **SQL Dump** - Text file with SQL commands (pg_dump)
2. **Custom Format** - Compressed, flexible format (pg_dump -Fc)
3. **File System Backup** - Copying data files (requires database shutdown)
4. **Continuous Archiving** - WAL (Write-Ahead Log) files for point-in-time recovery

We'll focus on **pg_dump**, the most common method.

## Step-by-Step Instructions

### Step 1: Connect and Create Test Data

```bash
docker exec -it my-postgres psql -U postgres -d ecommerce
```

Create some test data:

```sql
CREATE TABLE important_data (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100),
    value TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

INSERT INTO important_data (name, value) VALUES
    ('Customer Data', 'Very important information'),
    ('Product Catalog', 'Essential business data'),
    ('Sales Records', 'Critical financial data');

-- Verify data
SELECT * FROM important_data;
```

### Step 2: Create a SQL Dump Backup

Exit PostgreSQL and create a backup:

```sql
\q
```

Now create a backup using pg_dump:

```bash
docker exec my-postgres pg_dump -U postgres -d ecommerce > ecommerce_backup.sql
```

**Command Breakdown:**
- `docker exec my-postgres` - run command in container
- `pg_dump` - PostgreSQL backup utility
- `-U postgres` - username
- `-d ecommerce` - database name
- `> ecommerce_backup.sql` - save output to file

### Step 3: View the Backup File

Check what was created:

```bash
ls -lh ecommerce_backup.sql
head -20 ecommerce_backup.sql
```

The backup file contains SQL commands to recreate the database.

### Step 4: Create Backup in Custom Format

Custom format is compressed and more flexible:

```bash
docker exec my-postgres pg_dump -U postgres -d ecommerce -Fc -f /tmp/ecommerce_backup.dump
```

**Options:**
- `-Fc` - Custom format (compressed)
- `-f /tmp/ecommerce_backup.dump` - output file path (inside container)

Copy it to your host:

```bash
docker cp my-postgres:/tmp/ecommerce_backup.dump ./ecommerce_backup.dump
```

### Step 5: Backup a Single Table

Backup only specific tables:

```bash
docker exec my-postgres pg_dump -U postgres -d ecommerce -t important_data > important_data_backup.sql
```

The `-t` option specifies a table name.

### Step 6: Backup All Databases

Backup the entire PostgreSQL server:

```bash
docker exec my-postgres pg_dumpall -U postgres > all_databases_backup.sql
```

`pg_dumpall` backs up all databases, including users and roles.

### Step 7: Simulate Data Loss

Let's simulate an accident:

```bash
docker exec -it my-postgres psql -U postgres -d ecommerce
```

```sql
-- Oops! Accidentally deleted everything
DELETE FROM important_data;

-- Or worse, dropped the table
DROP TABLE important_data;

-- Verify it's gone
SELECT * FROM important_data;
```

### Step 8: Restore from SQL Backup

Exit and restore:

```sql
\q
```

Restore the database:

```bash
docker exec -i my-postgres psql -U postgres -d ecommerce < ecommerce_backup.sql
```

**Note:** `-i` allows stdin input.

Verify the restore:

```bash
docker exec -it my-postgres psql -U postgres -d ecommerce -c "SELECT * FROM important_data;"
```

### Step 9: Restore to a New Database

Create a new database and restore to it:

```bash
# Create new database
docker exec -it my-postgres psql -U postgres -c "CREATE DATABASE ecommerce_restored;"

# Restore backup to new database
docker exec -i my-postgres psql -U postgres -d ecommerce_restored < ecommerce_backup.sql

# Verify
docker exec -it my-postgres psql -U postgres -d ecommerce_restored -c "\dt"
```

### Step 10: Restore from Custom Format

Restore from the custom format backup:

```bash
# Copy backup into container
docker cp ecommerce_backup.dump my-postgres:/tmp/

# Restore using pg_restore
docker exec my-postgres pg_restore -U postgres -d ecommerce -c /tmp/ecommerce_backup.dump
```

**Options:**
- `-c` - Clean (drop objects before recreating)
- `pg_restore` - Used for custom format backups

## Backup Options

### Common pg_dump Options

```bash
# Verbose output (see what's happening)
pg_dump -U postgres -d ecommerce -v > backup.sql

# Include schema only (no data)
pg_dump -U postgres -d ecommerce --schema-only > schema.sql

# Include data only (no schema)
pg_dump -U postgres -d ecommerce --data-only > data.sql

# Exclude specific tables
pg_dump -U postgres -d ecommerce -T table_to_exclude > backup.sql

# Compress output
pg_dump -U postgres -d ecommerce | gzip > backup.sql.gz
```

### Backup with Timestamps

Create backups with timestamps for organization:

```bash
BACKUP_FILE="ecommerce_backup_$(date +%Y%m%d_%H%M%S).sql"
docker exec my-postgres pg_dump -U postgres -d ecommerce > "$BACKUP_FILE"
```

## Restore Options

### Common pg_restore Options

```bash
# Restore specific table
pg_restore -U postgres -d database -t table_name backup.dump

# List contents of backup
pg_restore -l backup.dump

# Restore with verbose output
pg_restore -U postgres -d database -v backup.dump

# Restore in parallel (faster)
pg_restore -U postgres -d database -j 4 backup.dump
```

## Backup Strategies

### 1. Full Backup (Daily)

```bash
# Daily full backup
pg_dump -U postgres -d mydb -Fc -f backup_$(date +%Y%m%d).dump
```

### 2. Incremental Backups with WAL Archiving

Use WAL (Write-Ahead Log) archiving for continuous backups and point-in-time recovery (covered in detail below).

### 3. Automated Backups

Create a backup script:

```bash
#!/bin/bash
# backup.sh

DB_NAME="ecommerce"
BACKUP_DIR="/backups"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="$BACKUP_DIR/${DB_NAME}_${TIMESTAMP}.dump"

# Create backup
docker exec my-postgres pg_dump -U postgres -d $DB_NAME -Fc -f /tmp/backup.dump

# Copy to host
docker cp my-postgres:/tmp/backup.dump "$BACKUP_FILE"

# Keep only last 7 days of backups
find $BACKUP_DIR -name "${DB_NAME}_*.dump" -mtime +7 -delete

echo "Backup completed: $BACKUP_FILE"
```

### 4. Backup Before Major Operations

Always backup before:
- Schema changes
- Large data migrations
- Dropping tables
- Major updates

## Testing Backups

**Always test your backups!** A backup that can't be restored is useless.

1. **Regularly test restores** to a test database
2. **Verify data integrity** after restore
3. **Document restore procedures**
4. **Practice disaster recovery**

## Useful Commands

```bash
# Backup database
pg_dump -U username -d database > backup.sql

# Backup in custom format
pg_dump -U username -d database -Fc -f backup.dump

# Backup all databases
pg_dumpall -U username > all_backup.sql

# Restore from SQL
psql -U username -d database < backup.sql

# Restore from custom format
pg_restore -U username -d database backup.dump

# List backup contents
pg_restore -l backup.dump

# Backup specific table
pg_dump -U username -d database -t table_name > table_backup.sql
```

## Practice Tasks

1. Create a database with multiple tables and data

2. Create a full database backup in SQL format

3. Create a backup in custom format

4. Backup only a specific table

5. Delete some data from your database

6. Restore the backup and verify data is recovered

7. Create a new database and restore your backup to it

8. Create a backup script that includes a timestamp

9. List the contents of a custom format backup

10. Practice the full backup and restore cycle:
    - Create test data
    - Backup
    - Make changes
    - Restore
    - Verify

## Key Concepts

- **pg_dump**: Tool for creating database backups
- **pg_dumpall**: Backs up all databases and roles
- **pg_restore**: Restores custom format backups
- **SQL Dump**: Text file with SQL commands
- **Custom Format**: Compressed, flexible backup format
- **Full Backup**: Complete copy of database
- **Point-in-Time Recovery**: Restore to specific moment (advanced)

## Common Issues

**Problem**: "permission denied" when creating backup
- **Solution**: Ensure user has necessary permissions or use superuser

**Problem**: Backup file is very large
- **Solution**: Use custom format (-Fc) for compression, or compress with gzip

**Problem**: Restore fails due to existing objects
- **Solution**: Use `-c` flag with pg_restore, or drop objects first

**Problem**: Backup takes too long
- **Solution**: Use custom format, run during off-peak hours, consider parallel backup

## Best Practices

1. **Automate Backups**: Set up scheduled backups (cron jobs)
2. **Test Restores**: Regularly verify backups can be restored
3. **Multiple Copies**: Keep backups in multiple locations
4. **Retention Policy**: Keep backups for appropriate time period
5. **Documentation**: Document backup and restore procedures
6. **Monitor**: Ensure backups are completing successfully
7. **Encryption**: Encrypt backups containing sensitive data

## Point-in-Time Recovery (PITR)

Point-in-Time Recovery allows you to restore your database to any specific moment in time, not just when the backup was taken. This is crucial for recovering from mistakes or data corruption.

### How PITR Works

1. **Base Backup**: A full backup of the database at a specific point
2. **WAL Files**: Continuous archiving of Write-Ahead Log files (records all changes)
3. **Recovery**: Restore base backup + replay WAL files up to target time

**Real-world example**: If you accidentally deleted data at 2:00 PM, but you have a backup from 1:00 AM and WAL files, you can recover to 1:59 PM - just before the mistake!

### Step-by-Step PITR Setup

For this exercise, we'll use a practical approach that works well in Docker. We'll create a new container specifically configured for PITR.

#### Step 1: Create Directories for WAL Archives and Backups

```bash
# Create directories on your host machine
mkdir -p $(pwd)/wal_archive
mkdir -p $(pwd)/pitr_backups
```

#### Step 2: Create PostgreSQL Container with WAL Archiving

Stop your current container (if running) and create a new one:

```bash
# Stop and remove existing container (optional)
docker stop my-postgres 2>/dev/null || true
docker rm my-postgres 2>/dev/null || true

# Create new container with volume mounts for WAL archiving
docker run --name my-postgres-pitr \
  -e POSTGRES_PASSWORD=mysecretpassword \
  -e POSTGRES_USER=postgres \
  -e POSTGRES_DB=ecommerce \
  -p 5432:5432 \
  -v $(pwd)/wal_archive:/var/lib/postgresql/wal_archive \
  -v $(pwd)/pitr_backups:/backups \
  -d postgres:15

# Wait for PostgreSQL to start
sleep 5
```

#### Step 3: Configure WAL Archiving

We need to configure PostgreSQL to archive WAL files. Create a custom configuration:

```bash
# Create postgresql.conf with archiving settings
cat > /tmp/postgresql-pitr.conf << 'EOF'
# WAL Archiving Configuration
wal_level = replica
archive_mode = on
archive_command = 'test ! -f /var/lib/postgresql/wal_archive/%f && cp %p /var/lib/postgresql/wal_archive/%f'
max_wal_senders = 3
EOF

# Copy the config file into the container
docker cp /tmp/postgresql-pitr.conf my-postgres-pitr:/var/lib/postgresql/data/postgresql.conf

# Restart to apply configuration
docker restart my-postgres-pitr
sleep 5

# Verify archiving is enabled
docker exec my-postgres-pitr psql -U postgres -c "SHOW archive_mode;"
```

You should see `archive_mode | on`.

#### Step 4: Create Test Database and Table

```bash
docker exec -it my-postgres-pitr psql -U postgres -d ecommerce
```

```sql
-- Create a table to track changes with explicit timestamps
CREATE TABLE transactions (
    id SERIAL PRIMARY KEY,
    description TEXT,
    amount DECIMAL(10, 2),
    transaction_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create a recovery log table to track our recovery points
CREATE TABLE recovery_log (
    id SERIAL PRIMARY KEY,
    checkpoint_name VARCHAR(100),
    checkpoint_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    transaction_count INTEGER,
    notes TEXT
);
```

#### Step 5: Create Base Backup

Exit PostgreSQL and create a base backup:

```sql
\q
```

```bash
# Create base backup using pg_basebackup
# This creates a full copy of the database at this point in time
docker exec my-postgres-pitr pg_basebackup -U postgres -D /backups/base_backup_$(date +%Y%m%d_%H%M%S) -Ft -z -P -X stream

# For simplicity, let's use a fixed name
docker exec my-postgres-pitr pg_basebackup -U postgres -D /backups/base_backup -Ft -z -P -X stream

# Verify backup was created
docker exec my-postgres-pitr ls -lh /backups/
```

**Command Breakdown:**
- `pg_basebackup` - Creates a base backup
- `-D /backups/base_backup` - Destination directory
- `-Ft` - Tar format (creates .tar files)
- `-z` - Compress the backup
- `-P` - Show progress
- `-X stream` - Include WAL files in backup

#### Step 6: Make Changes and Record Recovery Point

Now let's make changes at different times and identify a recovery point:

```bash
docker exec -it my-postgres-pitr psql -U postgres -d ecommerce
```

```sql
-- Insert first transaction and record time
INSERT INTO transactions (description, amount) 
VALUES ('Initial deposit', 1000.00);

-- Get current time
SELECT 'After transaction 1: ' || CURRENT_TIMESTAMP AS checkpoint;

-- Force a checkpoint to ensure WAL is written
CHECKPOINT;

-- Wait 3 seconds
SELECT pg_sleep(3);

-- Insert second transaction
INSERT INTO transactions (description, amount) 
VALUES ('Purchase item A', -50.00);
SELECT 'After transaction 2: ' || CURRENT_TIMESTAMP AS checkpoint;
CHECKPOINT;

-- THIS IS OUR RECOVERY TARGET POINT
-- Record this time - we'll recover to just after transaction 2
SELECT 
    'RECOVERY TARGET TIME: ' || 
    (SELECT transaction_time FROM transactions WHERE id = 2) + INTERVAL '1 second' 
    AS recovery_target;

-- Save the recovery target to our log
INSERT INTO recovery_log (checkpoint_name, checkpoint_time, transaction_count, notes)
VALUES (
    'RECOVERY_TARGET',
    (SELECT transaction_time FROM transactions WHERE id = 2) + INTERVAL '1 second',
    (SELECT COUNT(*) FROM transactions),
    'Target point: After transaction 2, before transaction 3'
);

-- Wait and continue (these will be "lost" after recovery)
SELECT pg_sleep(3);
INSERT INTO transactions (description, amount) 
VALUES ('Purchase item B', -75.00);
SELECT 'After transaction 3: ' || CURRENT_TIMESTAMP AS checkpoint;
CHECKPOINT;

SELECT pg_sleep(3);
INSERT INTO transactions (description, amount) 
VALUES ('Refund', 25.00);
SELECT 'After transaction 4: ' || CURRENT_TIMESTAMP AS checkpoint;

-- View all transactions with timestamps
SELECT 
    id, 
    description, 
    amount, 
    transaction_time,
    TO_CHAR(transaction_time, 'YYYY-MM-DD HH24:MI:SS') as formatted_time
FROM transactions 
ORDER BY transaction_time;

-- Get the recovery target time for later use
SELECT 
    checkpoint_time as recovery_target_time,
    transaction_count as expected_count_after_recovery
FROM recovery_log 
WHERE checkpoint_name = 'RECOVERY_TARGET';
```

**IMPORTANT**: Copy the `recovery_target_time` value - you'll need it in Step 9!

#### Step 7: Simulate Data Loss

Now let's simulate a disaster - we'll delete everything:

```sql
-- Accidentally delete all transactions!
DELETE FROM transactions;

-- Verify the disaster
SELECT COUNT(*) as remaining_transactions FROM transactions;
-- Should show 0

-- Exit to prepare recovery
\q
```

**Note**: In a real scenario, you might have corrupted data, accidental deletions, or other issues. The recovery process is the same.

#### Step 8: Prepare for Recovery

Stop the current container and set up for recovery:

```bash
# Stop the database (required for recovery)
docker stop my-postgres-pitr

# Create a new container for recovery (using different port)
docker run --name my-postgres-recovery \
  -e POSTGRES_PASSWORD=mysecretpassword \
  -e POSTGRES_USER=postgres \
  -v $(pwd)/pitr_backups:/backups \
  -v $(pwd)/wal_archive:/var/lib/postgresql/wal_archive \
  -p 5433:5432 \
  -d postgres:15

# Wait for it to initialize
sleep 5

# Stop it so we can restore the backup
docker stop my-postgres-recovery
```

#### Step 9: Restore Base Backup

```bash
# Remove the default (empty) data directory
docker exec my-postgres-recovery rm -rf /var/lib/postgresql/data/*

# Extract the base backup
docker exec my-postgres-recovery mkdir -p /var/lib/postgresql/data
docker exec my-postgres-recovery bash -c "cd /var/lib/postgresql/data && tar -xzf /backups/base_backup/base.tar.gz"

# Verify files were extracted
docker exec my-postgres-recovery ls -la /var/lib/postgresql/data/ | head -20
```

#### Step 10: Configure Recovery Settings

Now we need to tell PostgreSQL to recover to our target time. Get the recovery target time from Step 6, then:

```bash
# Get the recovery target time (replace with your actual time from Step 6)
# Format: 'YYYY-MM-DD HH:MI:SS'
RECOVERY_TIME="2024-01-15 10:30:00"  # REPLACE WITH YOUR ACTUAL TIME

# Create recovery.signal file (tells PostgreSQL to enter recovery mode)
docker exec my-postgres-recovery touch /var/lib/postgresql/data/recovery.signal

# Create postgresql.auto.conf with recovery settings
cat > /tmp/postgresql.auto.conf << EOF
restore_command = 'cp /var/lib/postgresql/wal_archive/%f %p'
recovery_target_time = '${RECOVERY_TIME}'
EOF

# Copy recovery config into container
docker cp /tmp/postgresql.auto.conf my-postgres-recovery:/var/lib/postgresql/data/postgresql.auto.conf

# Verify the config
docker exec my-postgres-recovery cat /var/lib/postgresql/data/postgresql.auto.conf
```

#### Step 11: Start Recovery Process

```bash
# Start the container - PostgreSQL will automatically enter recovery mode
docker start my-postgres-recovery

# Monitor recovery progress
docker logs -f my-postgres-recovery
```

You'll see messages like:
```
database system was interrupted; last known up at 2024-01-15 10:25:00 UTC
starting archive recovery
restored log file "000000010000000000000001" from archive
...
recovery stopping before commit of transaction ...
database system is ready to accept connections
```

**Important**: Wait until you see "database system is ready to accept connections" - this means recovery is complete!

#### Step 12: Verify Point-in-Time Recovery

Once recovery is complete (you see "database system is ready"), verify the recovery worked:

```bash
docker exec -it my-postgres-recovery psql -U postgres -d ecommerce
```

```sql
-- First, check what transactions exist
SELECT 
    id,
    description,
    amount,
    transaction_time,
    TO_CHAR(transaction_time, 'YYYY-MM-DD HH24:MI:SS') as formatted_time
FROM transactions
ORDER BY transaction_time;

-- Get the expected state from recovery log
SELECT 
    checkpoint_time as expected_recovery_time,
    transaction_count as expected_transaction_count
FROM recovery_log 
WHERE checkpoint_name = 'RECOVERY_TARGET';
```

#### Step 13: Prove Recovery to Specific Point in Time

Now let's create comprehensive verification queries:

```sql
-- Verification Query 1: Count Check
-- Should have exactly 2 transactions (before recovery point)
SELECT 
    COUNT(*) as actual_count,
    2 as expected_count,
    CASE 
        WHEN COUNT(*) = 2 THEN '✓ PASS: Correct number of transactions'
        ELSE '✗ FAIL: Wrong number of transactions'
    END as count_verification
FROM transactions;

-- Verification Query 2: Transaction ID Check
-- Should only have transactions 1 and 2
SELECT 
    id,
    description,
    CASE 
        WHEN id IN (1, 2) THEN '✓ Should exist'
        ELSE '✗ Should NOT exist'
    END as id_verification
FROM transactions
ORDER BY id;

-- Verification Query 3: Time Range Check
-- Latest transaction should be before or at recovery target time
WITH recovery_target AS (
    SELECT checkpoint_time as target_time
    FROM recovery_log 
    WHERE checkpoint_name = 'RECOVERY_TARGET'
)
SELECT 
    MAX(transactions.transaction_time) as latest_transaction_time,
    rt.target_time as recovery_target_time,
    CASE 
        WHEN MAX(transactions.transaction_time) <= rt.target_time THEN 
            '✓ PASS: All transactions are before recovery target'
        ELSE 
            '✗ FAIL: Transactions exist after recovery target'
    END as time_verification
FROM transactions, recovery_target rt
GROUP BY rt.target_time;

-- Verification Query 4: Comprehensive Verification Report
WITH recovery_info AS (
    SELECT 
        checkpoint_time as target_time,
        transaction_count as expected_count
    FROM recovery_log 
    WHERE checkpoint_name = 'RECOVERY_TARGET'
),
actual_info AS (
    SELECT 
        COUNT(*) as actual_count,
        MAX(transaction_time) as latest_time,
        MIN(transaction_time) as earliest_time,
        array_agg(id ORDER BY id) as transaction_ids
    FROM transactions
)
SELECT 
    '=== POINT-IN-TIME RECOVERY VERIFICATION REPORT ===' as report_header,
    '' as spacer1,
    'Expected State:' as section1,
    '  - Recovery Target Time: ' || ri.target_time as target_time,
    '  - Expected Transaction Count: ' || ri.expected_count as expected_count,
    '  - Expected Transaction IDs: [1, 2]' as expected_ids,
    '' as spacer2,
    'Actual State:' as section2,
    '  - Latest Transaction Time: ' || ai.latest_time as latest_time,
    '  - Actual Transaction Count: ' || ai.actual_count as actual_count,
    '  - Actual Transaction IDs: ' || ai.transaction_ids::text as actual_ids,
    '' as spacer3,
    'Verification Results:' as section3,
    CASE 
        WHEN ai.actual_count = ri.expected_count 
            AND ai.latest_time <= ri.target_time
            AND ai.transaction_ids = ARRAY[1,2]
        THEN '  ✓✓✓ RECOVERY SUCCESSFUL ✓✓✓'
        ELSE '  ✗✗✗ RECOVERY FAILED ✗✗✗'
    END as final_result,
    '' as spacer4,
    CASE 
        WHEN ai.actual_count = ri.expected_count THEN '  ✓ Transaction count matches'
        ELSE '  ✗ Transaction count mismatch'
    END as check1,
    CASE 
        WHEN ai.latest_time <= ri.target_time THEN '  ✓ All transactions before target time'
        ELSE '  ✗ Transactions exist after target time'
    END as check2,
    CASE 
        WHEN ai.transaction_ids = ARRAY[1,2] THEN '  ✓ Correct transactions present'
        ELSE '  ✗ Wrong transactions present'
    END as check3
FROM recovery_info ri, actual_info ai;

-- Verification Query 5: Show All Data for Manual Inspection
SELECT 
    id,
    description,
    amount,
    transaction_time,
    TO_CHAR(transaction_time, 'YYYY-MM-DD HH24:MI:SS.MS') as precise_time
FROM transactions
ORDER BY transaction_time;
```

**Expected Results:**
- ✅ Should have exactly 2 transactions (IDs 1 and 2)
- ✅ Transaction 3 and 4 should NOT exist
- ✅ Latest transaction time should be ≤ recovery target time
- ✅ All verification checks should show ✓ PASS

If all checks pass, **your Point-in-Time Recovery was successful!** 🎉

### Simplified PITR Exercise (Easier Approach)

For a simpler hands-on exercise, here's an alternative approach using pg_dump with timestamps:

#### Alternative: Timestamped Backups for PITR Simulation

```bash
# Connect and create test data
docker exec -it my-postgres psql -U postgres -d ecommerce

# In PostgreSQL:
```

```sql
-- Create table
CREATE TABLE audit_log (
    id SERIAL PRIMARY KEY,
    action TEXT,
    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Insert with explicit timestamps
INSERT INTO audit_log (action, timestamp) VALUES 
    ('Backup point 1', '2024-01-15 10:00:00'),
    ('Action 1', '2024-01-15 10:05:00'),
    ('Action 2', '2024-01-15 10:10:00');

-- Create backup at this point
-- Exit and backup
\q
```

```bash
# Backup with timestamp
BACKUP_TIME=$(date +"%Y%m%d_%H%M%S")
docker exec my-postgres pg_dump -U postgres -d ecommerce > "backup_${BACKUP_TIME}.sql"

# Continue making changes
docker exec -it my-postgres psql -U postgres -d ecommerce
```

```sql
-- Continue with more actions
INSERT INTO audit_log (action, timestamp) VALUES 
    ('Action 3', '2024-01-15 10:15:00'),
    ('Action 4', '2024-01-15 10:20:00');

-- Verify all data
SELECT * FROM audit_log ORDER BY timestamp;
```

Now restore to the backup point:

```sql
\q
```

```bash
# Restore from backup (this restores to the backup time)
docker exec -i my-postgres psql -U postgres -d ecommerce < "backup_${BACKUP_TIME}.sql"

# Verify - should only have data up to backup point
docker exec -it my-postgres psql -U postgres -d ecommerce -c "SELECT * FROM audit_log ORDER BY timestamp;"
```

## PITR Verification Checklist

When performing PITR, verify:

1. ✅ **Data exists up to recovery point**: All data before target time is present
2. ✅ **Data after recovery point is absent**: No data after target time exists
3. ✅ **Transaction count matches**: Expected number of transactions present
4. ✅ **Timestamps are correct**: Latest transaction time ≤ recovery target time
5. ✅ **Database is consistent**: No orphaned records or broken relationships
6. ✅ **Application can connect**: Database is ready for use

## Practice Tasks for PITR

1. Set up WAL archiving in a PostgreSQL container

2. Create a base backup using `pg_basebackup`

3. Make several changes to your database, recording timestamps at each step

4. Create a recovery log table to track your recovery points

5. Identify a specific point in time to recover to (after transaction 2, before transaction 3)

6. Simulate data loss (delete all transactions)

7. Restore the base backup to a new container

8. Configure recovery settings with the target time

9. Complete the recovery process and wait for completion

10. **Verify the recovery worked** (CRITICAL STEP):
    - Run verification query 1: Count check (should have 2 transactions)
    - Run verification query 2: Transaction ID check (should have IDs 1 and 2 only)
    - Run verification query 3: Time range check (all transactions before target time)
    - Run verification query 4: Comprehensive verification report
    - Run verification query 5: Show all recovered data
    - Document that all checks passed ✓

11. Take a screenshot or note the verification results showing successful recovery

12. Try recovering to a different point in time (e.g., after transaction 1) and verify again

## Key Concepts for PITR

- **Base Backup**: Full copy of database at a point in time
- **WAL (Write-Ahead Log)**: Transaction log files that record all changes
- **WAL Archiving**: Saving WAL files for later replay during recovery
- **Recovery Target**: Specific time to recover to (timestamp)
- **restore_command**: Command to retrieve archived WAL files during recovery
- **recovery_target_time**: Timestamp to recover to (format: 'YYYY-MM-DD HH:MI:SS')
- **recovery.signal**: File that tells PostgreSQL to enter recovery mode
- **Verification**: **Critical step** - Proving recovery worked correctly by:
  - Checking transaction count matches expected
  - Verifying correct transactions exist
  - Confirming timestamps are before recovery target
  - Running comprehensive verification queries

## Common PITR Issues

**Problem**: Recovery doesn't stop at target time
- **Solution**: Check `recovery_target_time` format (use 'YYYY-MM-DD HH:MM:SS')

**Problem**: WAL files missing
- **Solution**: Ensure `archive_command` is working and WAL files are being saved

**Problem**: Can't verify recovery worked
- **Solution**: Use timestamps in your data, create audit tables, compare record counts

**Problem**: Recovery takes too long
- **Solution**: This is normal for large databases. Monitor logs for progress.

## Next Steps

Congratulations! You've completed all 10 exercises in the PostgreSQL Fundamentals course! 

You now know:
- ✅ Setting up PostgreSQL with Docker
- ✅ Creating databases and tables
- ✅ Inserting and querying data
- ✅ Understanding indexes
- ✅ Updating and deleting data
- ✅ Dropping tables safely
- ✅ Managing users and permissions
- ✅ VACUUM operations
- ✅ Backup and restore
- ✅ Point-in-Time Recovery with verification

Continue practicing and exploring PostgreSQL. Consider learning:
- Advanced SQL queries (JOINs, subqueries, window functions)
- Database design and normalization
- Performance tuning
- Replication and high availability
- PostgreSQL administration

Happy learning! 🎉

