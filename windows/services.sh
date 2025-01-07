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

PG_HOST="127.0.0.1"   # We'll use TCP to check readiness
PG_PORT="5432"
MAX_WAIT=10          # seconds to wait in readiness loops

##############################################################################
# LOGGING & UTILS
##############################################################################

log() {
    echo "$(date +'%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

function psql_check {
    # We'll rely on a simple test query
    # '-c "\q"' effectively just connects & quits
    # 2>/dev/null hides connection errors
    su postgres -c "psql --host=$PG_HOST --port=$PG_PORT --username=postgres -c '\q'" 2>/dev/null
}

##############################################################################
# PERMISSIONS CHECK
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
# START & WAIT FOR READINESS
##############################################################################

start_postgres() {
    ensure_permissions

    # If DB uninitialized
    if [ ! -f "$POSTGRES_DATA_DIR/PG_VERSION" ]; then
        log "PostgreSQL not initialized. Initializing..."
        sudo -u postgres "$INITDB_BIN" -D "$POSTGRES_DATA_DIR"

        # Inline config edits for remote access
        # (listen_addresses, host all all 0.0.0.0/0 md5)
        log "Configuring PostgreSQL for remote access..."
        su postgres -c "echo \"listen_addresses = '*'\" >> \"$POSTGRES_DATA_DIR/postgresql.conf\""
        su postgres -c "echo \"host all all 0.0.0.0/0 md5\" >> \"$POSTGRES_DATA_DIR/pg_hba.conf\""

        log "First-time startup for password setup..."
        sudo -u postgres "$PGCTL_BIN" -D "$POSTGRES_DATA_DIR" \
            start -l "$POSTGRES_LOG_DIR/$POSTGRES_LOGFILE_NAME"

        # Wait up to MAX_WAIT for first-time startup
        first_time_ok=false
        for i in $(seq 1 $MAX_WAIT); do
            if psql_check; then
                log "PostgreSQL (first-time) is up. Setting 'postgres' password..."
                su postgres -c "psql --host=$PG_HOST --port=$PG_PORT --username=postgres -c \"ALTER USER postgres WITH PASSWORD 'postgres';\""
                first_time_ok=true
                break
            fi
            sleep 1
        done

        if [ "$first_time_ok" = false ]; then
            log "ERROR: First-time startup did not become ready within $MAX_WAIT seconds."
            sudo -u postgres "$PGCTL_BIN" -D "$POSTGRES_DATA_DIR" stop &>/dev/null
            return 1
        fi

        # Stop after first-time init
        log "Stopping PostgreSQL after init..."
        sudo -u postgres "$PGCTL_BIN" -D "$POSTGRES_DATA_DIR" stop
        sleep 2  # ensure it's fully stopped

        log "Initialization done. Run 'services.sh start postgres' again for normal start."
        return 0
    fi

    # If already initialized, do a normal start
    # Check if it's already running
    if psql_check; then
        log "PostgreSQL is already running."
        return 0
    else
        log "Starting PostgreSQL (normal)..."
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
    fi
}

##############################################################################
# STOP
##############################################################################

stop_postgres() {
    # If not running, do nothing
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
        echo "Usage: $0 {start|stop} postgres"
        ;;
esac
