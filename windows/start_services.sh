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

if ! ss -tnlp | grep ':3010' > /dev/null; then
  echo "Starting AFFiNE..."
  cd /home/fadzi/tools/affinity-main
  nohup sh -c 'node ./scripts/self-host-predeploy && node --loader ./scripts/loader.js ./dist/index.js' > /home/fadzi/tools/affinity-main/logs/affine_log.log 2>&1 &
else
  echo "AFFiNE is already running."
fi

export MB_DB_TYPE=postgres
export MB_DB_DBNAME=metabaseappdb
export MB_DB_PORT=5432
export MB_DB_USER=postgres
export MB_DB_PASS=postgres
export MB_DB_HOST=localhost

if ! ss -tnlp | grep ':3000' > /dev/null; then
  echo "Starting Metabase..."
  cd /home/fadzi/tools/metabase
  nohup java -jar metabase.jar > /home/fadzi/tools/metabase/logs/metabase_log.log 2>&1 &
else
  echo "Metabase is already running."
fi

export FLASK_APP=superset
export SUPERSET_CONFIG_PATH=/home/fadzi/tools/superset/superset_config.py

if ! ss -tnlp | grep ':8099' > /dev/null; then
  echo "Starting Apache Superset..."
  cd /home/fadzi/tools/superset
  source /home/fadzi/venv/bin/activate
  nohup superset run -p 8099 -h 0.0.0.0 --with-threads --reload --debugger > /home/fadzi/tools/superset/logs/superset_log.log 2>&1 &
else
  echo "Apache Superset is already running."
fi

if ! ss -tnlp | grep ':8088' > /dev/null; then
  echo "Starting Super Productivity..."
  cd /home/fadzi/tools/super-productivity-9.0.7/dist/browser
  nohup http-server -p 8088 > /home/fadzi/tools/super-productivity-9.0.7/dist/browser/logs/super_prod_log.log 2>&1 &
else
  echo "Super Productivity is already running."
fi
