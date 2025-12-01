# Exercise 1: Setting Up PostgreSQL with Docker

## Learning Objectives
- Understand what Docker is and why we use it for PostgreSQL
- Learn how to run PostgreSQL in a Docker container
- Connect to PostgreSQL using the command line
- Understand basic Docker commands for PostgreSQL

## What is Docker?

Docker is a platform that allows you to run applications in isolated containers. Think of a container as a lightweight, portable package that includes everything needed to run an application (the application itself, its dependencies, and configuration).

**Why use Docker for PostgreSQL?**
- Easy setup - no need to install PostgreSQL directly on your system
- Consistent environment across different machines
- Easy to start, stop, and remove without affecting your system
- Isolated from other applications

## Step-by-Step Instructions

### Step 1: Verify Docker Installation

First, let's make sure Docker is installed on your system:

```bash
docker --version
```

If Docker is not installed, visit https://www.docker.com/get-started to install it.

### Step 2: Pull the PostgreSQL Image

Docker uses "images" as templates for containers. Let's download the official PostgreSQL image:

```bash
docker pull postgres:15
```

This downloads PostgreSQL version 15. The download may take a few minutes.

### Step 3: Run PostgreSQL Container

Now let's start a PostgreSQL container:

```bash
docker run --name my-postgres \
  -e POSTGRES_PASSWORD=mysecretpassword \
  -e POSTGRES_USER=postgres \
  -e POSTGRES_DB=mydb \
  -p 5432:5432 \
  -d postgres:15
```

Let's break down this command:
- `docker run` - creates and starts a new container
- `--name my-postgres` - gives the container a friendly name
- `-e POSTGRES_PASSWORD=mysecretpassword` - sets the database password
- `-e POSTGRES_USER=postgres` - sets the database user (default is 'postgres')
- `-e POSTGRES_DB=mydb` - creates a database named 'mydb'
- `-p 5432:5432` - maps port 5432 (PostgreSQL's default port) from container to your machine
- `-d` - runs the container in detached mode (in the background)
- `postgres:15` - the image to use

### Step 4: Verify Container is Running

Check if your container is running:

```bash
docker ps
```

You should see your `my-postgres` container in the list with status "Up".

### Step 5: Connect to PostgreSQL

Now let's connect to PostgreSQL inside the container:

```bash
docker exec -it my-postgres psql -U postgres -d mydb
```

This command:
- `docker exec -it` - executes a command in a running container interactively
- `my-postgres` - the container name
- `psql` - PostgreSQL's command-line client
- `-U postgres` - connect as user 'postgres'
- `-d mydb` - connect to database 'mydb'

You should now see a prompt like: `mydb=#`

### Step 6: Test the Connection

Let's run a simple command to verify everything works:

```sql
SELECT version();
```

This will display the PostgreSQL version. You should see output showing PostgreSQL 15.x.

### Step 7: Exit PostgreSQL

To exit the PostgreSQL prompt, type:

```sql
\q
```

## Useful Docker Commands

Here are some essential Docker commands you'll use:

```bash
# Stop the container
docker stop my-postgres

# Start a stopped container
docker start my-postgres

# View container logs
docker logs my-postgres

# Remove the container (WARNING: this deletes the container and its data)
docker rm -f my-postgres

# List all containers (including stopped ones)
docker ps -a
```

## Practice Tasks

1. Stop your PostgreSQL container, then start it again
2. View the container logs to see PostgreSQL startup messages
3. Connect to PostgreSQL again and run `SELECT current_database();` to see which database you're connected to
4. Try connecting to PostgreSQL from outside the container using:
   ```bash
   psql -h localhost -U postgres -d mydb
   ```
   (You may need to install PostgreSQL client tools for this)

## Key Concepts

- **Container**: A running instance of an image
- **Image**: A template used to create containers
- **Port Mapping**: `-p 5432:5432` maps container port to host port
- **Environment Variables**: `-e` sets configuration values
- **Detached Mode**: `-d` runs container in background

## Common Issues

**Problem**: Port 5432 is already in use
- **Solution**: Change the port mapping to `-p 5433:5432` and connect using port 5433

**Problem**: Container won't start
- **Solution**: Check logs with `docker logs my-postgres` to see error messages

**Problem**: Can't connect to PostgreSQL
- **Solution**: Make sure the container is running with `docker ps`

## Next Steps

Congratulations! You've successfully set up PostgreSQL in Docker. In the next exercise, we'll learn how to create databases and understand the PostgreSQL structure.

