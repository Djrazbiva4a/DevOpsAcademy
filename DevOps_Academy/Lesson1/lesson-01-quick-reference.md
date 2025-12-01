# Lesson 1: Quick Reference Guide

## Quick Commands Cheat Sheet

### Database Files

```bash
# Find data directory
docker exec my-postgres psql -U postgres -c "SHOW data_directory;"

# List database OIDs and file locations
docker exec my-postgres psql -U postgres -c "
SELECT datname, oid, '/var/lib/postgresql/data/base/' || oid as path 
FROM pg_database;"

# List files in database directory
docker exec my-postgres ls -la /var/lib/postgresql/data/base/16384/

# Find table file locations
docker exec my-postgres psql -U postgres -d mydb -c "
SELECT tablename, pg_relation_filepath('public.'||tablename) 
FROM pg_tables WHERE schemaname='public';"
```

### Backups

```bash
# SQL Dump
docker exec my-postgres pg_dump -U postgres -d mydb > backup.sql

# Custom Format
docker exec my-postgres pg_dump -U postgres -d mydb -Fc -f /tmp/backup.dump

# All Databases
docker exec my-postgres pg_dumpall -U postgres > all_backup.sql

# Restore SQL
docker exec -i my-postgres psql -U postgres -d mydb < backup.sql

# Restore Custom
docker exec my-postgres pg_restore -U postgres -d mydb /tmp/backup.dump
```

### Users

```bash
# List users
docker exec my-postgres psql -U postgres -c "\du"

# Create user
docker exec my-postgres psql -U postgres -c "CREATE USER alice WITH PASSWORD 'pass123';"

# Connect as user
docker exec -it my-postgres psql -U alice -d mydb
```

### Schemas

```bash
# List schemas
docker exec my-postgres psql -U postgres -c "\dn"

# Create schema
docker exec my-postgres psql -U postgres -c "CREATE SCHEMA hr;"

# Create table in schema
docker exec my-postgres psql -U postgres -c "CREATE TABLE hr.employees (...);"
```

### Tables

```bash
# List tables
docker exec my-postgres psql -U postgres -d mydb -c "\dt"

# Show table size
docker exec my-postgres psql -U postgres -d mydb -c "
SELECT tablename, pg_size_pretty(pg_total_relation_size('public.'||tablename)) 
FROM pg_tables WHERE schemaname='public';"
```

### Logs

```bash
# View logs
docker logs my-postgres

# Follow logs
docker logs -f my-postgres

# Last 100 lines
docker logs --tail 100 my-postgres

# Enable connection logging
docker exec my-postgres psql -U postgres -c "
ALTER SYSTEM SET log_connections = 'on';
SELECT pg_reload_conf();"
```

### Configuration

```bash
# View config file location
docker exec my-postgres psql -U postgres -c "SHOW config_file;"

# View config file
docker exec my-postgres cat /var/lib/postgresql/data/postgresql.conf

# View HBA file
docker exec my-postgres cat /var/lib/postgresql/data/pg_hba.conf

# Change setting
docker exec my-postgres psql -U postgres -c "
ALTER SYSTEM SET max_connections = 200;
SELECT pg_reload_conf();"
```

### Tablespaces

```bash
# List tablespaces
docker exec my-postgres psql -U postgres -c "\db"

# Create tablespace (requires directory)
docker exec my-postgres mkdir -p /var/lib/postgresql/tablespaces/fast
docker exec my-postgres psql -U postgres -c "
CREATE TABLESPACE fast LOCATION '/var/lib/postgresql/tablespaces/fast';"
```

### Ownership & Permissions

```bash
# Create database with owner
docker exec my-postgres psql -U postgres -c "
CREATE DATABASE mydb OWNER alice;"

# Grant permissions
docker exec my-postgres psql -U postgres -d mydb -c "
GRANT SELECT ON table_name TO alice;
GRANT ALL PRIVILEGES ON table_name TO alice;"

# Transfer ownership
docker exec my-postgres psql -U postgres -d mydb -c "
ALTER TABLE table_name OWNER TO alice;"

# View table ownership
docker exec my-postgres psql -U postgres -d mydb -c "
SELECT tablename, tableowner FROM pg_tables;"
```

## Key Concepts Summary

| Concept | What It Is | Key Command |
|---------|------------|-------------|
| **Database Files** | Physical storage on disk | `/var/lib/postgresql/data/base/{OID}/` |
| **Backup** | Copy of database | `pg_dump`, `pg_dumpall` |
| **User** | Account that can connect | `CREATE USER name WITH PASSWORD 'pass'` |
| **Schema** | Namespace for objects | `CREATE SCHEMA name` |
| **Table** | Collection of rows/columns | `CREATE TABLE name (...)` |
| **Tablespace** | Physical storage location | `CREATE TABLESPACE name LOCATION '/path'` |
| **Logs** | Activity records | `docker logs my-postgres` |
| **Config** | PostgreSQL settings | `postgresql.conf`, `pg_hba.conf` |
| **Owner** | User who controls object | `ALTER TABLE ... OWNER TO user` |
| **Permissions** | What users can do | `GRANT SELECT ON table TO user` |

## Permission Levels

| Permission | Can Do |
|------------|--------|
| None | Cannot access |
| SELECT | Read data |
| INSERT | Add data |
| UPDATE | Modify data |
| DELETE | Remove data |
| ALL | Modify data (not structure) |
| OWNER | Everything including DROP/ALTER |

## File Locations

```
/var/lib/postgresql/data/
├── base/              # Database files (one dir per database)
├── global/            # Cluster-wide system catalogs
├── pg_wal/            # Write-Ahead Log files
├── pg_xact/           # Transaction status
├── postgresql.conf    # Main configuration
├── pg_hba.conf        # Authentication config
└── ...
```

## Backup Types Comparison

| Type | Command | Use When |
|------|---------|----------|
| SQL Dump | `pg_dump` | General purpose, portable |
| Custom Format | `pg_dump -Fc` | Production, compressed |
| File System | `pg_basebackup` | Full server backup |
| WAL Archiving | `archive_mode=on` | Point-in-time recovery |

## Common Tasks

### Create User with Database
```sql
CREATE USER alice WITH PASSWORD 'pass123';
CREATE DATABASE alice_db OWNER alice;
```

### Grant Access to Another User
```sql
GRANT SELECT, INSERT ON table_name TO bob;
GRANT USAGE ON SCHEMA schema_name TO bob;
```

### Find Large Tables
```sql
SELECT 
    tablename,
    pg_size_pretty(pg_total_relation_size('public.'||tablename)) as size
FROM pg_tables
WHERE schemaname = 'public'
ORDER BY pg_total_relation_size('public.'||tablename) DESC;
```

### View Active Connections
```sql
SELECT usename, datname, state, query
FROM pg_stat_activity
WHERE state = 'active';
```

### Check User Permissions
```sql
SELECT 
    grantee, 
    table_schema, 
    table_name, 
    privilege_type
FROM information_schema.role_table_grants
WHERE grantee = 'alice';
```

## Troubleshooting

**Can't see database files on host?**
- Files are inside Docker container, not on host
- Use `docker exec` to access them
- Or mount a volume: `-v /host/path:/var/lib/postgresql/data`

**Permission denied errors?**
- Check if user has necessary permissions
- Use `GRANT` to give permissions
- Check `pg_hba.conf` for connection permissions

**Backup too large?**
- Use custom format: `-Fc` (compressed)
- Or compress: `pg_dump ... | gzip > backup.sql.gz`

**Can't drop table?**
- Only owner can drop tables
- Transfer ownership: `ALTER TABLE ... OWNER TO user`
- Or connect as owner/superuser

## Practice Exercises

1. ✅ Find your database file locations
2. ✅ Create SQL and custom format backups
3. ✅ Create two users with their own databases
4. ✅ Test if users can access each other's objects
5. ✅ Grant permissions and test again
6. ✅ Try to delete each other's tables
7. ✅ View logs and enable logging
8. ✅ Explore configuration files
9. ✅ Create schemas and tables in different schemas
10. ✅ Create a tablespace and use it

## Next Steps

- Review `lesson-01-postgresql-fundamentals.md` for detailed explanations
- Run `./demo-lesson-01.sh` to see everything in action
- Run `./exercise-ownership-permissions.sh` for hands-on practice
- Continue to Exercise 2: Creating Your First Database

