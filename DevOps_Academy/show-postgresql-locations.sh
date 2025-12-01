#!/bin/bash

# PostgreSQL File Locations Explorer
# This script shows all important PostgreSQL file locations in your Docker container

CONTAINER_NAME="my-postgres"

echo "=========================================="
echo "PostgreSQL File Locations Explorer"
echo "=========================================="
echo ""

# Check if container is running
if ! docker ps | grep -q "$CONTAINER_NAME"; then
    echo "ERROR: Container '$CONTAINER_NAME' is not running!"
    echo "Start it with: docker start $CONTAINER_NAME"
    exit 1
fi

echo "=== 1. MAIN CONFIGURATION PATHS ==="
docker exec $CONTAINER_NAME psql -U postgres -t -c "
SELECT 
    'Data Directory: ' || setting
FROM pg_settings WHERE name = 'data_directory'
UNION ALL
SELECT 
    'Config File: ' || setting
FROM pg_settings WHERE name = 'config_file'
UNION ALL
SELECT 
    'HBA File: ' || setting
FROM pg_settings WHERE name = 'hba_file'
UNION ALL
SELECT 
    'Log Directory: ' || setting
FROM pg_settings WHERE name = 'log_directory';"
echo ""

echo "=== 2. DATABASE FILES (Data Files) ==="
echo "Base directory: /var/lib/postgresql/data/base/"
echo ""
echo "Databases and their file locations:"
docker exec $CONTAINER_NAME psql -U postgres -c "
SELECT 
    datname as database_name,
    oid as database_oid,
    pg_size_pretty(pg_database_size(datname)) as size,
    '/var/lib/postgresql/data/base/' || oid as data_directory
FROM pg_database
ORDER BY pg_database_size(datname) DESC;"
echo ""

echo "=== 3. WAL (Write-Ahead Log) FILES ==="
echo "Location: /var/lib/postgresql/data/pg_wal/"
docker exec $CONTAINER_NAME bash -c "
echo 'WAL Directory Size:'
du -sh /var/lib/postgresql/data/pg_wal 2>/dev/null
echo ''
echo 'WAL files (WAL files are named with 24 hex characters):'
ls -lh /var/lib/postgresql/data/pg_wal/ | grep -v '^d' | grep -v '^total' | head -10
echo ''
echo 'Number of WAL segment files:'
ls -1 /var/lib/postgresql/data/pg_wal/ | grep -v '^archive_status$' | wc -l
"
echo ""

echo "=== 4. CONFIGURATION FILES ==="
docker exec $CONTAINER_NAME bash -c "
echo 'Main config files:'
ls -lh /var/lib/postgresql/data/*.conf 2>/dev/null
echo ''
echo 'Config file locations:'
echo '  - Main: /var/lib/postgresql/data/postgresql.conf'
echo '  - Auto: /var/lib/postgresql/data/postgresql.auto.conf'
echo '  - HBA:  /var/lib/postgresql/data/pg_hba.conf'
echo '  - Ident: /var/lib/postgresql/data/pg_ident.conf'
"
echo ""

echo "=== 5. LOG FILES ==="
docker exec $CONTAINER_NAME bash -c "
if [ -d /var/lib/postgresql/data/log ]; then
    echo 'Log files in data directory:'
    ls -lh /var/lib/postgresql/data/log/ 2>/dev/null | head -10
else
    echo 'Logs are going to stdout/stderr (view with: docker logs $CONTAINER_NAME)'
fi
"
echo ""

echo "=== 6. BACKUP FILES ==="
echo "Note: PostgreSQL doesn't have a default backup directory."
echo "Backups are typically stored outside the container or in mounted volumes."
docker exec $CONTAINER_NAME bash -c "
echo 'Searching for backup-related files in container:'
find /var/lib/postgresql -name '*backup*' -o -name '*dump*' 2>/dev/null | head -10 || echo '  (none found)'
"
echo ""

echo "=== 7. DIRECTORY STRUCTURE & SIZES ==="
echo "All directories in data directory:"
docker exec $CONTAINER_NAME bash -c "du -sh /var/lib/postgresql/data/* 2>/dev/null | sort -h"
echo ""

echo "=== 8. KEY DIRECTORIES EXPLANATION ==="
echo "base/          - Database files (one subdirectory per database)"
echo "global/        - Cluster-wide system catalogs"
echo "pg_wal/        - Write-Ahead Log files (transaction logs)"
echo "pg_xact/       - Transaction commit status"
echo "pg_multixact/  - Multi-transaction status"
echo "pg_subtrans/   - Subtransaction status"
echo "pg_twophase/   - Two-phase commit state"
echo "pg_commit_ts/  - Transaction commit timestamps"
echo "pg_logical/    - Logical decoding data"
echo "pg_replslot/   - Replication slot data"
echo "pg_stat/       - Permanent statistics"
echo "pg_stat_tmp/   - Temporary statistics"
echo "pg_snapshots/  - Exported snapshots"
echo "pg_serial/     - Serializable transaction info"
echo "pg_tblspc/     - Tablespace symbolic links"
echo "pg_notify/     - LISTEN/NOTIFY status"
echo ""

echo "=== 9. QUICK ACCESS COMMANDS ==="
echo ""
echo "View main config:"
echo "  docker exec $CONTAINER_NAME cat /var/lib/postgresql/data/postgresql.conf"
echo ""
echo "View HBA config:"
echo "  docker exec $CONTAINER_NAME cat /var/lib/postgresql/data/pg_hba.conf"
echo ""
echo "List WAL files:"
echo "  docker exec $CONTAINER_NAME ls -lh /var/lib/postgresql/data/pg_wal/"
echo ""
echo "View logs:"
echo "  docker logs $CONTAINER_NAME"
echo ""
echo "List all databases with sizes:"
echo "  docker exec $CONTAINER_NAME psql -U postgres -c \"SELECT datname, pg_size_pretty(pg_database_size(datname)) FROM pg_database;\""
echo ""
echo "Copy config to host:"
echo "  docker cp $CONTAINER_NAME:/var/lib/postgresql/data/postgresql.conf ./"
echo ""

echo "=========================================="
echo "For more details, see: postgresql-file-locations.md"
echo "=========================================="

