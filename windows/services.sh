#!/bin/bash

##############################################################################
# CONFIGURABLE VARIABLES
##############################################################################

LOG_FILE="/var/log/services.log"

POSTGRES_DATA_DIR="/var/lib/pgsql/13/data"
POSTGRES_LOG_DIR="/var/lib/logs"
POSTGRES_LOGFILE_NAME="postgres.log"

PGCTL_BIN="/usr/pgsql-13/bin/pg_ctl"
INITDB_BIN="/usr/pgsql-13/bin/initdb"
PG_HOST="localhost"
PG_PORT="5432"

MAX_WAIT=5  # Max seconds to wait for start/stop checks

##############################################################################
# LOGGING & HELPERS
##############################################################################

log() {
    echo "$(date +'%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

is_postgres_ready() {
    pg_isready -h "$PG_HOST" -p "$PG_PORT" &>/dev/null
}

##############################################################################
# START / STOP POSTGRES
##############################################################################

start_postgres() {
    # Ensure log dir
    if [ ! -d "$POSTGRES_LOG_DIR" ]; then
        mkdir -p "$POSTGRES_LOG_DIR"
        chown postgres:postgres "$POSTGRES_LOG_DIR"
    fi

    # If not initialized, do so + set password
    if [ ! -f "$POSTGRES_DATA_DIR/PG_VERSION" ]; then
        log "PostgreSQL not initialized. Initializing..."
        sudo -u postgres "$INITDB_BIN" -D "$POSTGRES_DATA_DIR"

        log "Starting PostgreSQL (first time)..."
        sudo -u postgres "$PGCTL_BIN" -D "$POSTGRES_DATA_DIR" \
            start -l "$POSTGRES_LOG_DIR/$POSTGRES_LOGFILE_NAME"

        # Optionally wait a moment so we can set the password
        for i in $(seq 1 $MAX_WAIT); do
            if is_postgres_ready; then
                log "PostgreSQL started (first time)."
                # Set default password
                log "Setting postgres user password to 'postgres'..."
                sudo -u postgres psql -c "ALTER USER postgres WITH PASSWORD 'postgres';"

                # Stop after init
                sudo -u postgres "$PGCTL_BIN" -D "$POSTGRES_DATA_DIR" stop
                log "Initialization done."
                break
            fi
            sleep 1
        done
    fi

    # Now start normally
    log "Starting PostgreSQL..."
    sudo -u postgres "$PGCTL_BIN" -D "$POSTGRES_DATA_DIR" \
        start -l "$POSTGRES_LOG_DIR/$POSTGRES_LOGFILE_NAME"

    # Short readiness check (non-blocking forever, but up to $MAX_WAIT seconds)
    for i in $(seq 1 $MAX_WAIT); do
        if is_postgres_ready; then
            log "PostgreSQL started successfully."
            return 0
        fi
        sleep 1
    done

    log "ERROR: PostgreSQL did not become ready within $MAX_WAIT seconds."
    return 1
}

stop_postgres() {
    log "Stopping PostgreSQL..."
    sudo -u postgres "$PGCTL_BIN" -D "$POSTGRES_DATA_DIR" stop

    # Short wait for it to go down
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
            postgres)
                start_postgres
                ;;
            *)
                echo "Usage: $0 start postgres"
                exit 1
                ;;
        esac
        ;;
    stop)
        case "$2" in
            postgres)
                stop_postgres
                ;;
            *)
                echo "Usage: $0 stop postgres"
                exit 1
                ;;
        esac
        ;;
    *)
        echo "Usage: $0 {start|stop} postgres"
        ;;
esac
