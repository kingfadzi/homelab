#!/bin/bash

##############################################################################
# CONFIG
##############################################################################

# Determine the real home directory for installations.
if [ -n "${SUDO_USER:-}" ]; then
    USER_HOME=$(getent passwd "$SUDO_USER" | cut -d: -f6)
else
    USER_HOME="$HOME"
fi

LOG_FILE="/var/log/services.log"

# Postgres
POSTGRES_DATA_DIR="/var/lib/pgsql/13/data"
POSTGRES_LOG_DIR="/var/lib/logs"
PGCTL_BIN="/usr/pgsql-13/bin/pg_ctl"
PG_HOST="127.0.0.1"
PG_PORT="5432"
PG_MAX_WAIT=10

# Redis
REDIS_CONF_FILE="/etc/redis.conf"

# AFFiNE
AFFINE_HOME="$USER_HOME/tools/affinity-main"
AFFINE_LOG_DIR="$AFFINE_HOME/logs"
AFFINE_PORT="3010"

# Metabase
METABASE_HOME="$USER_HOME/tools/metabase"
METABASE_LOG_DIR="$METABASE_HOME/logs"
METABASE_PORT="3000"
METABASE_JAR="metabase.jar"

export MB_DB_TYPE="postgres"
export MB_DB_DBNAME="metabase"
export MB_DB_PORT="5432"
export MB_DB_USER="postgres"
export MB_DB_PASS="postgres"
export MB_DB_HOST="localhost"

# Superset
SUPERSET_HOME="$USER_HOME/tools/superset"
SUPERSET_CONFIG="$SUPERSET_HOME/superset_config.py"
SUPERSET_LOG_DIR="$SUPERSET_HOME/logs"
SUPERSET_PORT="8099"

##############################################################################
# LOGGING & HELPERS
##############################################################################

log() {
    echo "$(date +'%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

psql_check() {
    su postgres -c "psql --host=$PG_HOST --port=$PG_PORT --username=postgres -c '\q'" 2>/dev/null
}

ensure_dir() {
    local dirpath="$1"
    if [ ! -d "$dirpath" ]; then
        log "Creating directory: $dirpath"
        mkdir -p "$dirpath"
    fi
}

##############################################################################
# POSTGRES START / STOP
##############################################################################

start_postgres() {
    ensure_dir "$POSTGRES_DATA_DIR"
    ensure_dir "$POSTGRES_LOG_DIR"
    if [ ! -f "$POSTGRES_DATA_DIR/PG_VERSION" ]; then
        log "ERROR: PostgreSQL not initialized. Please run the install script first."
        return 1
    fi

    if psql_check; then
        log "PostgreSQL is already running."
        return 0
    fi

    log "Starting PostgreSQL..."
    sudo -u postgres "$PGCTL_BIN" -D "$POSTGRES_DATA_DIR" start -l "$POSTGRES_LOG_DIR/postgres.log"
    local started_ok=false
    for i in $(seq 1 $PG_MAX_WAIT); do
        if psql_check; then
            log "PostgreSQL started successfully."
            started_ok=true
            break
        fi
        sleep 1
    done

    if [ "$started_ok" = false ]; then
        log "ERROR: Postgres not ready after $PG_MAX_WAIT seconds."
        return 1
    fi
    return 0
}

stop_postgres() {
    if ! psql_check; then
        log "PostgreSQL is not running."
        return 0
    fi

    log "Stopping PostgreSQL..."
    sudo -u postgres "$PGCTL_BIN" -D "$POSTGRES_DATA_DIR" stop
    local stopped_ok=false
    for i in $(seq 1 $PG_MAX_WAIT); do
        if ! psql_check; then
            log "PostgreSQL stopped successfully."
            stopped_ok=true
            break
        fi
        sleep 1
    done
    if [ "$stopped_ok" = false ]; then
        log "ERROR: Postgres did not stop within $PG_MAX_WAIT seconds."
        return 1
    fi
    return 0
}

##############################################################################
# REDIS
##############################################################################

start_redis() {
    if pgrep -f "redis-server" &>/dev/null; then
        log "Redis is already running."
        return 0
    fi

    log "Starting Redis..."
    redis-server "$REDIS_CONF_FILE" &
    sleep 1
    if ! pgrep -f "redis-server" &>/dev/null; then
        log "ERROR: Redis failed to start."
        return 1
    fi
    log "Redis started."
    return 0
}

stop_redis() {
    log "Stopping Redis..."
    pkill -f "redis-server"
    sleep 1
    if pgrep -f "redis-server" &>/dev/null; then
        log "ERROR: Redis did not stop."
        return 1
    fi
    log "Redis stopped."
    return 0
}

##############################################################################
# AFFiNE
##############################################################################

start_affine() {
    ensure_dir "$AFFINE_HOME"
    ensure_dir "$AFFINE_LOG_DIR"
    if ss -tnlp | grep ":$AFFINE_PORT" &>/dev/null; then
        log "AFFiNE is already running."
        return 0
    fi

    log "Starting AFFiNE..."
    cd "$AFFINE_HOME" || return 1
    nohup sh -c 'node ./scripts/self-host-predeploy && node --loader ./scripts/loader.js ./dist/index.js' \
      > "$AFFINE_LOG_DIR/affine_log.log" 2>&1 &
    for i in {1..30}; do
        if ss -tnlp | grep ":$AFFINE_PORT" &>/dev/null; then
            log "AFFiNE started."
            return 0
        fi
        sleep 1
    done
    log "ERROR: AFFiNE failed to start after 30 seconds."
    return 1
}

stop_affine() {
    log "Stopping AFFiNE..."
    pkill -f 'node --loader ./scripts/loader.js ./dist/index.js'
    sleep 1
    if ss -tnlp | grep ":$AFFINE_PORT" &>/dev/null; then
        log "ERROR: AFFiNE did not stop."
        return 1
    fi
    log "AFFiNE stopped."
    return 0
}

##############################################################################
# METABASE
##############################################################################

start_metabase() {
    ensure_dir "$METABASE_HOME"
    ensure_dir "$METABASE_LOG_DIR"
    if ss -tnlp | grep ":$METABASE_PORT" &>/dev/null; then
        log "Metabase is already running."
        return 0
    fi

    log "Starting Metabase..."
    cd "$METABASE_HOME" || return 1
    nohup java -jar "$METABASE_JAR" \
      > "$METABASE_LOG_DIR/metabase_log.log" 2>&1 &
    for i in {1..30}; do
        if ss -tnlp | grep ":$METABASE_PORT" &>/dev/null; then
            log "Metabase started."
            return 0
        fi
        sleep 1
    done
    log "ERROR: Metabase failed to start after 30 seconds."
    return 1
}

stop_metabase() {
    log "Stopping Metabase..."
    pkill -f "$METABASE_JAR"
    sleep 1
    if ss -tnlp | grep ":$METABASE_PORT" &>/dev/null; then
        log "ERROR: Metabase did not stop."
        return 1
    fi
    log "Metabase stopped."
    return 0
}

##############################################################################
# SUPERSET
##############################################################################

start_superset() {
    if ! psql_check; then
        log "ERROR: Postgres is not running; cannot start Superset."
        return 1
    fi
    if ! pgrep -f "redis-server" &>/dev/null; then
        log "ERROR: Redis is not running; cannot start Superset."
        return 1
    fi
    if [ ! -f "$SUPERSET_HOME/.superset_init_done" ]; then
        log "ERROR: Superset not initialized. Initialization must be done separately."
        return 1
    fi
    ensure_dir "$SUPERSET_HOME"
    ensure_dir "$SUPERSET_LOG_DIR"
    if ss -tnlp | grep ":$SUPERSET_PORT" &>/dev/null; then
        log "Superset is already running."
        return 0
    fi
    cd "$SUPERSET_HOME" || return 1
    source env/bin/activate
    export FLASK_APP=superset
    export SUPERSET_CONFIG_PATH="$SUPERSET_CONFIG"
    log "Starting Superset..."
    nohup superset run -p "$SUPERSET_PORT" -h 0.0.0.0 --with-threads --reload --debugger \
      > "$SUPERSET_LOG_DIR/superset_log.log" 2>&1 &
    for i in {1..30}; do
        if ss -tnlp | grep ":$SUPERSET_PORT" &>/dev/null; then
            log "Superset started."
            return 0
        fi
        sleep 1
    done
    log "ERROR: Superset failed to start after 30 seconds."
    return 1
}

stop_superset() {
    log "Stopping Superset..."
    pkill -f "superset run"
    sleep 1
    if ss -tnlp | grep ":$SUPERSET_PORT" &>/dev/null; then
        log "ERROR: Superset did not stop."
        return 1
    fi
    log "Superset stopped."
    return 0
}

##############################################################################
# START/STOP ALL
##############################################################################

start_all() {
    log "Starting all services..."
    start_postgres || { log "ERROR: Postgres is required."; return 1; }
    start_redis || { log "ERROR: Redis is required."; return 1; }
    start_affine || return 1
    start_metabase || return 1
    start_superset || return 1
    log "All services started."
    return 0
}

stop_all() {
    log "Stopping all services..."
    stop_superset
    stop_metabase
    stop_affine
    stop_redis
    stop_postgres
    log "All services stopped."
}

##############################################################################
# RESTART
##############################################################################

restart_postgres() {
    stop_postgres
    start_postgres
}

restart_redis() {
    stop_redis
    start_redis
}

restart_affine() {
    stop_affine
    start_affine
}

restart_metabase() {
    stop_metabase
    start_metabase
}

restart_superset() {
    stop_superset
    start_superset
}

restart_all() {
    log "Restarting all services..."
    stop_all
    start_all
}

##############################################################################
# STATUS FUNCTIONS
##############################################################################

status_postgres() {
    if psql_check; then
        log "PostgreSQL is running."
    else
        log "PostgreSQL is NOT running."
    fi
}

status_redis() {
    if pgrep -f "redis-server" &>/dev/null; then
        log "Redis is running."
    else
        log "Redis is NOT running."
    fi
}

status_affine() {
    if ss -tnlp | grep ":$AFFINE_PORT" &>/dev/null; then
        log "AFFiNE is running."
    else
        log "AFFiNE is NOT running."
    fi
}

status_metabase() {
    if ss -tnlp | grep ":$METABASE_PORT" &>/dev/null; then
        log "Metabase is running."
    else
        log "Metabase is NOT running."
    fi
}

status_superset() {
    if ss -tnlp | grep ":$SUPERSET_PORT" &>/dev/null; then
        log "Superset is running."
    else
        log "Superset is NOT running."
    fi
}

status_all() {
    status_postgres
    status_redis
    status_affine
    status_metabase
    status_superset
}

##############################################################################
# MENU
##############################################################################

case "$1" in
    start)
        case "$2" in
            all) start_all ;;
            postgres) start_postgres ;;
            redis) start_redis ;;
            affine) start_affine ;;
            metabase) start_metabase ;;
            superset) start_superset ;;
            *) echo "Usage: $0 start {all|postgres|redis|affine|metabase|superset}" ;;
        esac
        ;;
    stop)
        case "$2" in
            all) stop_all ;;
            postgres) stop_postgres ;;
            redis) stop_redis ;;
            affine) stop_affine ;;
            metabase) stop_metabase ;;
            superset) stop_superset ;;
            *) echo "Usage: $0 stop {all|postgres|redis|affine|metabase|superset}" ;;
        esac
        ;;
    restart)
        case "$2" in
            all) restart_all ;;
            postgres) restart_postgres ;;
            redis) restart_redis ;;
            affine) restart_affine ;;
            metabase) restart_metabase ;;
            superset) restart_superset ;;
            *) echo "Usage: $0 restart {all|postgres|redis|affine|metabase|superset}" ;;
        esac
        ;;
    status)
        case "$2" in
            all) status_all ;;
            postgres) status_postgres ;;
            redis) status_redis ;;
            affine) status_affine ;;
            metabase) status_metabase ;;
            superset) status_superset ;;
            *) echo "Usage: $0 status {all|postgres|redis|affine|metabase|superset}" ;;
        esac
        ;;
    *)
        echo "Usage: $0 {start|stop|restart|status} {service|all}"
        ;;
esac