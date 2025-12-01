#!/bin/bash

# Hands-On Exercise: Ownership and Permissions
# This script guides you through creating two users and testing ownership

CONTAINER_NAME="my-postgres"

echo "=========================================="
echo "Ownership and Permissions Exercise"
echo "=========================================="
echo ""
echo "This exercise will:"
echo "1. Create two users (alice and bob)"
echo "2. Create databases owned by each user"
echo "3. Create tables in each database"
echo "4. Test if users can access each other's objects"
echo "5. Test if users can delete each other's objects"
echo ""
read -p "Press Enter to continue or Ctrl+C to cancel..."
echo ""

# Step 1: Create Users
echo "=== Step 1: Creating Users ==="
docker exec $CONTAINER_NAME psql -U postgres -c "
DROP USER IF EXISTS exercise_alice;
DROP USER IF EXISTS exercise_bob;
CREATE USER exercise_alice WITH PASSWORD 'alice123';
CREATE USER exercise_bob WITH PASSWORD 'bob123';
\du exercise_alice
\du exercise_bob
"
echo "✓ Users created"
echo ""

# Step 2: Create Databases
echo "=== Step 2: Creating Databases ==="
docker exec $CONTAINER_NAME psql -U postgres -c "
DROP DATABASE IF EXISTS alice_db;
DROP DATABASE IF EXISTS bob_db;
CREATE DATABASE alice_db OWNER exercise_alice;
CREATE DATABASE bob_db OWNER exercise_bob;
\l alice_db
\l bob_db
"
echo "✓ Databases created"
echo ""

# Step 3: Create Tables
echo "=== Step 3: Creating Tables ==="
echo "Creating tables as alice..."
docker exec $CONTAINER_NAME psql -U exercise_alice -d alice_db -c "
CREATE TABLE alice_products (
    id SERIAL PRIMARY KEY,
    product_name VARCHAR(100),
    price DECIMAL(10, 2)
);
INSERT INTO alice_products (product_name, price) VALUES
    ('Alice Product 1', 19.99),
    ('Alice Product 2', 29.99);
SELECT * FROM alice_products;
"
echo ""

echo "Creating tables as bob..."
docker exec $CONTAINER_NAME psql -U exercise_bob -d bob_db -c "
CREATE TABLE bob_customers (
    id SERIAL PRIMARY KEY,
    customer_name VARCHAR(100),
    email VARCHAR(100)
);
INSERT INTO bob_customers (customer_name, email) VALUES
    ('Bob Customer 1', 'customer1@example.com'),
    ('Bob Customer 2', 'customer2@example.com');
SELECT * FROM bob_customers;
"
echo "✓ Tables created and populated"
echo ""

# Step 4: Test Cross-Database Access
echo "=== Step 4: Testing Cross-Database Access ==="
echo "Can bob access alice's database?"
docker exec $CONTAINER_NAME psql -U exercise_bob -d alice_db -c "\dt" 2>&1 | head -5
echo ""

echo "Can bob SELECT from alice's table? (Should fail)"
docker exec $CONTAINER_NAME psql -U exercise_bob -d alice_db -c "SELECT * FROM alice_products;" 2>&1 | grep -E "(ERROR|Alice|id)" | head -3
echo ""

# Step 5: Grant Permissions
echo "=== Step 5: Granting Permissions ==="
echo "Granting SELECT permission to bob..."
docker exec $CONTAINER_NAME psql -U exercise_alice -d alice_db -c "
GRANT SELECT ON alice_products TO exercise_bob;
"
echo ""

echo "Now can bob SELECT from alice's table? (Should work)"
docker exec $CONTAINER_NAME psql -U exercise_bob -d alice_db -c "SELECT * FROM alice_products;" 2>&1 | grep -v "^$"
echo ""

echo "Can bob INSERT into alice's table? (Should fail - only SELECT granted)"
docker exec $CONTAINER_NAME psql -U exercise_bob -d alice_db -c "INSERT INTO alice_products (product_name, price) VALUES ('Test', 10.00);" 2>&1 | grep -E "(ERROR|INSERT)" | head -2
echo ""

# Step 6: Test Deletion
echo "=== Step 6: Testing Deletion Permissions ==="
echo "Can bob DELETE from alice's table? (Should fail)"
docker exec $CONTAINER_NAME psql -U exercise_bob -d alice_db -c "DELETE FROM alice_products WHERE id = 1;" 2>&1 | grep -E "(ERROR|DELETE)" | head -2
echo ""

echo "Can bob DROP alice's table? (Should fail - only owner can drop)"
docker exec $CONTAINER_NAME psql -U exercise_bob -d alice_db -c "DROP TABLE alice_products;" 2>&1 | grep -E "(ERROR|DROP)" | head -2
echo ""

# Step 7: Grant ALL Privileges
echo "=== Step 7: Granting ALL Privileges ==="
echo "Granting ALL privileges to bob..."
docker exec $CONTAINER_NAME psql -U exercise_alice -d alice_db -c "
GRANT ALL PRIVILEGES ON alice_products TO exercise_bob;
"
echo ""

echo "Can bob UPDATE alice's table now? (Should work)"
docker exec $CONTAINER_NAME psql -U exercise_bob -d alice_db -c "
UPDATE alice_products SET price = 99.99 WHERE id = 1;
SELECT * FROM alice_products;
" 2>&1 | grep -v "^$"
echo ""

echo "Can bob DROP alice's table with ALL privileges? (Should still fail - only owner can drop)"
docker exec $CONTAINER_NAME psql -U exercise_bob -d alice_db -c "DROP TABLE alice_products;" 2>&1 | grep -E "(ERROR|DROP)" | head -2
echo ""

# Step 8: Transfer Ownership
echo "=== Step 8: Transferring Ownership ==="
echo "Transferring table ownership to bob..."
docker exec $CONTAINER_NAME psql -U exercise_alice -d alice_db -c "
ALTER TABLE alice_products OWNER TO exercise_bob;
\dt
"
echo ""

echo "Now can bob DROP the table? (Should work - bob is now owner)"
docker exec $CONTAINER_NAME psql -U exercise_bob -d alice_db -c "
DROP TABLE alice_products;
\dt
" 2>&1 | grep -v "^$"
echo ""

# Summary
echo "=========================================="
echo "Exercise Summary"
echo "=========================================="
echo ""
echo "Key Learnings:"
echo "✓ Users can only access objects they have permission for"
echo "✓ GRANT SELECT allows reading but not modifying"
echo "✓ GRANT ALL allows data modification but NOT structural changes"
echo "✓ Only the OWNER can DROP or ALTER table structure"
echo "✓ Ownership can be transferred with ALTER TABLE ... OWNER TO"
echo ""
echo "Permission Levels:"
echo "  - No permission: Cannot access"
echo "  - SELECT: Can read data"
echo "  - INSERT/UPDATE/DELETE: Can modify data"
echo "  - ALL: Can modify data but not structure"
echo "  - OWNER: Can do everything including DROP/ALTER"
echo ""
echo "Try these commands manually:"
echo "  docker exec -it $CONTAINER_NAME psql -U exercise_alice -d alice_db"
echo "  docker exec -it $CONTAINER_NAME psql -U exercise_bob -d bob_db"
echo ""

