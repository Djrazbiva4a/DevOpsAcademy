#!/bin/bash

# Lesson 1 Demonstration Script
# This script demonstrates all concepts from Lesson 1

CONTAINER_NAME="my-postgres"

echo "=========================================="
echo "Lesson 1: PostgreSQL Fundamentals Demo"
echo "=========================================="
echo ""

# Check if container is running
if ! docker ps | grep -q "$CONTAINER_NAME"; then
    echo "ERROR: Container '$CONTAINER_NAME' is not running!"
    echo "Start it with: docker start $CONTAINER_NAME"
    exit 1
fi

echo "=== PART 1: Database Files ==="
echo ""
echo "1. Data Directory Location:"
docker exec $CONTAINER_NAME psql -U postgres -t -c "SHOW data_directory;"
echo ""

echo "2. Database OIDs and File Locations:"
docker exec $CONTAINER_NAME psql -U postgres -c "
SELECT 
    datname as database_name,
    oid as database_oid,
    '/var/lib/postgresql/data/base/' || oid as file_location
FROM pg_database
WHERE datname NOT IN ('template0', 'template1')
ORDER BY oid;"
echo ""

echo "3. Directory Structure:"
docker exec $CONTAINER_NAME bash -c "ls -1 /var/lib/postgresql/data/ | grep -E '^[a-z]' | head -10"
echo ""

echo "=== PART 2: Backups ==="
echo ""
echo "Creating a test database for backup demonstration..."
docker exec $CONTAINER_NAME psql -U postgres -c "DROP DATABASE IF EXISTS backup_demo;" 2>/dev/null
docker exec $CONTAINER_NAME psql -U postgres -c "CREATE DATABASE backup_demo;"
docker exec $CONTAINER_NAME psql -U postgres -d backup_demo -c "
CREATE TABLE test_data (id SERIAL PRIMARY KEY, name VARCHAR(100));
INSERT INTO test_data (name) VALUES ('Record 1'), ('Record 2'), ('Record 3');"
echo "✓ Test database created"
echo ""

echo "1. SQL Dump Backup:"
docker exec $CONTAINER_NAME pg_dump -U postgres -d backup_demo > /tmp/backup_demo.sql 2>/dev/null
if [ -f /tmp/backup_demo.sql ]; then
    echo "✓ SQL backup created: $(wc -l < /tmp/backup_demo.sql) lines"
    echo "  First few lines:"
    head -5 /tmp/backup_demo.sql | sed 's/^/    /'
else
    echo "✗ Backup failed"
fi
echo ""

echo "2. Custom Format Backup:"
docker exec $CONTAINER_NAME pg_dump -U postgres -d backup_demo -Fc -f /tmp/backup_demo.dump 2>/dev/null
if docker exec $CONTAINER_NAME test -f /tmp/backup_demo.dump; then
    SIZE=$(docker exec $CONTAINER_NAME stat -c%s /tmp/backup_demo.dump 2>/dev/null || echo "0")
    echo "✓ Custom format backup created: ${SIZE} bytes"
else
    echo "✗ Backup failed"
fi
echo ""

echo "=== PART 3: Users ==="
echo ""
echo "Current Users:"
docker exec $CONTAINER_NAME psql -U postgres -c "
SELECT 
    rolname as username,
    rolsuper as is_superuser,
    rolcanlogin as can_login
FROM pg_roles
WHERE rolcanlogin = true
ORDER BY rolname;"
echo ""

echo "Creating demo users..."
docker exec $CONTAINER_NAME psql -U postgres -c "
DO \$\$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'demo_alice') THEN
        CREATE USER demo_alice WITH PASSWORD 'demo123';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'demo_bob') THEN
        CREATE USER demo_bob WITH PASSWORD 'demo123';
    END IF;
END
\$\$;" 2>/dev/null
echo "✓ Demo users created (if they didn't exist)"
echo ""

echo "=== PART 4: Schemas ==="
echo ""
echo "Schemas in current database:"
docker exec $CONTAINER_NAME psql -U postgres -d postgres -c "
SELECT schema_name 
FROM information_schema.schemata
WHERE schema_name NOT IN ('pg_catalog', 'information_schema', 'pg_toast')
ORDER BY schema_name;"
echo ""

echo "=== PART 5: Tables ==="
echo ""
echo "Tables in 'backup_demo' database:"
docker exec $CONTAINER_NAME psql -U postgres -d backup_demo -c "
SELECT 
    schemaname,
    tablename,
    pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) as size
FROM pg_tables
WHERE schemaname = 'public'
ORDER BY tablename;"
echo ""

echo "=== PART 6: Logs ==="
echo ""
echo "Recent log entries (last 5 lines):"
docker logs --tail 5 $CONTAINER_NAME 2>&1 | sed 's/^/    /'
echo ""

echo "Logging configuration:"
docker exec $CONTAINER_NAME psql -U postgres -t -c "
SELECT name || ' = ' || setting 
FROM pg_settings 
WHERE name IN ('log_connections', 'log_statement', 'logging_collector')
ORDER BY name;" | sed 's/^/    /'
echo ""

echo "=== PART 7: Configuration Files ==="
echo ""
echo "Configuration file locations:"
docker exec $CONTAINER_NAME psql -U postgres -t -c "
SELECT 
    'Config File: ' || setting
FROM pg_settings WHERE name = 'config_file'
UNION ALL
SELECT 
    'HBA File: ' || setting
FROM pg_settings WHERE name = 'hba_file';" | sed 's/^/    /'
echo ""

echo "Key configuration settings:"
docker exec $CONTAINER_NAME psql -U postgres -t -c "
SELECT name || ' = ' || setting 
FROM pg_settings 
WHERE name IN ('max_connections', 'shared_buffers', 'work_mem', 'maintenance_work_mem')
ORDER BY name;" | sed 's/^/    /'
echo ""

echo "=== PART 8: Tablespaces ==="
echo ""
echo "Available tablespaces:"
docker exec $CONTAINER_NAME psql -U postgres -c "
SELECT 
    spcname as tablespace_name,
    CASE 
        WHEN pg_tablespace_location(oid) = '' THEN 'default location'
        ELSE pg_tablespace_location(oid)
    END as location
FROM pg_tablespace
ORDER BY spcname;"
echo ""

echo "=== PART 9: User Activity Logging ==="
echo ""
echo "Current active connections:"
docker exec $CONTAINER_NAME psql -U postgres -c "
SELECT 
    usename,
    datname,
    application_name,
    state,
    COUNT(*) as connection_count
FROM pg_stat_activity
WHERE datname IS NOT NULL
GROUP BY usename, datname, application_name, state
ORDER BY usename, datname;" 2>/dev/null || echo "    (No active connections)"
echo ""

echo "=== PART 10: Ownership and Permissions Demo ==="
echo ""
echo "Setting up ownership demonstration..."

# Create databases for demo users
docker exec $CONTAINER_NAME psql -U postgres -c "
DROP DATABASE IF EXISTS alice_demo;
DROP DATABASE IF EXISTS bob_demo;
CREATE DATABASE alice_demo OWNER demo_alice;
CREATE DATABASE bob_demo OWNER demo_bob;" 2>/dev/null

# Create tables as each user
docker exec $CONTAINER_NAME psql -U demo_alice -d alice_demo -c "
CREATE TABLE alice_table (id SERIAL PRIMARY KEY, data TEXT);
INSERT INTO alice_table (data) VALUES ('Alice owns this');" 2>/dev/null

docker exec $CONTAINER_NAME psql -U demo_bob -d bob_demo -c "
CREATE TABLE bob_table (id SERIAL PRIMARY KEY, data TEXT);
INSERT INTO bob_table (data) VALUES ('Bob owns this');" 2>/dev/null

echo "✓ Demo databases and tables created"
echo ""

echo "Database ownership:"
docker exec $CONTAINER_NAME psql -U postgres -c "
SELECT 
    datname,
    pg_catalog.pg_get_userbyid(datdba) as owner
FROM pg_database
WHERE datname IN ('alice_demo', 'bob_demo')
ORDER BY datname;"
echo ""

echo "Table ownership:"
docker exec $CONTAINER_NAME psql -U postgres -d alice_demo -c "
SELECT 
    schemaname,
    tablename,
    tableowner
FROM pg_tables
WHERE schemaname = 'public';" 2>/dev/null

docker exec $CONTAINER_NAME psql -U postgres -d bob_demo -c "
SELECT 
    schemaname,
    tablename,
    tableowner
FROM pg_tables
WHERE schemaname = 'public';" 2>/dev/null
echo ""

echo "Testing permissions (bob trying to access alice's table):"
docker exec $CONTAINER_NAME psql -U demo_bob -d alice_demo -c "SELECT * FROM alice_table;" 2>&1 | grep -E "(ERROR|Alice)" | head -2 | sed 's/^/    /'
echo "    (Expected: permission denied)"
echo ""

echo "=========================================="
echo "Demo Complete!"
echo "=========================================="
echo ""
echo "Next steps:"
echo "1. Review lesson-01-postgresql-fundamentals.md for detailed explanations"
echo "2. Try the hands-on exercises in the lesson"
echo "3. Experiment with creating users, tables, and testing permissions"
echo ""
echo "Useful commands:"
echo "  - View logs: docker logs $CONTAINER_NAME"
echo "  - Connect to DB: docker exec -it $CONTAINER_NAME psql -U postgres"
echo "  - List users: docker exec $CONTAINER_NAME psql -U postgres -c '\\du'"
echo "  - List databases: docker exec $CONTAINER_NAME psql -U postgres -c '\\l'"
echo ""

