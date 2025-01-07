#!/bin/bash

##############################################################################
# DEFAULT VARIABLES
##############################################################################

LOG_FILE="/var/log/services.log"

# PostgreSQL 13
POSTGRES_DATA_DIR="/var/lib/pgsql/13/data"
POSTGRES_SOCKET_DIR="/var/lib/pgsql/socket"
POSTGRES_LOG_DIR="/var/lib/logs"
POSTGRES_LOGFILE_NAME="postgres.log"
INITDB_BIN="/usr/pgsql-13/bin/initdb"
PGCTL_BIN="/usr/pgsql-13/bin/pg_ctl"

# Redis
REDIS_CONF_FILE="/etc/redis.conf"

# AFFiNE
AFFINE_HOME="/root/tools/affinity-main"
AFFINE_LOG_DIR="$AFFINE_HOME/logs"
AFFINE_PORT="3010"

# Metabase
METABASE_HOME="/root/tools/metabase"
METABASE_LOG_DIR="$METABASE_HOME/logs"
METABASE_PORT="3000"
METABASE_JAR="metabase.jar"

# Superset
SUPERSET_HOME="/root/superset"
SUPERSET_CONFIG="$SUPERSET_HOME/superset_config.py"
SUPERSET_LOG_DIR="$SUPERSET_HOME/logs"
SUPERSET_PORT="8099"

# Super Productivity
SUPER_PROD_HOME="/root/tools/super-productivity-9.0.7/dist/browser"
SUPER_PROD_LOG_DIR="$SUPER_PROD_HOME/logs"
SUPER_PROD_PORT="8088"

##############################################################################
# LOGGING
##############################################################################

function log {
    echo "$(date +'%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

##############################################################################
# WAIT FUNCTIONS
##############################################################################

function wait_for_postgres {
    log "Waiting for PostgreSQL..."
    until pg_isready -h "$POSTGRES_SOCKET_DIR" &>/dev/null; do
        sleep 1
    done
}

function wait_for_redis {
    log "Waiting for Redis..."
    until redis-cli ping 2>/dev/null | grep -q PONG; do
        sleep 1
    done
}

##############################################################################
# START FUNCTIONS
##############################################################################

function start_postgres {
    # Ensure /var/lib/logs exists and is owned by postgres
    if [ ! -d "$POSTGRES_LOG_DIR" ]; then
        mkdir -p "$POSTGRES_LOG_DIR"
        chown postgres:postgres "$POSTGRES_LOG_DIR"
    fi

    # Initialize if needed
    if [ ! -f "$POSTGRES_DATA_DIR/PG_VERSION" ]; then
        log "PostgreSQL not initialized. Initializing..."
        sudo -u postgres "$INITDB_BIN" -D "$POSTGRES_DATA_DIR"

        log "Starting PostgreSQL (first time)..."
        sudo -u postgres "$PGCTL_BIN" -D "$POSTGRES_DATA_DIR" \
            start -l "$POSTGRES_LOG_DIR/$POSTGRES_LOGFILE_NAME"
        wait_for_postgres

        log "Setting 'postgres' password to 'postgres'..."
        sudo -u postgres psql -c "ALTER USER postgres WITH PASSWORD 'postgres';"

        sudo -u postgres "$PGCTL_BIN" -D "$POSTGRES_DATA_DIR" stop
        log "Initialization done."
    fi

    # Start if not running
    if ! pg_isready -h "$POSTGRES_SOCKET_DIR" &>/dev/null; then
        log "Starting PostgreSQL..."
        sudo -u postgres "$PGCTL_BIN" -D "$POSTGRES_DATA_DIR" \
            start -l "$POSTGRES_LOG_DIR/$POSTGRES_LOGFILE_NAME"
        wait_for_postgres
        if ! pg_isready -h "$POSTGRES_SOCKET_DIR" &>/dev/null; then
            log "ERROR: PostgreSQL failed to start."
            exit 1
        fi
        log "PostgreSQL started."
    else
        log "PostgreSQL is already running."
    fi
}

function start_redis {
    if ! redis-cli ping &>/dev/null; then
        log "Starting Redis..."
        redis-server "$REDIS_CONF_FILE" &
        wait_for_redis
        if ! redis-cli ping | grep -q PONG; then
            log "ERROR: Redis failed to start."
            exit 1
        fi
        log "Redis started."
    else
        log "Redis is already running."
    fi
}

function start_affine {
    if ! ss -tnlp | grep ":$AFFINE_PORT" &>/dev/null; then
        log "Starting AFFiNE..."
        cd "$AFFINE_HOME" || exit
        nohup sh -c 'node ./scripts/self-host-predeploy && node --loader ./scripts/loader.js ./dist/index.js' \
          > "$AFFINE_LOG_DIR/affine_log.log" 2>&1 &
        sleep 5
        if ! ss -tnlp | grep ":$AFFINE_PORT" &>/dev/null; then
            log "ERROR: AFFiNE failed to start."
            exit 1
        fi
        log "AFFiNE started."
    else
        log "AFFiNE is already running."
    fi
}

function start_metabase {
    if ! ss -tnlp | grep ":$METABASE_PORT" &>/dev/null; then
        log "Starting Metabase..."
        cd "$METABASE_HOME" || exit
        nohup java -jar "$METABASE_JAR" \
          > "$METABASE_LOG_DIR/metabase_log.log" 2>&1 &
        sleep 5
        if ! ss -tnlp | grep ":$METABASE_PORT" &>/dev/null; then
            log "ERROR: Metabase failed to start."
            exit 1
        fi
        log "Metabase started."
    else
        log "Metabase is already running."
    fi
}

function start_superset {
    if ! ss -tnlp | grep ":$SUPERSET_PORT" &>/dev/null; then
        log "Starting Superset..."
        export SUPERSET_CONFIG_PATH="$SUPERSET_CONFIG"
        cd "$SUPERSET_HOME" || exit
        nohup superset run -p "$SUPERSET_PORT" -h 0.0.0.0 --with-threads --reload --debugger \
          > "$SUPERSET_LOG_DIR/superset_log.log" 2>&1 &
        sleep 5
        if ! ss -tnlp | grep ":$SUPERSET_PORT" &>/dev/null; then
            log "ERROR: Superset failed to start."
            exit 1
        fi
        log "Superset started."
    else
        log "Superset is already running."
    fi
}

function start_super_productivity {
    if ! ss -tnlp | grep ":$SUPER_PROD_PORT" &>/dev/null; then
        log "Starting Super Productivity..."
        cd "$SUPER_PROD_HOME" || exit
        nohup http-server -p "$SUPER_PROD_PORT" \
          > "$SUPER_PROD_LOG_DIR/super_prod_log.log" 2>&1 &
        sleep 5
        if ! ss -tnlp | grep ":$SUPER_PROD_PORT" &>/dev/null; then
            log "ERROR: Super Productivity failed to start."
            exit 1
        fi
        log "Super Productivity started."
    else
        log "Super Productivity is already running."
    fi
}

##############################################################################
# STOP / RESTART
##############################################################################

function stop_all {
    log "Stopping all services..."
    pkill -f http-server
    pkill -f superset
    pkill -f "$METABASE_JAR"
    pkill -f 'node --loader ./scripts/loader.js ./dist/index.js'
    pkill redis-server
    sudo -u postgres "$PGCTL_BIN" -D "$POSTGRES_DATA_DIR" stop
    log "All services stopped."
}

function start_all {
    log "Starting all services..."
    start_postgres
    start_redis
    start_affine
    start_metabase
    start_superset
    start_super_productivity
    log "All services started."
}

function restart_all {
    log "Restarting all services..."
    stop_all
    start_all
}

##############################################################################
# MENU
##############################################################################

case $1 in
    start)
        case $2 in
            all) start_all ;;
            postgres) start_postgres ;;
            redis) start_redis ;;
            affine) start_affine ;;
            metabase) start_metabase ;;
            superset) start_superset ;;
            super-productivity) start_super_productivity ;;
            *) echo "Usage: $0 start {service|all}" ;;
        esac
        ;;
    stop)
        case $2 in
            all) stop_all ;;
            *) echo "Usage: $0 stop {all}" ;;
        esac
        ;;
    restart)
        case $2 in
            all) restart_all ;;
            *) echo "Usage: $0 restart {all}" ;;
        esac
        ;;
    *)
        echo "Usage: $0 {start|stop|restart} {service|all}"
        ;;
esac
