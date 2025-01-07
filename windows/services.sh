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

PG_HOST="localhost"
PG_PORT="5432"

MAX_WAIT=5  # max seconds to wait in readiness loops

##############################################################################
# LOGGING & UTILS
##############################################################################

log() {
    echo "$(date +'%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

is_postgres_ready() {
    pg_isready -h "$PG_HOST" -p "$PG_PORT" &>/dev/null
}

##############################################################################
# START POSTGRES
##############################################################################

start_postgres() {
    # Ensure /var/lib/logs exists
    if [ ! -d "$POSTGRES_LOG_DIR" ]; then
        mkdir -p "$POSTGRES_LOG_DIR"
        chown postgres:postgres "$POSTGRES_LOG_DIR"
    fi

    # If database is uninitialized
    if [ ! -f "$POSTGRES_DATA_DIR/PG_VERSION" ]; then
        log "PostgreSQL not initialized. Initializing..."
        sudo -u postgres "$INITDB_BIN" -D "$POSTGRES_DATA_DIR"

        log "First-time startup to set password..."
        sudo -u postgres "$PGCTL_BIN" -D "$POSTGRES_DATA_DIR" \
            start -l "$POSTGRES_LOG_DIR/$POSTGRES_LOGFILE_NAME"

        # Short wait for the initial start
        for i in $(seq 1 $MAX_WAIT); do
            if is_postgres_ready; then
                log "PostgreSQL (first-time) is up. Setting default password..."
                sudo -u postgres psql -c "ALTER USER postgres WITH PASSWORD 'postgres';"

                log "Stopping after init..."
                sudo -u postgres "$PGCTL_BIN" -D "$POSTGRES_DATA_DIR" stop
                sleep 2  # ensure it's fully stopped
                log "Initialization done. Run 'services.sh start postgres' again for normal start."
                return 0
            fi
            sleep 1
        done

        log "ERROR: First-time startup did not become ready within $MAX_WAIT seconds."
        # Attempt to stop if partial start
        sudo -u postgres "$PGCTL_BIN" -D "$POSTGRES_DATA_DIR" stop &>/dev/null
        return 1
    fi

    # Normal start if already initialized
    if is_postgres_ready; then
        log "PostgreSQL is already running."
        return 0
    else
        log "Starting PostgreSQL (normal)..."
        sudo -u postgres "$PGCTL_BIN" -D "$POSTGRES_DATA_DIR" \
            start -l "$POSTGRES_LOG_DIR/$POSTGRES_LOGFILE_NAME"

        # Short readiness check
        for i in $(seq 1 $MAX_WAIT); do
            if is_postgres_ready; then
                log "PostgreSQL started successfully."
                return 0
            fi
            sleep 1
        done

        log "ERROR: PostgreSQL did not become ready within $MAX_WAIT seconds."
        return 1
    fi
}

##############################################################################
# STOP POSTGRES
##############################################################################

stop_postgres() {
    # If not running, do nothing
    if ! is_postgres_ready; then
        log "PostgreSQL is not running."
        return 0
    fi

    log "Stopping PostgreSQL..."
    sudo -u postgres "$PGCTL_BIN" -D "$POSTGRES_DATA_DIR" stop

    # Short wait for graceful shutdown
    for i in $(seq 1 $MAX_WAIT); do
        if ! is_postgres_ready; then
            log "PostgreSQL stopped successfully."
            return 0
        fi
        sleep 1
    done

    log "ERROR: PostgreSQL did not stop within $MAX_WAIT seconds."
    return 1
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
