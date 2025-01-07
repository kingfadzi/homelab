#!/bin/bash

LOG_FILE="/path/to/logfile.log"

function log {
    echo "$(date +'%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
    echo "$1"
}

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

function start_postgres {
    if ! pg_isready -h /var/lib/pgsql/socket > /dev/null 2>&1; then
        log "Starting PostgreSQL..."
        sudo -u postgres pg_ctl -D /var/lib/pgsql/data start -l /var/lib/logs/logfile
        wait_for_postgres
        if ! pg_isready -h /var/lib/pgsql/socket > /dev/null 2>&1; then
            log "ERROR: Failed to start PostgreSQL."
            exit 1
        fi
        log "PostgreSQL started successfully."
    else
        log "PostgreSQL is already running."
    fi
}

function start_redis {
    if ! redis-cli ping > /dev/null 2>&1; then
        log "Starting Redis..."
        redis-server /etc/redis/redis.conf &
        wait_for_redis
        if ! redis-cli ping | grep -q PONG > /dev/null 2>&1; then
            log "ERROR: Failed to start Redis."
            exit 1
        fi
        log "Redis started successfully."
    else
        log "Redis is already running."
    fi
}

function start_affine {
    if ! ss -tnlp | grep ':3010' > /dev/null; then
        log "Starting AFFiNE..."
        cd /home/fadzi/tools/affinity-main
        nohup sh -c 'node ./scripts/self-host-predeploy && node --loader ./scripts/loader.js ./dist/index.js' > /home/fadzi/tools/affinity-main/logs/affine_log.log 2>&1 &
        sleep 5
        if ! ss -tnlp | grep ':3010' > /dev/null; then
            log "ERROR: Failed to start AFFiNE."
            exit 1
        fi
        log "AFFiNE started successfully."
    else
        log "AFFiNE is already running."
    fi
}

function start_metabase {
    if ! ss -tnlp | grep ':3000' > /dev/null; then
        log "Starting Metabase..."
        cd /home/fadzi/tools/metabase
        nohup java -jar metabase.jar > /home/fadzi/tools/metabase/logs/metabase_log.log 2>&1 &
        sleep 5
        if ! ss -tnlp | grep ':3000' > /dev/null; then
            log "ERROR: Failed to start Metabase."
            exit 1
        fi
        log "Metabase started successfully."
    else
        log "Metabase is already running."
    fi
}

function start_superset {
    if ! ss -tnlp | grep ':8099' > /dev/null; then
        log "Starting Apache Superset..."
        cd /home/fadzi/tools/superset
        source /home/fadzi/venv/bin/activate
        nohup superset run -p 8099 -h 0.0.0.0 --with-threads --reload --debugger > /home/fadzi/tools/superset/logs/superset_log.log 2>&1 &
        sleep 5
        if ! ss -tnlp | grep ':8099' > /dev/null; then
            log "ERROR: Failed to start Apache Superset."
            exit 1
        fi
        log "Apache Superset started successfully."
    else
        log "Apache Superset is already running."
    fi
}

function start_super_productivity {
    if ! ss -tnlp | grep ':8088' > /dev/null; then
        log "Starting Super Productivity..."
        cd /home/fadzi/tools/super-productivity-9.0.7/dist/browser
        nohup http-server -p 8088 > /home/fadzi/tools/super-productivity-9.0.7/dist/browser/logs/super_prod_log.log 2>&1 &
        sleep 5
        if ! ss -tnlp | grep ':8088' > /dev/null; then
            log "ERROR: Failed to start Super Productivity."
            exit 1
        fi
        log "Super Productivity started successfully."
    else
        log "Super Productivity is already running."
    fi
}

function stop_all {
    log "Stopping all services..."
    pkill -f http-server
    pkill -f superset
    pkill -f metabase.jar
    pkill -f 'node --loader ./scripts/loader.js ./dist/index.js'
    pkill redis-server
    sudo -u postgres pg_ctl -D /var/lib/pgsql/data stop
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
    log "All services started successfully."
}

function restart_all {
    log "Restarting all services..."
    stop_all
    start_all
}

# Main menu
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