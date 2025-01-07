#!/bin/bash

##############################################################################
# CONFIG
##############################################################################

LOG_FILE="/var/log/services.log"

POSTGRES_DATA_DIR="/var/lib/pgsql/13/data"
POSTGRES_LOG_DIR="/var/lib/logs"
POSTGRES_LOGFILE_NAME="postgres.log"

INITDB_BIN="/usr/pgsql-13/bin/initdb"
PGCTL_BIN="/usr/pgsql-13/bin/pg_ctl"

PG_HOST="127.0.0.1"
PG_PORT="5432"
MAX_WAIT=10  # seconds for readiness checks

##############################################################################
# LOGGING & UTILS
##############################################################################

log() {
    echo "$(date +'%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

psql_check() {
    # If we can connect & run a trivial query, Postgres is ready
    su postgres -c "psql --host=$PG_HOST --port=$PG_PORT --username=postgres -c '\q'" 2>/dev/null
}

##############################################################################
# PERMISSIONS
##############################################################################

ensure_permissions() {
    if [ ! -d "$POSTGRES_DATA_DIR" ]; then
        log "Creating PostgreSQL data directory at $POSTGRES_DATA_DIR..."
        mkdir -p "$POSTGRES_DATA_DIR"
    fi
    log "Ensuring correct ownership and permissions for $POSTGRES_DATA_DIR..."
    chown -R postgres:postgres "$POSTGRES_DATA_DIR"
    chmod 700 "$POSTGRES_DATA_DIR"

    if [ ! -d "$POSTGRES_LOG_DIR" ]; then
        mkdir -p "$POSTGRES_LOG_DIR"
        chown postgres:postgres "$POSTGRES_LOG_DIR"
    fi
}

##############################################################################
# INITIALIZE POSTGRES
##############################################################################

init_postgres() {
    ensure_permissions

    if [ -f "$POSTGRES_DATA_DIR/PG_VERSION" ]; then
        log "PostgreSQL already initialized; skipping."
        return 0
    fi

    log "Initializing PostgreSQL..."
    sudo -u postgres "$INITDB_BIN" -D "$POSTGRES_DATA_DIR"

    # Inline config changes for remote access
    log "Configuring PostgreSQL for remote access..."
    su postgres -c "echo \"listen_addresses = '*'\" >> \"$POSTGRES_DATA_DIR/postgresql.conf\""
    su postgres -c "echo \"host all all 0.0.0.0/0 md5\" >> \"$POSTGRES_DATA_DIR/pg_hba.conf\""

    # Start once, set password, stop
    log "Starting PostgreSQL for initialization..."
    sudo -u postgres "$PGCTL_BIN" -D "$POSTGRES_DATA_DIR" \
        start -l "$POSTGRES_LOG_DIR/$POSTGRES_LOGFILE_NAME"

    init_ok=false
    for i in $(seq 1 $MAX_WAIT); do
        if psql_check; then
            log "PostgreSQL (init) is up; setting password 'postgres'..."
            su postgres -c "psql --host=$PG_HOST --port=$PG_PORT --username=postgres -c \"ALTER USER postgres WITH PASSWORD 'postgres';\""
            init_ok=true
            break
        fi
        sleep 1
    done

    if [ "$init_ok" = false ]; then
        log "ERROR: PostgreSQL did not become ready within $MAX_WAIT seconds (init)."
        sudo -u postgres "$PGCTL_BIN" -D "$POSTGRES_DATA_DIR" stop &>/dev/null
        return 1
    fi

    log "Stopping PostgreSQL after initialization..."
    sudo -u postgres "$PGCTL_BIN" -D "$POSTGRES_DATA_DIR" stop
    sleep 2  # ensure fully stopped
    log "Initialization done."
    return 0
}

##############################################################################
# START POSTGRES
##############################################################################

start_postgres() {
    ensure_permissions

    # If not initialized, fail
    if [ ! -f "$POSTGRES_DATA_DIR/PG_VERSION" ]; then
        log "ERROR: PostgreSQL is not initialized. Run 'services.sh init postgres' first."
        return 1
    fi

    # If already running, do nothing
    if psql_check; then
        log "PostgreSQL is already running."
        return 0
    fi

    log "Starting PostgreSQL normally..."
    sudo -u postgres "$PGCTL_BIN" -D "$POSTGRES_DATA_DIR" \
        start -l "$POSTGRES_LOG_DIR/$POSTGRES_LOGFILE_NAME"

    started_ok=false
    for i in $(seq 1 $MAX_WAIT); do
        if psql_check; then
            log "PostgreSQL started successfully."
            started_ok=true
            break
        fi
        sleep 1
    done

    if [ "$started_ok" = false ]; then
        log "ERROR: PostgreSQL did not become ready within $MAX_WAIT seconds."
        return 1
    fi
    return 0
}

##############################################################################
# STOP POSTGRES
##############################################################################

stop_postgres() {
    if ! psql_check; then
        log "PostgreSQL is not running."
        return 0
    fi

    log "Stopping PostgreSQL..."
    sudo -u postgres "$PGCTL_BIN" -D "$POSTGRES_DATA_DIR" stop

    stopped_ok=false
    for i in $(seq 1 $MAX_WAIT); do
        if ! psql_check; then
            log "PostgreSQL stopped successfully."
            stopped_ok=true
            break
        fi
        sleep 1
    done

    if [ "$stopped_ok" = false ]; then
        log "ERROR: PostgreSQL did not stop within $MAX_WAIT seconds."
        return 1
    fi
    return 0
}

##############################################################################
# MENU
##############################################################################

case "$1" in
    init)
        case "$2" in
            postgres) init_postgres ;;
            *) echo "Usage: $0 init postgres" ;;
        esac
        ;;
    start)
        case "$2" in
            postgres) start_postgres ;;
            *) echo "Usage: $0 start postgres" ;;
        esac
        ;;
    stop)
        case "$2" in
            postgres) stop_postgres ;;
            *) echo "Usage: $0 stop postgres" ;;
        esac
        ;;
    *)
        echo "Usage: $0 {init|start|stop} postgres"
        ;;
esac
