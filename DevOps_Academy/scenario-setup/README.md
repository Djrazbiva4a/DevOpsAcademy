# TechShop Database Scenario Setup

This directory contains scripts to set up a database with **intentional problems** for troubleshooting practice.

## Quick Start

1. **Make scripts executable:**
   ```bash
   chmod +x create-bad-database.sh
   ```

2. **Run the setup script:**
   ```bash
   ./create-bad-database.sh
   ```

3. **Connect to the database:**
   ```bash
   docker exec -it techshop-db psql -U postgres -d techshop
   ```

4. **Verify problems exist:**
   ```bash
   docker exec -i techshop-db psql -U postgres -d techshop < verify-problems.sql
   ```

5. **Start fixing issues!** Use the queries from `REAL_WORLD_SCENARIO.md`

## What Problems Are Created?

### 🔴 Performance Issues
- **Missing indexes** on frequently queried columns (name, category_id, order_id, etc.)
- **Outdated statistics** (ANALYZE not run)
- **Table bloat** (dead tuples from updates/deletes)
- **Large tables** without proper indexing (50K+ products, 30K+ order_items)

### 🔴 Data Integrity Issues
- **Duplicate customer emails** (missing UNIQUE constraint)
- **Products with negative stock** quantities
- **Orphaned order_items** (referencing non-existent orders)
- **Invalid foreign key references** (order_items with bad product_ids)
- **Orders with zero/negative totals**
- **Products with NULL category_id**

### 🔴 Schema Issues
- **Missing foreign key constraints** on order_items
- **Missing UNIQUE constraints** on email and sku
- **Missing CHECK constraints** (e.g., stock_quantity >= 0)

## Database Statistics

After setup, you'll have:
- **~1,000 customers** (with some duplicates)
- **~50,000 products** (with some negative stock, NULL categories)
- **~10,000 orders** (with some zero/negative totals)
- **~30,000 order_items** (with some orphaned records)
- **Dead tuples** from updates/deletes (not vacuumed)

## Additional Performance Problems

To add more performance issues, run:

```bash
docker exec -i techshop-db psql -U postgres -d techshop < create-performance-problems.sql
```

This adds:
- `product_reviews` table with 100K rows, no indexes
- `customer_sessions` table with inefficient data types
- `inventory_log` table with heavy update bloat
- Expensive views and functions

## Verification

Run the verification script to see all problems:

```bash
docker exec -i techshop-db psql -U postgres -d techshop < verify-problems.sql
```

## Cleanup

To start fresh:

```bash
docker stop techshop-db
docker rm techshop-db
./create-bad-database.sh
```

## Troubleshooting

**Container won't start:**
- Check if port 5433 is already in use: `lsof -i :5433`
- Change the port in the script if needed

**Script fails:**
- Make sure Docker is running
- Check container logs: `docker logs techshop-db`

**Database seems fine:**
- Run `verify-problems.sql` to see all issues
- Check that data was inserted: `SELECT COUNT(*) FROM products;`

## Next Steps

1. Work through the tasks in `REAL_WORLD_SCENARIO.md`
2. Use the diagnostic queries to find problems
3. Fix issues one by one
4. Verify your fixes worked
5. Document your solutions

Good luck! 🚀

