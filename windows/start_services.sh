#!/bin/bash

function wait_for_postgres {
    echo "Waiting for PostgreSQL to start..."
    until pg_isready -h /var/lib/pgsql/socket; do
      sleep 1
    done
}

function wait_for_redis {
    echo "Waiting for Redis to respond..."
    until redis-cli ping | grep -q PONG; do
      sleep 1
    done
}

if ! pg_isready -h /var/lib/pgsql/socket > /dev/null 2>&1; then
  echo "Starting PostgreSQL..."
  sudo -u postgres pg_ctl -D /var/lib/pgsql/data start -l /var/lib/logs/logfile
  wait_for_postgres
  if ! pg_isready -h /var/lib/pgsql/socket > /dev/null 2>&1; then
      echo "Failed to start PostgreSQL."
      exit 1
  fi
else
  echo "PostgreSQL is already running."
fi

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

if ! lsof -i:3010 > /dev/null 2>&1; then
  echo "Starting  AFFiNE..."
  cd /home/fadzi/tools/affinity-main
  node ./scripts/self-host-predeploy && node ./dist/index.js &
else
  echo "AFFiNE already running."
fi

echo "Starting Super Productivity..."
cd /home/fadzi/tools/super-productivity-9.0.7/dist/browser
nohup http-server -p 8080 &

export MB_DB_TYPE=postgres
export MB_DB_DBNAME=metabaseappdb
export MB_DB_PORT=5432
export MB_DB_USER=postgres
export MB_DB_PASS=postgres
export MB_DB_HOST=localhost

echo "Starting Metabase..."
cd /home/fadzi/tools/metabase
if type java > /dev/null 2>&1; then
    java -jar metabase.jar &
else
    echo "Java not found, please install it to run Metabase."
    exit 1
fi

export FLASK_APP=superset
export SUPERSET_CONFIG_PATH=/home/fadzi/tools/superset/superset_config.py

echo "Starting Apache Superset..."
cd /home/fadzi/tools/superset
source /home/fadzi/venv/bin/activate
superset run -p 8099 -h 0.0.0.0 --with-threads --reload --debugger &

echo "Checking if Apache Superset is up..."
until $(curl --output /dev/null --silent --head --fail http://localhost:8099/health); do
    printf '.'
    sleep 5
done
echo "Apache Superset is up and running."
