#!/bin/bash

##############################################################################
# CONFIG
##############################################################################

LOG_FILE="/var/log/services.log"

# Postgres
POSTGRES_DATA_DIR="/var/lib/pgsql/13/data"
POSTGRES_LOG_DIR="/var/lib/logs"
POSTGRES_LOGFILE_NAME="postgres.log"
INITDB_BIN="/usr/pgsql-13/bin/initdb"
PGCTL_BIN="/usr/pgsql-13/bin/pg_ctl"
PG_HOST="127.0.0.1"
PG_PORT="5432"
PG_MAX_WAIT=10

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

export MB_DB_TYPE="postgres"
export MB_DB_DBNAME="metabaseappdb"
export MB_DB_PORT="5432"
export MB_DB_USER="postgres"
export MB_DB_PASS="postgres"
export MB_DB_HOST="localhost"


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
# LOGGING & HELPERS
##############################################################################

log() {
    echo "$(date +'%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

psql_check() {
    su postgres -c "psql --host=$PG_HOST --port=$PG_PORT --username=postgres -c '\q'" 2>/dev/null
}

##############################################################################
# Ensure directories for each service
##############################################################################

ensure_dir() {
    local dirpath="$1"
    if [ ! -d "$dirpath" ]; then
        log "Creating directory: $dirpath"
        mkdir -p "$dirpath"
    fi
}

##############################################################################
# POSTGRES INIT / START / STOP
##############################################################################

ensure_permissions() {
    ensure_dir "$POSTGRES_DATA_DIR"
    chown -R postgres:postgres "$POSTGRES_DATA_DIR"
    chmod 700 "$POSTGRES_DATA_DIR"

    ensure_dir "$POSTGRES_LOG_DIR"
    chown postgres:postgres "$POSTGRES_LOG_DIR"
}

init_postgres() {
    ensure_permissions
    if [ -f "$POSTGRES_DATA_DIR/PG_VERSION" ]; then
        log "PostgreSQL already initialized; skipping."
        return 0
    fi

    log "Initializing PostgreSQL..."
    sudo -u postgres "$INITDB_BIN" -D "$POSTGRES_DATA_DIR"

    log "Configuring PostgreSQL for remote access..."
    su postgres -c "echo \"listen_addresses = '*'\" >> \"$POSTGRES_DATA_DIR/postgresql.conf\""
    su postgres -c "echo \"host all all 0.0.0.0/0 md5\" >> \"$POSTGRES_DATA_DIR/pg_hba.conf\""

    log "Starting PostgreSQL (init) ..."
    sudo -u postgres "$PGCTL_BIN" -D "$POSTGRES_DATA_DIR" \
        start -l "$POSTGRES_LOG_DIR/postgres_init.log"

    local init_ok=false
    for i in $(seq 1 $PG_MAX_WAIT); do
        if psql_check; then
            log "PostgreSQL init: setting password 'postgres'..."
            su postgres -c "psql -c \"ALTER USER postgres WITH PASSWORD 'postgres';\""

            log "Creating 'superset' DB if not exists..."
            su postgres -c "psql -tc \"SELECT 1 FROM pg_database WHERE datname = 'superset'\" | grep -q 1 || psql -c \"CREATE DATABASE superset WITH OWNER postgres;\""

            log "Creating 'metabaseappdb' DB if not exists..."
            su postgres -c "psql -tc \"SELECT 1 FROM pg_database WHERE datname = 'metabaseappdb'\" | grep -q 1 || psql -c \"CREATE DATABASE metabaseappdb WITH OWNER postgres;\""

            log "Creating 'affine' DB if not exists..."
            su postgres -c "psql -tc \"SELECT 1 FROM pg_database WHERE datname = 'affine'\" | grep -q 1 || psql -c \"CREATE DATABASE affine WITH OWNER postgres;\""

            init_ok=true
            break
        fi
        sleep 1
    done

    if [ "$init_ok" = false ]; then
        log "ERROR: PostgreSQL did not become ready within $PG_MAX_WAIT seconds (init)."
        sudo -u postgres "$PGCTL_BIN" -D "$POSTGRES_DATA_DIR" stop &>/dev/null
        return 1
    fi

    log "Stopping after init..."
    sudo -u postgres "$PGCTL_BIN" -D "$POSTGRES_DATA_DIR" stop
    sleep 2
    log "Initialization complete."
    return 0
}

start_postgres() {
    ensure_permissions

    if [ ! -f "$POSTGRES_DATA_DIR/PG_VERSION" ]; then
        log "ERROR: PostgreSQL not initialized. Run: services.sh init postgres"
        return 1
    fi

    if psql_check; then
        log "PostgreSQL is already running."
        return 0
    fi

    log "Starting PostgreSQL..."
    sudo -u postgres "$PGCTL_BIN" -D "$POSTGRES_DATA_DIR" \
        start -l "$POSTGRES_LOG_DIR/postgres.log"

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
    redis-server /etc/redis.conf &
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
    # Ensure directories exist for AFFiNE
    ensure_dir "$AFFINE_HOME"
    ensure_dir "$AFFINE_LOG_DIR"

    # Ensure Postgres is running
    if ! psql_check; then
        log "ERROR: Postgres is not running; cannot start Affine."
        return 1
    fi

    if ss -tnlp | grep ":$AFFINE_PORT" &>/dev/null; then
        log "AFFiNE is already running."
        return 0
    fi

    log "Starting AFFiNE..."
    cd "$AFFINE_HOME" || return 1
    nohup sh -c 'node ./scripts/self-host-predeploy && node --loader ./scripts/loader.js ./dist/index.js' \
      > "$AFFINE_LOG_DIR/affine_log.log" 2>&1 &
    sleep 5

    if ! ss -tnlp | grep ":$AFFINE_PORT" &>/dev/null; then
        log "ERROR: AFFiNE failed to start."
        return 1
    fi
    log "AFFiNE started."
    return 0
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

    # Ensure Postgres is running
    if ! psql_check; then
        log "ERROR: Postgres is not running; cannot start Metabase."
        return 1
    fi

    if ss -tnlp | grep ":$METABASE_PORT" &>/dev/null; then
        log "Metabase is already running."
        return 0
    fi

    log "Starting Metabase..."
    cd "$METABASE_HOME" || return 1
    nohup java -jar "$METABASE_JAR" \
      > "$METABASE_LOG_DIR/metabase_log.log" 2>&1 &
    sleep 5

    if ! ss -tnlp | grep ":$METABASE_PORT" &>/dev/null; then
        log "ERROR: Metabase failed to start."
        return 1
    fi
    log "Metabase started."
    return 0
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
# HELPER: Check if Redis is running
##############################################################################
redis_check() {
    # Return 0 if redis-server is found, else non-zero
    pgrep -f "redis-server" &>/dev/null
}

##############################################################################
# SUPERSET INIT
##############################################################################

init_superset() {
    # Ensure Postgres is running
    if ! psql_check; then
        log "ERROR: PostgreSQL is not running; cannot init Superset."
        return 1
    fi

    # Ensure Redis is running (if your superset config depends on it)
    if ! redis_check; then
        log "ERROR: Redis is not running; cannot init Superset."
        return 1
    fi

    export FLASK_APP=superset
    export SUPERSET_CONFIG_PATH="$SUPERSET_CONFIG"

    log "Initializing Superset..."

    # 1) Migrate the DB (create tables, etc.)
    superset db upgrade

    # 2) Create admin user (adjust username/password as needed)
    superset fab create-admin \
        --username admin \
        --password admin \
        --firstname Admin \
        --lastname User \
        --email admin@admin.com

    # 3) Load examples (optional)
    superset load_examples

    # 4) Finalize
    superset init

    # Create sentinel file so 'start_superset' knows we're initialized
    touch /root/tools/superset/.superset_init_done

    log "Superset initialization complete."
    return 0
}


##############################################################################
# SUPERTSET START / STOP
##############################################################################

start_superset() {
    # Ensure Postgres is running
    if ! psql_check; then
        log "ERROR: Postgres is not running; cannot start Superset."
        return 1
    fi

    # Ensure Redis is running
    if ! redis_check; then
        log "ERROR: Redis is not running; cannot start Superset."
        return 1
    fi

    if [ ! -f "/root/tools/superset/.superset_init_done" ]; then
        log "ERROR: Superset not initialized. Run: services.sh init superset"
        return 1
    fi

    # Create dirs if missing
    ensure_dir "$SUPERSET_HOME"
    ensure_dir "$SUPERSET_LOG_DIR"

    # Check if Superset is already up
    if ss -tnlp | grep ":$SUPERSET_PORT" &>/dev/null; then
        log "Superset is already running."
        return 0
    fi

    # Export needed env vars
    export FLASK_APP=superset
    export SUPERSET_CONFIG_PATH="$SUPERSET_CONFIG"

    log "Starting Superset..."
    cd "$SUPERSET_HOME" || return 1
    nohup superset run -p "$SUPERSET_PORT" -h 0.0.0.0 --with-threads --reload --debugger \
      > "$SUPERSET_LOG_DIR/superset_log.log" 2>&1 &

    sleep 5

    if ! ss -tnlp | grep ":$SUPERSET_PORT" &>/dev/null; then
        log "ERROR: Superset failed to start."
        return 1
    fi
    log "Superset started."
    return 0
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
# SUPER PRODUCTIVITY
##############################################################################

start_super_productivity() {
    ensure_dir "$SUPER_PROD_HOME"
    ensure_dir "$SUPER_PROD_LOG_DIR"

    if ss -tnlp | grep ":$SUPER_PROD_PORT" &>/dev/null; then
        log "Super Productivity is already running."
        return 0
    fi

    log "Starting Super Productivity..."
    cd "$SUPER_PROD_HOME" || return 1
    nohup http-server -p "$SUPER_PROD_PORT" \
      > "$SUPER_PROD_LOG_DIR/super_prod_log.log" 2>&1 &
    sleep 5

    if ! ss -tnlp | grep ":$SUPER_PROD_PORT" &>/dev/null; then
        log "ERROR: Super Productivity failed to start."
        return 1
    fi
    log "Super Productivity started."
    return 0
}

stop_super_productivity() {
    log "Stopping Super Productivity..."
    pkill -f "http-server -p $SUPER_PROD_PORT"
    sleep 1
    if ss -tnlp | grep ":$SUPER_PROD_PORT" &>/dev/null; then
        log "ERROR: Super Productivity did not stop."
        return 1
    fi
    log "Super Productivity stopped."
    return 0
}

##############################################################################
# START/STOP ALL (Short-Circuit on Failure)
##############################################################################

start_all() {
    log "Starting all services..."

    # 1) Postgres must be initialized
    if [ ! -f "$POSTGRES_DATA_DIR/PG_VERSION" ]; then
        log "ERROR: PostgreSQL not initialized. Run: services.sh init postgres"
        return 1
    fi

    # 2) Postgres must succeed
    start_postgres || {
        log "ERROR: Cannot continue. Postgres is required."
        return 1
    }

    # 3) Redis must succeed
    start_redis || {
        log "ERROR: Cannot continue. Redis is required."
        return 1
    }

    # 4) AFFiNE
    start_affine || return 1

    # 5) Metabase
    start_metabase || return 1

    # 6) Superset
    start_superset || return 1

    # 7) Super Productivity
    start_super_productivity || return 1

    log "All services started."
    return 0
}

stop_all() {
    log "Stopping all services..."
    stop_super_productivity
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
    if [ ! -f "$POSTGRES_DATA_DIR/PG_VERSION" ]; then
        log "ERROR: Cannot restart PostgreSQL. Not initialized."
        return 1
    fi
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

restart_super_productivity() {
    stop_super_productivity
    start_super_productivity
}

restart_all() {
    log "Restarting all services..."

    if [ ! -f "$POSTGRES_DATA_DIR/PG_VERSION" ]; then
        log "ERROR: Cannot restart all. PostgreSQL not initialized."
        return 1
    fi

    stop_all
    start_all
}

##############################################################################
# MENU
##############################################################################

case "$1" in
    init)
        case "$2" in
            postgres)
                init_postgres
                ;;
            superset)
                init_superset
                ;;
            *)
                echo "Usage: $0 init {postgres|superset}"
                ;;
        esac
        ;;
    start)
        case "$2" in
            all) start_all ;;
            postgres) start_postgres ;;
            redis) start_redis ;;
            affine) start_affine ;;
            metabase) start_metabase ;;
            superset) start_superset ;;
            super-productivity) start_super_productivity ;;
            *) echo "Usage: $0 start {all|postgres|redis|affine|metabase|superset|super-productivity}" ;;
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
            super-productivity) stop_super_productivity ;;
            *) echo "Usage: $0 stop {all|postgres|redis|affine|metabase|superset|super-productivity}" ;;
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
            super-productivity) restart_super_productivity ;;
            *) echo "Usage: $0 restart {all|postgres|redis|affine|metabase|superset|super-productivity}" ;;
        esac
        ;;
    *)
        echo "Usage: $0 {init|start|stop|restart} {service|all}"
        ;;
esac
