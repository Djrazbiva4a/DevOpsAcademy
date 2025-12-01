# Complete PostgreSQL Backup Commands Reference

This document contains all backup types with commands to create, list, and explanations.

---

## 1. SQL Dump Backup (Plain Text)

### Command to Create:
```bash
docker exec my-postgres pg_dump -U postgres -d mydb > mydb_backup_$(date +%Y%m%d_%H%M%S).sql
```

### Commands to List:
```bash
# List all SQL backups
ls -lh mydb_backup_*.sql

# List with details
ls -lhT mydb_backup_*.sql | tail -10

# List latest backup
ls -t mydb_backup_*.sql | head -1

# Count backups
ls -1 mydb_backup_*.sql | wc -l

# View backup size
ls -lh mydb_backup_*.sql | awk '{print $5, $9}'
```

### Explanation:
- **What it is:** Logical backup that creates a text file with SQL commands (CREATE, INSERT, etc.) to recreate the database. Human-readable.
- **Online/Cold:** Online (hot) — database can run and accept connections. No downtime.
- **Full/Partial:** Can be full (entire database) or partial (specific tables with `-t`, schemas with `-n`).
- **Characteristics:** Portable across versions, editable, selective restore possible. Slower for very large databases, larger file size.
- **Use case:** General purpose, small to medium databases, cross-version upgrades, schema versioning.

---

## 2. Custom Format Backup (Compressed Binary)

### Command to Create:
```bash
docker exec my-postgres pg_dump -U postgres -d mydb -Fc -f /tmp/mydb_backup_$(date +%Y%m%d_%H%M%S).dump
```

### Commands to List:
```bash
# List backups in container
docker exec my-postgres bash -c "ls -lh /tmp/*.dump"

# List with details
docker exec my-postgres bash -c "ls -lh /tmp/*.dump | tail -10"

# List latest backup
docker exec my-postgres bash -c "ls -t /tmp/*.dump | head -1"

# Count backups
docker exec my-postgres bash -c "ls -1 /tmp/*.dump | wc -l"

# List contents of backup (what's inside)
docker exec my-postgres bash -c "pg_restore -l \$(ls -t /tmp/*.dump | head -1) | head -20"

# Copy latest to host
LATEST=$(docker exec my-postgres bash -c "ls -t /tmp/mydb_backup_*.dump | head -1")
docker cp my-postgres:$LATEST ./

# List on host after copying
ls -lh mydb_backup_*.dump
```

### Explanation:
- **What it is:** Logical backup in compressed binary format. Same data as SQL dump but compressed and structured. Not human-readable; requires `pg_restore`.
- **Online/Cold:** Online (hot) — database can run. No downtime.
- **Full/Partial:** Can be full or partial. Supports selective restore of specific objects (tables, indexes, functions). Can list contents before restoring.
- **Characteristics:** Compressed (smaller), faster backup/restore than SQL dump, parallel restore support, selective restore. Not human-readable, requires `pg_restore`.
- **Use case:** Production databases, large databases, when you need fast backups/restores, selective restore needs.

---

## 3. File System Backup (Physical Copy)

### Command to Create:
```bash
docker exec my-postgres pg_basebackup -U postgres -D /tmp/base_backup_$(date +%Y%m%d_%H%M%S) -Ft -z -P -X stream
```

### Commands to List:
```bash
# List file system backups in container
docker exec my-postgres bash -c "ls -lh /tmp/base_backup_*"

# List with details
docker exec my-postgres bash -c "ls -lh /tmp/base_backup_* | tail -10"

# List latest backup
docker exec my-postgres bash -c "ls -t /tmp/base_backup_* | head -1"

# List contents of tar backup (what files are inside)
docker exec my-postgres bash -c "tar -tzf \$(ls -t /tmp/base_backup_*.tar.gz | head -1) | head -20"

# Check backup size
docker exec my-postgres bash -c "du -sh /tmp/base_backup_*"

# Copy latest to host
LATEST=$(docker exec my-postgres bash -c "ls -t /tmp/base_backup_*.tar.gz | head -1")
docker cp my-postgres:$LATEST ./

# List on host after copying
ls -lh base_backup_*.tar.gz
```

### Explanation:
- **What it is:** Physical backup that copies actual database files from disk. Bit-for-bit copy of the data directory. Exact copy of filesystem structure.
- **Online/Cold:** Online (hot) — uses streaming replication protocol. Creates consistent snapshot while running. No downtime.
- **Full/Partial:** Always full — backs up entire PostgreSQL cluster (all databases, users, configuration). Cannot backup individual databases or tables.
- **Characteristics:** Fastest for large databases, exact copy, can be used for replication setup, fastest restore. Always full, larger file size, less flexible, platform-specific.
- **Use case:** Very large databases, full server backups, setting up replication, disaster recovery, migration to new server.

---

## 4. Schema-Only Backup (Structure Only)

### Command to Create:
```bash
docker exec my-postgres pg_dump -U postgres -d mydb --schema-only > mydb_schema_$(date +%Y%m%d_%H%M%S).sql
```

### Commands to List:
```bash
# List schema backups
ls -lh mydb_schema_*.sql

# List with details
ls -lhT mydb_schema_*.sql | tail -10

# List latest schema backup
ls -t mydb_schema_*.sql | head -1

# View first few lines to verify
head -30 $(ls -t mydb_schema_*.sql | head -1)

# Count schema backups
ls -1 mydb_schema_*.sql | wc -l
```

### Explanation:
- **What it is:** Logical backup containing only database structure (tables, indexes, views, functions, triggers, constraints). No data (rows). Creates empty tables.
- **Online/Cold:** Online (hot) — database can run. No downtime.
- **Full/Partial:** Can be full (all schemas) or partial (specific schemas with `-n`, specific tables with `-t`).
- **Characteristics:** Small file size, fast to create, useful for version control, can recreate structure on different database. No data included.
- **Use case:** Schema versioning, creating empty test databases, documenting database structure, migration scripts.

---

## 5. Data-Only Backup (Data Only)

### Command to Create:
```bash
docker exec my-postgres pg_dump -U postgres -d mydb --data-only > mydb_data_$(date +%Y%m%d_%H%M%S).sql
```

### Commands to List:
```bash
# List data backups
ls -lh mydb_data_*.sql

# List with details
ls -lhT mydb_data_*.sql | tail -10

# List latest data backup
ls -t mydb_data_*.sql | head -1

# Count INSERT statements (approximate row count)
grep -c "^INSERT" $(ls -t mydb_data_*.sql | head -1)

# Count data backups
ls -1 mydb_data_*.sql | wc -l
```

### Explanation:
- **What it is:** Logical backup containing only data (rows). Includes INSERT statements with all data. Does not include table structures, indexes, or constraints. Assumes tables already exist.
- **Online/Cold:** Online (hot) — database can run. No downtime.
- **Full/Partial:** Can be full (all data) or partial (specific tables with `-t`, specific schemas with `-n`).
- **Characteristics:** Contains only data, useful when structure hasn't changed, can reload data into existing tables. Requires tables to exist first, no structure information.
- **Use case:** Refreshing test data, data migration, reloading data after structure changes, data-only refreshes.

---

## 6. Single Table Backup

### Command to Create:
```bash
# Single table
docker exec my-postgres pg_dump -U postgres -d mydb -t customers > customers_backup_$(date +%Y%m%d_%H%M%S).sql

# Multiple tables
docker exec my-postgres pg_dump -U postgres -d mydb -t customers -t orders -t payments > tables_backup_$(date +%Y%m%d_%H%M%S).sql
```

### Commands to List:
```bash
# List all table backups
ls -lh *backup_*.sql

# List specific table backups
ls -lh customers_backup_*.sql

# List multiple table backups
ls -lh tables_backup_*.sql

# List with details
ls -lhT *backup_*.sql | tail -10

# List latest table backup
ls -t *backup_*.sql | head -1

# Count table backups
ls -1 *backup_*.sql | wc -l
```

### Explanation:
- **What it is:** Logical backup of one or more specific tables. Contains both structure and data for selected tables. Can specify multiple tables with multiple `-t` flags.
- **Online/Cold:** Online (hot) — database can run. No downtime.
- **Full/Partial:** Partial — only selected tables. Can backup multiple tables: `-t table1 -t table2 -t table3`.
- **Characteristics:** Selective backup, smaller file size, faster than full backup, useful for specific table recovery. Doesn't backup entire database, may miss related data.
- **Use case:** Backing up specific important tables, table-level recovery, exporting specific data.

---

## 7. All Databases Backup (Entire Cluster)

### Command to Create:
```bash
docker exec my-postgres pg_dumpall -U postgres > all_databases_$(date +%Y%m%d_%H%M%S).sql
```

### Commands to List:
```bash
# List all database backups
ls -lh all_databases_*.sql

# List with details
ls -lhT all_databases_*.sql | tail -10

# List latest cluster backup
ls -t all_databases_*.sql | head -1

# Check file size (these are usually large)
ls -lh all_databases_*.sql | awk '{print $5, $9}'

# View first few lines to see what databases are included
head -50 $(ls -t all_databases_*.sql | head -1) | grep -i "CREATE DATABASE"

# Count cluster backups
ls -1 all_databases_*.sql | wc -l
```

### Explanation:
- **What it is:** Logical backup of entire PostgreSQL cluster. Backs up all databases in the cluster. Also backs up users, roles, permissions, and global objects. Creates a single SQL file with everything.
- **Online/Cold:** Online (hot) — all databases can run. No downtime.
- **Full/Partial:** Always full — entire cluster. Cannot backup individual databases with this command. Includes all databases, all users, all roles.
- **Characteristics:** Complete cluster backup, includes users and roles, single file for entire cluster. Large file size, slower than single database backup, cannot selectively restore databases easily.
- **Use case:** Complete cluster backup, disaster recovery, migrating entire PostgreSQL instance, backing up user accounts.

---

## 8. Compressed Backup

### Command to Create:
```bash
docker exec my-postgres pg_dump -U postgres -d mydb | gzip > mydb_backup_$(date +%Y%m%d_%H%M%S).sql.gz
```

### Commands to List:
```bash
# List compressed backups
ls -lh *.sql.gz

# List with details
ls -lhT *.sql.gz | tail -10

# List latest compressed backup
ls -t *.sql.gz | head -1

# Compare sizes (compressed vs uncompressed if you have both)
ls -lh mydb_backup_*.sql* | awk '{print $5, $9}'

# Check compression ratio
for file in $(ls -t *.sql.gz | head -1); do
    echo "File: $file"
    echo "  Compressed: $(ls -lh "$file" | awk '{print $5}')"
    echo "  Uncompressed estimate: $(gunzip -c "$file" | wc -c | awk '{print $1/1024/1024 " MB"}')"
done

# Count compressed backups
ls -1 *.sql.gz | wc -l
```

### Explanation:
- **What it is:** SQL dump backup compressed with gzip. Same as SQL dump but compressed to save space. Reduces file size significantly (often 70-90% smaller). Must decompress before restoring.
- **Online/Cold:** Online (hot) — database can run. No downtime.
- **Full/Partial:** Same as SQL dump — can be full or partial, depending on pg_dump options used.
- **Characteristics:** Much smaller file size, faster to transfer, saves disk space. Must decompress before restoring, cannot read directly.
- **Use case:** Saving disk space, transferring backups over network, long-term storage, large databases.

---

## 9. Backup with Clean (Includes DROP Statements)

### Command to Create:
```bash
docker exec my-postgres pg_dump -U postgres -d mydb --clean --if-exists > mydb_clean_backup_$(date +%Y%m%d_%H%M%S).sql
```

### Commands to List:
```bash
# List clean backups
ls -lh mydb_clean_backup_*.sql

# List with details
ls -lhT mydb_clean_backup_*.sql | tail -10

# List latest clean backup
ls -t mydb_clean_backup_*.sql | head -1

# Verify it contains DROP statements
grep -c "DROP" $(ls -t mydb_clean_backup_*.sql | head -1)

# Count clean backups
ls -1 mydb_clean_backup_*.sql | wc -l
```

### Explanation:
- **What it is:** SQL dump that includes DROP statements before CREATE statements. `--clean` adds DROP commands, `--if-exists` makes DROP statements use IF EXISTS (safer). Useful for clean restore that removes existing objects first.
- **Online/Cold:** Online (hot) — database can run. No downtime.
- **Full/Partial:** Can be full or partial, same as regular SQL dump.
- **Characteristics:** Clean restore (drops existing objects first), safer with IF EXISTS, prevents errors if objects already exist. More destructive on restore (drops existing data).
- **Use case:** Clean restores, refreshing test environments, ensuring clean state.

---

## 10. Backup Without Owner/Privileges (Portable)

### Command to Create:
```bash
docker exec my-postgres pg_dump -U postgres -d mydb --no-owner --no-privileges > mydb_portable_$(date +%Y%m%d_%H%M%S).sql
```

### Commands to List:
```bash
# List portable backups
ls -lh mydb_portable_*.sql

# List with details
ls -lhT mydb_portable_*.sql | tail -10

# List latest portable backup
ls -t mydb_portable_*.sql | head -1

# Verify it doesn't have ownership commands
grep -c "OWNER TO" $(ls -t mydb_portable_*.sql | head -1)

# Count portable backups
ls -1 mydb_portable_*.sql | wc -l
```

### Explanation:
- **What it is:** SQL dump that doesn't include ownership or privilege information. More portable across different PostgreSQL installations. Restores objects owned by the user running the restore, not original owners.
- **Online/Cold:** Online (hot) — database can run. No downtime.
- **Full/Partial:** Can be full or partial, same as regular SQL dump.
- **Characteristics:** More portable, works across different user setups, simpler restore. Doesn't preserve original ownership/permissions.
- **Use case:** Cross-environment restores, when ownership doesn't matter, simpler restore process.

---

## 11. Verbose Backup (See Progress)

### Command to Create:
```bash
docker exec my-postgres pg_dump -U postgres -d mydb -v > mydb_verbose_backup_$(date +%Y%m%d_%H%M%S).sql
```

### Commands to List:
```bash
# List verbose backups
ls -lh mydb_verbose_backup_*.sql

# List with details
ls -lhT mydb_verbose_backup_*.sql | tail -10

# List latest verbose backup
ls -t mydb_verbose_backup_*.sql | head -1

# Note: Verbose output is in the backup file itself, you can check it
head -50 $(ls -t mydb_verbose_backup_*.sql | head -1) | grep -i "dumping"

# Count verbose backups
ls -1 mydb_verbose_backup_*.sql | wc -l
```

### Explanation:
- **What it is:** SQL dump with verbose output showing progress. Displays what's being backed up in real-time. Useful for monitoring large backups.
- **Online/Cold:** Online (hot) — database can run. No downtime.
- **Full/Partial:** Can be full or partial, same as regular SQL dump.
- **Characteristics:** Shows progress, useful for large databases, helps monitor backup status. More output to read.
- **Use case:** Large databases, monitoring backup progress, debugging backup issues.

---

## 12. Backup Specific Schema

### Command to Create:
```bash
# Single schema
docker exec my-postgres pg_dump -U postgres -d mydb -n public > mydb_public_schema_$(date +%Y%m%d_%H%M%S).sql

# Multiple schemas
docker exec my-postgres pg_dump -U postgres -d mydb -n public -n hr > mydb_schemas_$(date +%Y%m%d_%H%M%S).sql
```

### Commands to List:
```bash
# List schema backups
ls -lh mydb_*_schema_*.sql

# List public schema backups
ls -lh mydb_public_schema_*.sql

# List multiple schema backups
ls -lh mydb_schemas_*.sql

# List with details
ls -lhT mydb_*_schema_*.sql | tail -10

# List latest schema backup
ls -t mydb_*_schema_*.sql | head -1

# Count schema backups
ls -1 mydb_*_schema_*.sql | wc -l
```

### Explanation:
- **What it is:** Logical backup of specific schema(s) only. Backs up all objects (tables, views, functions) within the specified schema(s). Can specify multiple schemas with multiple `-n` flags.
- **Online/Cold:** Online (hot) — database can run. No downtime.
- **Full/Partial:** Partial — only specified schemas. Useful for schema-level backups.
- **Characteristics:** Schema-level backup, smaller than full backup, faster. Doesn't backup other schemas, may miss cross-schema dependencies.
- **Use case:** Schema-level backups, multi-tenant databases, backing up specific application schemas.

---

## 13. Exclude Tables from Backup

### Command to Create:
```bash
docker exec my-postgres pg_dump -U postgres -d mydb -T old_table -T temp_table > mydb_excluded_backup_$(date +%Y%m%d_%H%M%S).sql
```

### Commands to List:
```bash
# List excluded backups
ls -lh mydb_excluded_backup_*.sql

# List with details
ls -lhT mydb_excluded_backup_*.sql | tail -10

# List latest excluded backup
ls -t mydb_excluded_backup_*.sql | head -1

# Verify excluded tables are not in backup
grep -c "old_table\|temp_table" $(ls -t mydb_excluded_backup_*.sql | head -1)

# Count excluded backups
ls -1 mydb_excluded_backup_*.sql | wc -l
```

### Explanation:
- **What it is:** SQL dump that excludes specific tables. Backs up entire database except the tables specified with `-T` flag. Can exclude multiple tables with multiple `-T` flags.
- **Online/Cold:** Online (hot) — database can run. No downtime.
- **Full/Partial:** Partial — excludes specified tables. Everything else is backed up.
- **Characteristics:** Excludes unwanted tables, smaller backup, faster. Doesn't backup excluded tables, may miss dependencies.
- **Use case:** Excluding temporary tables, excluding large log tables, excluding test data.

---

## 14. Custom Format with Maximum Compression

### Command to Create:
```bash
docker exec my-postgres pg_dump -U postgres -d mydb -Fc -Z 9 -f /tmp/mydb_max_compressed_$(date +%Y%m%d_%H%M%S).dump
```

### Commands to List:
```bash
# List max compressed backups in container
docker exec my-postgres bash -c "ls -lh /tmp/mydb_max_compressed_*.dump"

# List with details
docker exec my-postgres bash -c "ls -lh /tmp/mydb_max_compressed_*.dump | tail -10"

# List latest max compressed backup
docker exec my-postgres bash -c "ls -t /tmp/mydb_max_compressed_*.dump | head -1"

# Compare sizes (regular vs max compressed)
echo "Regular custom format:"
docker exec my-postgres bash -c "ls -lh /tmp/mydb_backup_*.dump | tail -1 | awk '{print \$5}'"
echo "Max compressed:"
docker exec my-postgres bash -c "ls -lh /tmp/mydb_max_compressed_*.dump | tail -1 | awk '{print \$5}'"

# Copy to host
LATEST=$(docker exec my-postgres bash -c "ls -t /tmp/mydb_max_compressed_*.dump | head -1")
docker cp my-postgres:$LATEST ./

# List on host
ls -lh mydb_max_compressed_*.dump
```

### Explanation:
- **What it is:** Custom format backup with maximum compression level. `-Z 9` sets compression to maximum (1-9, where 9 is maximum). Smaller file size but slower backup/restore.
- **Online/Cold:** Online (hot) — database can run. No downtime.
- **Full/Partial:** Can be full or partial, same as regular custom format.
- **Characteristics:** Maximum compression (smallest file), saves most disk space, slower backup/restore. Trade-off between size and speed.
- **Use case:** Long-term storage, limited disk space, network transfer, archival backups.

---

## 15. Complete Backup Summary (List All Types)

### Command to Create All Types:
```bash
# SQL dump
docker exec my-postgres pg_dump -U postgres -d mydb > mydb_sql_$(date +%Y%m%d_%H%M%S).sql

# Custom format
docker exec my-postgres pg_dump -U postgres -d mydb -Fc -f /tmp/mydb_custom_$(date +%Y%m%d_%H%M%S).dump

# Schema only
docker exec my-postgres pg_dump -U postgres -d mydb --schema-only > mydb_schema_$(date +%Y%m%d_%H%M%S).sql

# Data only
docker exec my-postgres pg_dump -U postgres -d mydb --data-only > mydb_data_$(date +%Y%m%d_%H%M%S).sql

# Compressed
docker exec my-postgres pg_dump -U postgres -d mydb | gzip > mydb_compressed_$(date +%Y%m%d_%H%M%S).sql.gz
```

### Command to List All Types:
```bash
echo "=== BACKUP SUMMARY ==="
echo ""
echo "SQL Dump Backups:"
ls -lh mydb_backup_*.sql mydb_sql_*.sql 2>/dev/null | awk '{printf "  %s %s %s %s\n", $5, $6, $7, $9}' | tail -10
echo ""
echo "Custom Format Backups:"
docker exec my-postgres bash -c "ls -lh /tmp/*.dump 2>/dev/null" | awk '{printf "  %s %s %s %s\n", $5, $6, $7, $9}' | tail -10
echo ""
echo "File System Backups:"
docker exec my-postgres bash -c "ls -lh /tmp/base_backup_* 2>/dev/null" | awk '{printf "  %s %s %s %s\n", $5, $6, $7, $9}' | tail -5
echo ""
echo "Compressed Backups:"
ls -lh *.sql.gz 2>/dev/null | awk '{printf "  %s %s %s %s\n", $5, $6, $7, $9}' | tail -5
echo ""
echo "Schema Backups:"
ls -lh mydb_schema_*.sql 2>/dev/null | awk '{printf "  %s %s %s %s\n", $5, $6, $7, $9}' | tail -5
echo ""
echo "Data Backups:"
ls -lh mydb_data_*.sql 2>/dev/null | awk '{printf "  %s %s %s %s\n", $5, $6, $7, $9}' | tail -5
echo ""
echo "=== Backup Counts ==="
echo "  SQL: $(ls -1 mydb_backup_*.sql mydb_sql_*.sql 2>/dev/null | wc -l)"
echo "  Custom Format: $(docker exec my-postgres bash -c 'ls -1 /tmp/*.dump 2>/dev/null | wc -l')"
echo "  File System: $(docker exec my-postgres bash -c 'ls -1 /tmp/base_backup_* 2>/dev/null | wc -l')"
echo "  Compressed: $(ls -1 *.sql.gz 2>/dev/null | wc -l)"
echo "  Schema: $(ls -1 mydb_schema_*.sql 2>/dev/null | wc -l)"
echo "  Data: $(ls -1 mydb_data_*.sql 2>/dev/null | wc -l)"
```

### Explanation:
- **What it is:** Comprehensive script that creates and lists all backup types in one place. Shows file sizes, dates, and counts for each backup type. Useful for getting overview of all backups.
- **Use case:** Backup inventory, monitoring backup status, finding specific backups, backup management.

---

## Quick Reference Table

| Backup Type | Create Command | List Command | Online/Cold | Full/Partial |
|------------|----------------|--------------|-------------|--------------|
| **SQL Dump** | `pg_dump -d mydb > backup.sql` | `ls -lh *.sql` | Online | Full/Partial |
| **Custom Format** | `pg_dump -d mydb -Fc -f /tmp/backup.dump` | `docker exec ... bash -c "ls -lh /tmp/*.dump"` | Online | Full/Partial |
| **File System** | `pg_basebackup -D /tmp/base` | `docker exec ... bash -c "ls -lh /tmp/base_backup_*"` | Online | Always Full |
| **Schema Only** | `pg_dump --schema-only > schema.sql` | `ls -lh *schema*.sql` | Online | Full/Partial |
| **Data Only** | `pg_dump --data-only > data.sql` | `ls -lh *data*.sql` | Online | Full/Partial |
| **Single Table** | `pg_dump -t table > table.sql` | `ls -lh *backup*.sql` | Online | Partial |
| **All Databases** | `pg_dumpall > all.sql` | `ls -lh all_databases*.sql` | Online | Always Full |
| **Compressed** | `pg_dump \| gzip > backup.sql.gz` | `ls -lh *.sql.gz` | Online | Full/Partial |

---

## Notes

- All commands assume you're in a directory with write permissions (like `~/Documents/DevOps_Academy` or `~`)
- For zsh, use `bash -c` inside `docker exec` when using wildcards
- Custom format and file system backups are stored in container `/tmp/` and need to be copied to host
- SQL backups are created directly on the host in the current directory
- Use timestamps in filenames to avoid overwriting backups
- Always verify backups after creation

---

## Backup Best Practices

1. **Regular Backups:** Schedule automated backups (daily, weekly)
2. **Test Restores:** Regularly test that backups can be restored
3. **Multiple Copies:** Keep backups in multiple locations (3-2-1 rule)
4. **Monitor:** Check backup sizes and verify they're completing successfully
5. **Documentation:** Document backup and restore procedures
6. **Retention:** Keep backups for appropriate time period
7. **Encryption:** Encrypt backups containing sensitive data
8. **Verification:** Verify backup integrity regularly

---

## Common Issues and Solutions

**Issue:** Permission denied when creating backup
- **Solution:** Run from a directory where you have write permissions (not `/var/lib` or other system directories)

**Issue:** zsh: no matches found (wildcards)
- **Solution:** Use `bash -c` inside `docker exec` for wildcards: `docker exec my-postgres bash -c "ls -lh /tmp/*.dump"`

**Issue:** Backup file is very large
- **Solution:** Use custom format (`-Fc`) for compression, or compress with gzip

**Issue:** Can't find backup files
- **Solution:** Custom format backups are in container `/tmp/`, SQL backups are in current directory on host

**Issue:** Backup takes too long
- **Solution:** Use custom format for faster backups, run during off-peak hours, consider parallel backup

---

## Restore Commands (Quick Reference)

```bash
# Restore SQL dump
docker exec -i my-postgres psql -U postgres -d mydb < mydb_backup.sql

# Restore custom format
docker exec my-postgres pg_restore -U postgres -d mydb /tmp/mydb_backup.dump

# Restore compressed backup
gunzip -c mydb_backup.sql.gz | docker exec -i my-postgres psql -U postgres -d mydb

# Restore to new database
docker exec my-postgres psql -U postgres -c "CREATE DATABASE mydb_restored;"
docker exec -i my-postgres psql -U postgres -d mydb_restored < mydb_backup.sql
```

---

*Last updated: December 2024*

