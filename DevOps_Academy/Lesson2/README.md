# Intermediate PostgreSQL Lesson

A comprehensive 90-minute hands-on lesson covering intermediate PostgreSQL concepts for junior to mid-level developers.

## 📚 Lesson Overview

**Duration:** 90 minutes  
**Level:** Junior to Mid-Level  
**Prerequisites:** Basic SQL knowledge (SELECT, INSERT, UPDATE, DELETE, WHERE, ORDER BY)

## 🎯 Learning Objectives

By completing this lesson, you will be able to:

- Write complex queries using JOINs to combine data from multiple tables
- Use subqueries and Common Table Expressions (CTEs) to organize complex queries
- Understand and use transactions to ensure data integrity
- Apply basic window functions for advanced data analysis
- Optimize queries for better performance

## 📋 Topics Covered

1. **Understanding Joins** (30 min)
   - INNER JOIN
   - LEFT/RIGHT/FULL OUTER JOIN
   - Multiple joins
   - Join performance tips

2. **Subqueries and CTEs** (20 min)
   - Scalar subqueries
   - Subqueries with IN
   - Common Table Expressions (CTEs)
   - Recursive CTEs (introduction)

3. **Transactions and ACID Properties** (20 min)
   - Transaction basics
   - ACID properties explained
   - Savepoints
   - Isolation levels

4. **Window Functions Basics** (10 min)
   - ROW_NUMBER()
   - RANK() and DENSE_RANK()
   - Running totals
   - PARTITION BY

5. **Practical Exercise** (5 min)
   - Comprehensive challenge combining all concepts

## 🚀 Quick Start

### Prerequisites

- Docker installed and running
- Basic command line knowledge
- Basic SQL knowledge

### Setup

1. **Run the setup script:**
   ```bash
   chmod +x setup-database.sh
   ./setup-database.sh
   ```

2. **Connect to the database:**
   ```bash
   docker exec -it my-postgres psql -U postgres -d ecommerce_advanced
   ```

3. **Follow along with the lesson:**
   Open `intermediate-postgresql-lesson.md` and work through each section.

## 📁 Files in This Directory

- `intermediate-postgresql-lesson.md` - Main lesson content (90 minutes)
- `setup-database.sh` - Database setup script
- `README.md` - This file

## 🏗️ Database Schema

The lesson uses an e-commerce database with the following tables:

```
customers
├── id (PK)
├── first_name
├── last_name
├── email
├── city
└── registration_date

products
├── id (PK)
├── name
├── category
├── price
└── stock_quantity

orders
├── id (PK)
├── customer_id (FK → customers.id)
├── order_date
├── status
└── total_amount

order_items
├── id (PK)
├── order_id (FK → orders.id)
├── product_id (FK → products.id)
├── quantity
├── unit_price
└── subtotal (computed)
```

## 💡 How to Use This Lesson

1. **Read through each section** in order
2. **Type out all examples** - don't just copy-paste
3. **Complete the exercises** - solutions are provided but try first!
4. **Experiment** - modify queries to see what happens
5. **Take notes** - write down concepts you find challenging

## 🎓 Exercises

Each section includes hands-on exercises with solutions. Try to solve them yourself before looking at the answers!

## 📖 Additional Resources

- [PostgreSQL Official Documentation](https://www.postgresql.org/docs/)
- [PostgreSQL Tutorial](https://www.postgresqltutorial.com/)
- [SQL Practice on HackerRank](https://www.hackerrank.com/domains/sql)

## 🔄 Resetting the Database

If you need to start fresh:

```bash
./setup-database.sh
```

This will drop and recreate the database with fresh sample data.

## ❓ Troubleshooting

### Container not running
```bash
docker start my-postgres
```

### Can't connect to database
```bash
# Check if container is running
docker ps | grep my-postgres

# Check container logs
docker logs my-postgres
```

### Permission denied on setup script
```bash
chmod +x setup-database.sh
```

## 🎉 Next Steps

After completing this lesson:

1. Practice writing JOIN queries with your own data
2. Experiment with CTEs to refactor complex queries
3. Use transactions in your applications
4. Explore more advanced window functions
5. Move on to advanced topics like:
   - Stored procedures and functions
   - Triggers
   - Full-text search
   - Performance tuning
   - Replication

---

**Happy Learning!** 🚀

