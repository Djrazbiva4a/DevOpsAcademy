# Accessing PostgreSQL Files from Host Machine

## The Problem

PostgreSQL files are **inside the Docker container**, not on your host machine. When you navigate to `/var/lib` on your Mac, you're looking at your **host filesystem**, not the container's filesystem.

**Container filesystem**: `/var/lib/postgresql/data` (inside Docker container)  
**Host filesystem**: `/var/lib` (your Mac's system directory)

---

## Solution 1: View Files Using Docker Exec (Recommended for Quick Access)

### View Configuration Files

```bash
# View main PostgreSQL config
docker exec my-postgres cat /var/lib/postgresql/data/postgresql.conf

# View HBA config (authentication)
docker exec my-postgres cat /var/lib/postgresql/data/pg_hba.conf

# View auto-generated config
docker exec my-postgres cat /var/lib/postgresql/data/postgresql.auto.conf
```

### List Files and Directories

```bash
# List all files in data directory
docker exec my-postgres ls -la /var/lib/postgresql/data/

# List WAL files
docker exec my-postgres ls -lh /var/lib/postgresql/data/pg_wal/

# List database directories
docker exec my-postgres ls -la /var/lib/postgresql/data/base/
```

### Interactive Shell Access

```bash
# Get an interactive bash shell inside the container
docker exec -it my-postgres bash

# Once inside, you can navigate normally:
cd /var/lib/postgresql/data
ls -la
cat postgresql.conf
# ... etc

# Exit when done
exit
```

---

## Solution 2: Copy Files to Host Machine

### Copy Individual Files

```bash
# Copy config file to current directory
docker cp my-postgres:/var/lib/postgresql/data/postgresql.conf ./postgresql.conf

# Copy HBA config
docker cp my-postgres:/var/lib/postgresql/data/pg_hba.conf ./pg_hba.conf

# Copy entire data directory (WARNING: This is large - ~50MB+)
docker cp my-postgres:/var/lib/postgresql/data ./postgresql-data-backup
```

### Copy Specific Directories

```bash
# Copy only WAL files
docker cp my-postgres:/var/lib/postgresql/data/pg_wal ./wal-backup

# Copy only config files
docker cp my-postgres:/var/lib/postgresql/data/postgresql.conf ./configs/
docker cp my-postgres:/var/lib/postgresql/data/pg_hba.conf ./configs/
```

---

## Solution 3: Mount Volume for Direct Host Access (Best for Development)

If you want to access files directly from your host machine, you can mount a volume when starting the container.

### Step 1: Stop and Remove Current Container

```bash
# Stop the container
docker stop my-postgres

# Remove the container (data will be lost unless you copy it first!)
docker rm my-postgres
```

### Step 2: Create Directory on Host

```bash
# Create a directory on your host machine
mkdir -p ~/postgres-data

# Or in your project directory
mkdir -p ~/Documents/DevOps_Academy/postgres-data
```

### Step 3: Start Container with Volume Mount

```bash
# Start container with volume mount
docker run --name my-postgres \
  -e POSTGRES_PASSWORD=mysecretpassword \
  -e POSTGRES_USER=postgres \
  -e POSTGRES_DB=mydb \
  -p 5432:5432 \
  -v ~/Documents/DevOps_Academy/postgres-data:/var/lib/postgresql/data \
  -d postgres:15
```

Now you can access files directly:
```bash
cd ~/Documents/DevOps_Academy/postgres-data
ls -la
cat postgresql.conf
```

**Important Notes:**
- The first time you mount a volume, PostgreSQL will initialize the data directory
- If you had existing data, you'll need to copy it first
- Files will persist even if you remove the container

---

## Solution 4: Use Docker Volume (Recommended for Production)

Docker volumes are managed by Docker and stored in Docker's storage location:

```bash
# Create a named volume
docker volume create postgres-data

# Start container with named volume
docker run --name my-postgres \
  -e POSTGRES_PASSWORD=mysecretpassword \
  -e POSTGRES_USER=postgres \
  -e POSTGRES_DB=mydb \
  -p 5432:5432 \
  -v postgres-data:/var/lib/postgresql/data \
  -d postgres:15

# Find where Docker stores the volume
docker volume inspect postgres-data
```

---

## Quick Reference: Common Tasks

### View Config File
```bash
docker exec my-postgres cat /var/lib/postgresql/data/postgresql.conf
```

### Edit Config File (copy, edit, copy back)
```bash
# 1. Copy to host
docker cp my-postgres:/var/lib/postgresql/data/postgresql.conf ./postgresql.conf

# 2. Edit on host (use your favorite editor)
nano postgresql.conf
# or
vim postgresql.conf

# 3. Copy back to container
docker cp ./postgresql.conf my-postgres:/var/lib/postgresql/data/postgresql.conf

# 4. Reload PostgreSQL config (no restart needed)
docker exec my-postgres psql -U postgres -c "SELECT pg_reload_conf();"
```

### View Logs
```bash
# View container logs (PostgreSQL logs go here by default)
docker logs my-postgres

# Follow logs in real-time
docker logs -f my-postgres

# View last 100 lines
docker logs --tail 100 my-postgres
```

### Check File Sizes
```bash
docker exec my-postgres du -sh /var/lib/postgresql/data/*
```

### Find Specific Files
```bash
# Find all .conf files
docker exec my-postgres find /var/lib/postgresql/data -name "*.conf"

# Find large files
docker exec my-postgres find /var/lib/postgresql/data -type f -size +10M
```

---

## Understanding the File System Separation

```
┌─────────────────────────────────────┐
│  Your Mac (Host Machine)            │
│  /var/lib/                          │  ← You were here
│    └── postfix/                     │
│                                     │
│  ~/Documents/DevOps_Academy/        │  ← Your project
│                                     │
└─────────────────────────────────────┘
           │
           │ Docker
           ▼
┌─────────────────────────────────────┐
│  Docker Container (my-postgres)     │
│  /var/lib/postgresql/data/          │  ← PostgreSQL files are HERE
│    ├── postgresql.conf              │
│    ├── pg_hba.conf                  │
│    ├── base/                        │
│    ├── pg_wal/                      │
│    └── ...                          │
└─────────────────────────────────────┘
```

---

## Troubleshooting

### "Permission denied" errors
- Files inside container are owned by `postgres` user
- Use `docker exec` commands, not direct file access
- If mounting volumes, you may need to adjust permissions

### "No such file or directory" on host
- Remember: files are in the container, not on host
- Use `docker exec` or `docker cp` to access them
- Or mount a volume to access directly from host

### Want to see files in Finder/File Explorer?
1. Copy files to host: `docker cp my-postgres:/var/lib/postgresql/data/postgresql.conf ~/Desktop/`
2. Or mount a volume to a location you can access

---

## Recommended Approach

For **learning/development**: Use `docker exec` commands (Solution 1) - it's quick and doesn't require container changes.

For **persistent access**: Mount a volume (Solution 3) - you can access files directly from your host.

For **production**: Use Docker volumes (Solution 4) - managed by Docker, better for production environments.

