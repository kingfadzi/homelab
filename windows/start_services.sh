#!/bin/bash

# Function to check if PostgreSQL is ready
function wait_for_postgres {
    echo "Waiting for PostgreSQL to start..."
    until pg_isready -h /var/lib/pgsql/socket; do  # Adjust the path as necessary for the socket
      sleep 1
    done
}

# Function to check if Redis is ready
function wait_for_redis {
    echo "Waiting for Redis to respond..."
    until redis-cli ping | grep -q PONG; do
      sleep 1
    done
}

# Start PostgreSQL
if ! pg_isready -h /var/lib/pgsql/socket > /dev/null 2>&1; then  # Ensure the host path is correctly specified
  echo "Starting PostgreSQL..."
  pg_ctl -D /var/lib/pgsql/data start  # Ensure the data directory is correctly specified
  wait_for_postgres
  if ! pg_isready -h /var/lib/pgsql/socket > /dev/null 2>&1; then
      echo "Failed to start PostgreSQL."
      exit 1
  fi
else
  echo "PostgreSQL is already running."
fi

# Start Redis
if ! redis-cli ping > /dev/null 2>&1; then
  echo "Starting Redis..."
  redis-server /etc/redis/redis.conf &
  wait_for_redis
  if ! redis-cli ping | grep -q PONG > /dev/null 2>&1; then
      echo "Failed to start Redis."
      exit 1
  fi
else
  echo "Redis is already running."
fi

# Start Node.js App
if ! lsof -i:3010 > /dev/null 2>&1; then
  echo "Starting Node.js app..."
  cd /path/to/your/node/app
  node ./scripts/self-host-predeploy && node ./dist/index.js &
else
  echo "Node.js app already running."
fi

# Start Super Productivity
echo "Starting Super Productivity..."
cd /path/to/super-productivity
nohup http-server -p 8080 &
