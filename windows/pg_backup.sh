#!/bin/bash

# Configuration
BACKUP_DIR="/path/to/backup/directory"
DATE=$(date +\%Y-\%m-\%d_\%H-\%M-\%S)
PG_DUMP="/usr/bin/pg_dump"
LOG_FILE="/path/to/backup_log.txt"
PG_USER="postgres"
PG_PASS="postgres"  # Same for all instances

# Define PostgreSQL instances (alias: host:port)
declare -A POSTGRES_INSTANCES
POSTGRES_INSTANCES=(
    ["local"]="localhost:5432"
    ["dev_server"]="192.168.1.100:5432"
)

# Export password (if using a password)
export PGPASSWORD="$PG_PASS"

# Create backup directory and log file if they don't exist
mkdir -p "$BACKUP_DIR"
touch "$LOG_FILE"

echo "Backup started: $DATE" >> "$LOG_FILE"

# Loop through each PostgreSQL instance
for instance in "${!POSTGRES_INSTANCES[@]}"; do
  IFS=':' read -r HOST PORT <<< "${POSTGRES_INSTANCES[$instance]}"
  
  echo "Connecting to instance: $instance ($HOST:$PORT)" >> "$LOG_FILE"
  
  # Check connection
  if ! psql -U "$PG_USER" -h "$HOST" -p "$PORT" -c "\q" 2>>"$LOG_FILE"; then
    echo "ERROR: Unable to connect to $instance ($HOST:$PORT)" >> "$LOG_FILE"
    continue
  fi
  
  # List databases
  databases=$(psql -U "$PG_USER" -h "$HOST" -p "$PORT" -t -c "SELECT datname FROM pg_database WHERE datistemplate = false;" 2>>"$LOG_FILE")
  
  if [[ -z "$databases" ]]; then
    echo "ERROR: No databases found on $instance ($HOST:$PORT)" >> "$LOG_FILE"
    continue
  fi
  
  # Back up each database
  for db in $databases; do
    INSTANCE_BACKUP_DIR="$BACKUP_DIR/$instance"
    mkdir -p "$INSTANCE_BACKUP_DIR"
    echo "Backing up database: $db on $instance" >> "$LOG_FILE"
    if ! $PG_DUMP -U "$PG_USER" -h "$HOST" -p "$PORT" -Fc "$db" > "$INSTANCE_BACKUP_DIR/$db-$DATE.dump" 2>>"$LOG_FILE"; then
      echo "ERROR: Failed to back up $db on $instance" >> "$LOG_FILE"
    fi
  done
done

# Optional: Remove old backups (older than 7 days)
find "$BACKUP_DIR" -type f -mtime +7 -name "*.dump" -exec rm -f {} \;

echo "Backup completed: $(date +\%Y-\%m-\%d_\%H-\%M-\%S)" >> "$LOG_FILE"