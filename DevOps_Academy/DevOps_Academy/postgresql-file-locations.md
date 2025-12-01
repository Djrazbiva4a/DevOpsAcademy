# PostgreSQL File Locations Reference

This document contains commands to explore all PostgreSQL file locations in your Docker container.

## Quick Reference: Main Directories

**Base Data Directory**: `/var/lib/postgresql/data`

All PostgreSQL files are stored under this directory in the Docker container.

---

## 1. Configuration Files

### Main Configuration File
```bash
# Show location of main config file
docker exec my-postgres psql -U postgres -c "SHOW config_file;"

# View the configuration file
docker exec my-postgres cat /var/lib/postgresql/data/postgresql.conf

# View auto-generated config (runtime changes)
docker exec my-postgres cat /var/lib/postgresql/data/postgresql.auto.conf
```

### Authentication Configuration
```bash
# Show location of pg_hba.conf (host-based authentication)
docker exec my-postgres psql -U postgres -c "SHOW hba_file;"

# View pg_hba.conf
docker exec my-postgres cat /var/lib/postgresql/data/pg_hba.conf

# View pg_ident.conf (user name mapping)
docker exec my-postgres cat /var/lib/postgresql/data/pg_ident.conf
```

### View All Configuration Settings
```bash
# Show all configuration parameters
docker exec my-postgres psql -U postgres -c "SELECT name, setting, source FROM pg_settings ORDER BY name;"

# Show only file locations
docker exec my-postgres psql -U postgres -c "SELECT name, setting FROM pg_settings WHERE name LIKE '%file%' OR name LIKE '%directory%' OR name LIKE '%dir%';"
```

---

## 2. Data Files (Database Files)

### Main Data Directory
```bash
# Show data directory location
docker exec my-postgres psql -U postgres -c "SHOW data_directory;"

# List all databases and their OIDs (Object Identifiers)
docker exec my-postgres psql -U postgres -c "SELECT oid, datname FROM pg_database ORDER BY oid;"

# Show database file locations
docker exec my-postgres bash -c "ls -la /var/lib/postgresql/data/base/"
```

### Database-Specific Data Files
```bash
# Find which database is in which directory
# Each database has a subdirectory in /base/ named after its OID
docker exec my-postgres psql -U postgres -c "SELECT oid, datname FROM pg_database;"

# Example: List files for a specific database (replace OID with actual OID)
# For 'mydb' database:
docker exec my-postgres bash -c "ls -lh /var/lib/postgresql/data/base/16384/ | head -20"

# Show size of each database directory
docker exec my-postgres bash -c "du -sh /var/lib/postgresql/data/base/*"
```

### Find Table Files
```bash
# Connect to a database and find table file locations
docker exec my-postgres psql -U postgres -d mydb -c "
SELECT 
    schemaname,
    tablename,
    pg_relation_filepath(schemaname||'.'||tablename) as filepath
FROM pg_tables
WHERE schemaname NOT IN ('pg_catalog', 'information_schema')
ORDER BY schemaname, tablename;"
```

---

## 3. WAL (Write-Ahead Log) Files

### WAL Directory Location
```bash
# WAL files are stored in pg_wal subdirectory
docker exec my-postgres bash -c "ls -lh /var/lib/postgresql/data/pg_wal/"

# Show WAL directory size
docker exec my-postgres bash -c "du -sh /var/lib/postgresql/data/pg_wal"

# Count WAL files
docker exec my-postgres bash -c "ls -1 /var/lib/postgresql/data/pg_wal/*.wal 2>/dev/null | wc -l"

# Show WAL settings
docker exec my-postgres psql -U postgres -c "SELECT name, setting FROM pg_settings WHERE name LIKE '%wal%' ORDER BY name;"
```

### WAL Archive Status (if archiving is enabled)
```bash
# Check archive status directory
docker exec my-postgres bash -c "ls -la /var/lib/postgresql/data/pg_wal/archive_status/"

# Check if archiving is enabled
docker exec my-postgres psql -U postgres -c "SHOW archive_mode;"
```

---

## 4. Backup Files

### Default Backup Locations
```bash
# PostgreSQL doesn't have a default backup directory
# Backups are typically stored outside the data directory
# Check if you've created any backup directories
docker exec my-postgres bash -c "find /var/lib/postgresql -name '*backup*' -o -name '*dump*' 2>/dev/null"

# Check for pg_basebackup output (if used)
docker exec my-postgres bash -c "ls -la /var/lib/postgresql/ 2>/dev/null"
```

### View Backup-Related Settings
```bash
# Show backup/archive settings
docker exec my-postgres psql -U postgres -c "SELECT name, setting FROM pg_settings WHERE name LIKE '%archive%' OR name LIKE '%backup%' ORDER BY name;"
```

**Note**: In Docker, backups are typically stored on the host machine or in mounted volumes, not inside the container.

---

## 5. Log Files

### Log Directory
```bash
# Show log directory location
docker exec my-postgres psql -U postgres -c "SHOW log_directory;"

# List log files (if logging to files)
docker exec my-postgres bash -c "ls -lh /var/lib/postgresql/data/log/ 2>/dev/null || echo 'Logs may be going to stdout/stderr'"

# View PostgreSQL logs via Docker
docker logs my-postgres

# View last 100 lines of logs
docker logs --tail 100 my-postgres

# Follow logs in real-time
docker logs -f my-postgres
```

### Log Settings
```bash
# Show logging configuration
docker exec my-postgres psql -U postgres -c "SELECT name, setting FROM pg_settings WHERE name LIKE '%log%' ORDER BY name;"
```

---

## 6. All Supporting Directories

### Complete Directory Structure
```bash
# List all directories in data directory with sizes
docker exec my-postgres bash -c "du -sh /var/lib/postgresql/data/* 2>/dev/null | sort -h"

# Detailed listing of all files and directories
docker exec my-postgres bash -c "ls -lah /var/lib/postgresql/data/"

# Tree view (if tree is installed)
docker exec my-postgres bash -c "tree -L 2 /var/lib/postgresql/data/ 2>/dev/null || find /var/lib/postgresql/data -maxdepth 2 -type d | sort"
```

### Key Directory Explanations

| Directory | Purpose |
|-----------|---------|
| `base/` | Database files (one subdirectory per database, named by OID) |
| `global/` | Cluster-wide tables (shared system catalogs) |
| `pg_wal/` | Write-Ahead Log files (transaction logs) |
| `pg_xact/` | Transaction commit status data |
| `pg_multixact/` | Multi-transaction status data |
| `pg_subtrans/` | Subtransaction status data |
| `pg_twophase/` | Two-phase commit state files |
| `pg_commit_ts/` | Transaction commit timestamps |
| `pg_logical/` | Logical decoding data |
| `pg_replslot/` | Replication slot data |
| `pg_stat/` | Permanent statistics files |
| `pg_stat_tmp/` | Temporary statistics files |
| `pg_snapshots/` | Exported snapshots |
| `pg_serial/` | Serializable transaction information |
| `pg_tblspc/` | Tablespace symbolic links |
| `pg_notify/` | LISTEN/NOTIFY status files |

---

## 7. Comprehensive Exploration Commands

### Get All Important Paths at Once
```bash
docker exec my-postgres psql -U postgres -c "
SELECT 
    'Data Directory' as location_type,
    setting as path
FROM pg_settings 
WHERE name = 'data_directory'
UNION ALL
SELECT 
    'Config File',
    setting
FROM pg_settings 
WHERE name = 'config_file'
UNION ALL
SELECT 
    'HBA File',
    setting
FROM pg_settings 
WHERE name = 'hba_file'
UNION ALL
SELECT 
    'Log Directory',
    setting
FROM pg_settings 
WHERE name = 'log_directory';"
```

### Show Database Sizes and Locations
```bash
docker exec my-postgres psql -U postgres -c "
SELECT 
    d.datname as database_name,
    d.oid as database_oid,
    pg_size_pretty(pg_database_size(d.datname)) as size,
    '/var/lib/postgresql/data/base/' || d.oid as data_directory
FROM pg_database d
ORDER BY pg_database_size(d.datname) DESC;"
```

### Show All Tablespaces
```bash
docker exec my-postgres psql -U postgres -c "
SELECT 
    spcname as tablespace_name,
    pg_tablespace_location(oid) as location
FROM pg_tablespace;"
```

---

## 8. Accessing Files from Host Machine

### Copy Files from Container to Host
```bash
# Copy configuration file to host
docker cp my-postgres:/var/lib/postgresql/data/postgresql.conf ./postgresql.conf

# Copy entire data directory (WARNING: large!)
docker cp my-postgres:/var/lib/postgresql/data ./postgresql-data-backup

# Copy WAL files
docker cp my-postgres:/var/lib/postgresql/data/pg_wal ./wal-backup
```

### Mount Data Directory (for persistent storage)
If you want to access files directly from the host, you can mount a volume:
```bash
# Stop current container
docker stop my-postgres

# Remove container (data will be lost unless you copy it first!)
docker rm my-postgres

# Run with volume mount
docker run --name my-postgres \
  -e POSTGRES_PASSWORD=mysecretpassword \
  -e POSTGRES_USER=postgres \
  -e POSTGRES_DB=mydb \
  -p 5432:5432 \
  -v $(pwd)/postgres-data:/var/lib/postgresql/data \
  -d postgres:15
```

---

## 9. Quick Status Check

### One-Liner to Show Everything Important
```bash
docker exec my-postgres bash -c "
echo '=== Data Directory ==='
psql -U postgres -t -c 'SHOW data_directory;'
echo ''
echo '=== Database Sizes ==='
psql -U postgres -c 'SELECT datname, pg_size_pretty(pg_database_size(datname)) as size FROM pg_database;'
echo ''
echo '=== WAL Directory Size ==='
du -sh /var/lib/postgresql/data/pg_wal
echo ''
echo '=== Top 10 Largest Directories ==='
du -sh /var/lib/postgresql/data/* 2>/dev/null | sort -h | tail -10
"
```

---

## 10. Finding Specific Files

### Find All Configuration Files
```bash
docker exec my-postgres bash -c "find /var/lib/postgresql/data -name '*.conf' -type f"
```

### Find All Log Files
```bash
docker exec my-postgres bash -c "find /var/lib/postgresql/data -name '*.log' -o -name '*.log.*' 2>/dev/null"
```

### Find All Lock Files
```bash
docker exec my-postgres bash -c "find /var/lib/postgresql/data -name '*.lock' -o -name '*.pid' 2>/dev/null"
```

### Find Large Files
```bash
docker exec my-postgres bash -c "find /var/lib/postgresql/data -type f -size +10M -exec ls -lh {} \;"
```

---

## Notes

- **Data Persistence**: By default, Docker containers store data inside the container. If you remove the container, data is lost unless you use volumes.
- **File Permissions**: All files are owned by the `postgres` user inside the container.
- **Access**: You need to use `docker exec` to access files inside the container, or mount volumes to access from the host.
- **Backups**: Always backup before making changes to configuration files or data files.

