# Exercise 9: VACUUM Operations

## Learning Objectives
- Understand what VACUUM does and why it's needed
- Learn about dead tuples and bloat
- Run VACUUM manually
- Understand VACUUM ANALYZE
- Learn about autovacuum
- Monitor vacuum operations

## What is VACUUM?

**VACUUM** is a maintenance operation that cleans up your PostgreSQL database. Think of it like cleaning up your room - removing things you don't need anymore.

### Why Do We Need VACUUM?

When you UPDATE or DELETE data in PostgreSQL:
- The old data isn't immediately removed
- It becomes "dead tuples" (unused rows)
- These dead tuples take up space
- Over time, this causes "bloat" (wasted space)
- Queries can slow down

**VACUUM**:
- Removes dead tuples
- Reclaims disk space
- Updates statistics for the query planner
- Prevents transaction ID wraparound issues

## Understanding Dead Tuples

Let's see this in action:

### Step 1: Connect to Database

```bash
docker exec -it my-postgres psql -U postgres -d ecommerce
```

### Step 2: Create and Populate a Table

```sql
CREATE TABLE test_vacuum (
    id SERIAL PRIMARY KEY,
    data TEXT
);

-- Insert 1000 rows
INSERT INTO test_vacuum (data)
SELECT 'Row ' || generate_series(1, 1000);
```

### Step 3: Check Table Size

See how much space the table uses:

```sql
SELECT 
    pg_size_pretty(pg_total_relation_size('test_vacuum')) AS total_size,
    pg_size_pretty(pg_relation_size('test_vacuum')) AS table_size;
```

### Step 4: Delete Some Rows (Create Dead Tuples)

Delete half the rows:

```sql
DELETE FROM test_vacuum WHERE id % 2 = 0;
```

This deletes rows with even IDs (500 rows).

### Step 5: Check Size Again (Still Large!)

```sql
SELECT 
    pg_size_pretty(pg_total_relation_size('test_vacuum')) AS total_size,
    pg_size_pretty(pg_relation_size('test_vacuum')) AS table_size;
```

Notice the size is still the same! The deleted rows are still taking up space (they're "dead tuples").

### Step 6: Count Dead Tuples

See how many dead tuples exist:

```sql
SELECT 
    schemaname,
    tablename,
    n_dead_tup,
    n_live_tup,
    last_vacuum,
    last_autovacuum
FROM pg_stat_user_tables
WHERE tablename = 'test_vacuum';
```

You should see `n_dead_tup` showing around 500 dead tuples.

### Step 7: Run VACUUM

Now let's clean up:

```sql
VACUUM test_vacuum;
```

### Step 8: Check Size After VACUUM

```sql
SELECT 
    pg_size_pretty(pg_total_relation_size('test_vacuum')) AS total_size,
    pg_size_pretty(pg_relation_size('test_vacuum')) AS table_size;
```

The size should be smaller now! VACUUM reclaimed the space.

### Step 9: Check Dead Tuples Again

```sql
SELECT 
    n_dead_tup,
    n_live_tup,
    last_vacuum
FROM pg_stat_user_tables
WHERE tablename = 'test_vacuum';
```

`n_dead_tup` should be 0 or very low now.

## Types of VACUUM

### 1. VACUUM (Standard)

Cleans up dead tuples but doesn't lock the table:

```sql
VACUUM table_name;
```

- Can run while database is in use
- Doesn't block reads/writes
- Doesn't reclaim space to OS (keeps it for future use)

### 2. VACUUM FULL

More aggressive, locks the table:

```sql
VACUUM FULL table_name;
```

- Reclaims space to operating system
- Locks the table (blocks operations)
- Slower than regular VACUUM
- Use only when you need to reclaim disk space

⚠️ **Warning**: VACUUM FULL locks the table. Use sparingly!

### 3. VACUUM ANALYZE

Cleans up AND updates statistics:

```sql
VACUUM ANALYZE table_name;
```

**ANALYZE** updates table statistics that help the query planner choose the best execution plan.

### 4. VACUUM VERBOSE

Shows detailed information:

```sql
VACUUM VERBOSE table_name;
```

Shows what VACUUM is doing.

## VACUUM on Entire Database

Vacuum all tables in the current database:

```sql
VACUUM;
```

Vacuum all tables with analyze:

```sql
VACUUM ANALYZE;
```

## Autovacuum

PostgreSQL automatically runs VACUUM in the background! This is called **autovacuum**.

### Check Autovacuum Status

```sql
-- See autovacuum settings
SHOW autovacuum;

-- See when autovacuum last ran
SELECT 
    schemaname,
    tablename,
    last_autovacuum,
    last_autoanalyze,
    n_dead_tup,
    n_live_tup
FROM pg_stat_user_tables
ORDER BY last_autovacuum DESC NULLS LAST;
```

### When Autovacuum Runs

Autovacuum automatically runs when:
- A table has enough dead tuples (threshold based on table size)
- A certain amount of time has passed
- Transaction ID wraparound is approaching

### Disable Autovacuum (Not Recommended!)

```sql
-- Disable for a specific table (usually not needed)
ALTER TABLE table_name SET (autovacuum_enabled = false);
```

**Generally, you should leave autovacuum enabled!**

## Monitoring VACUUM

### View VACUUM Statistics

```sql
-- Tables that need vacuuming
SELECT 
    schemaname,
    tablename,
    n_dead_tup,
    n_live_tup,
    ROUND(n_dead_tup * 100.0 / NULLIF(n_live_tup + n_dead_tup, 0), 2) AS dead_pct,
    last_vacuum,
    last_autovacuum
FROM pg_stat_user_tables
WHERE n_dead_tup > 0
ORDER BY n_dead_tup DESC;
```

### Tables with Most Bloat

```sql
SELECT 
    schemaname,
    tablename,
    pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) AS size,
    n_dead_tup,
    n_live_tup
FROM pg_stat_user_tables
ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC
LIMIT 10;
```

## When to Run VACUUM Manually

Usually, autovacuum handles it. But you might need manual VACUUM when:

1. **After large DELETE operations**
   ```sql
   DELETE FROM large_table WHERE condition;
   VACUUM ANALYZE large_table;
   ```

2. **After bulk updates**
   ```sql
   UPDATE large_table SET column = value;
   VACUUM ANALYZE large_table;
   ```

3. **Before important queries** (to update statistics)
   ```sql
   VACUUM ANALYZE table_name;
   ```

4. **When you need to reclaim disk space**
   ```sql
   VACUUM FULL table_name;  -- Use carefully!
   ```

## Best Practices

### 1. Let Autovacuum Do Its Job

In most cases, autovacuum is sufficient. Don't disable it!

### 2. Monitor Regularly

Check vacuum statistics regularly to ensure autovacuum is working:

```sql
SELECT * FROM pg_stat_user_tables 
WHERE last_autovacuum IS NULL 
   OR last_autovacuum < NOW() - INTERVAL '7 days';
```

### 3. VACUUM ANALYZE After Schema Changes

After creating indexes or changing table structure:

```sql
VACUUM ANALYZE table_name;
```

### 4. Use VACUUM FULL Sparingly

Only use `VACUUM FULL` when you really need to reclaim disk space, and during maintenance windows.

## Useful Commands

```sql
-- Vacuum a specific table
VACUUM table_name;

-- Vacuum with analyze
VACUUM ANALYZE table_name;

-- Vacuum full (aggressive)
VACUUM FULL table_name;

-- Vacuum verbose (see details)
VACUUM VERBOSE table_name;

-- Vacuum entire database
VACUUM;

-- Check table statistics
SELECT * FROM pg_stat_user_tables WHERE tablename = 'table_name';

-- Check table size
SELECT pg_size_pretty(pg_total_relation_size('table_name'));

-- View autovacuum settings
SHOW autovacuum;
```

## Practice Tasks

1. Create a table and insert 1000 rows

2. Delete 300 rows and check the number of dead tuples

3. Run VACUUM and verify dead tuples are cleaned up

4. Check the table size before and after VACUUM

5. Run VACUUM ANALYZE on a table

6. Use VACUUM VERBOSE to see detailed output

7. Check when autovacuum last ran on your tables

8. Find tables with the most dead tuples

9. Update many rows in a table, then run VACUUM ANALYZE

10. Monitor vacuum statistics and identify tables that might need attention

## Key Concepts

- **VACUUM**: Cleans up dead tuples and reclaims space
- **Dead Tuples**: Rows that were deleted or updated (old versions)
- **Bloat**: Wasted space from dead tuples
- **Autovacuum**: Automatic background vacuum process
- **VACUUM ANALYZE**: Vacuums and updates statistics
- **VACUUM FULL**: Aggressive vacuum that locks table
- **Statistics**: Information about data distribution used by query planner

## Common Issues

**Problem**: Table size not decreasing after DELETE
- **Solution**: Run VACUUM. Space is kept for future inserts, but dead tuples are removed.

**Problem**: Autovacuum not running
- **Solution**: Check if autovacuum is enabled: `SHOW autovacuum;` Check logs for errors.

**Problem**: VACUUM taking too long
- **Solution**: This is normal for large tables. VACUUM is designed to run incrementally. Consider running during off-peak hours.

**Problem**: Need to reclaim disk space immediately
- **Solution**: Use VACUUM FULL during a maintenance window (it locks the table).

## Next Steps

Excellent! You now understand VACUUM and database maintenance. In the final exercise, we'll learn about backing up and restoring databases.

