#!/bin/bash

# Environment Configuration
export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8
export PYTHONUNBUFFERED=1
export SUPERSET_HOME="$HOME/tools/superset"
export SUPERSET_CONFIG_PATH="$SUPERSET_HOME/superset_config.py"
export METABASE_HOME="$HOME/tools/metabase"
export AFFINE_HOME="$HOME/tools/affinity-main"
export MINIO_BASE_URL="http://internal-minio:9000/your-bucket"
export POSTGRES_DATA_DIR="/var/lib/pgsql/13/data"
export INITDB_BIN="/usr/pgsql-13/bin/initdb"
export PGCTL_BIN="/usr/pgsql-13/bin/pg_ctl"
export PG_RESTORE_BIN="/usr/pgsql-13/bin/pg_restore"
export PG_MAX_WAIT=30
export PG_DATABASES=${PG_DATABASES:-"superset metabaseappdb affine"}

# Logging System
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# PostgreSQL Management Functions
ensure_permissions() {
    mkdir -p "$POSTGRES_DATA_DIR"
    chown postgres:postgres "$POSTGRES_DATA_DIR"
    chmod 700 "$POSTGRES_DATA_DIR"
}

psql_check() {
    sudo -u postgres psql -c "SELECT 1;" &>/dev/null
    return $?
}

restore_backup() {
    local db=$1
    local backup_file="${db}_backup.dump"
    local backup_path="/tmp/${backup_file}"
    
    log "Downloading ${db} backup from Minio..."
    if ! wget -q "${MINIO_BASE_URL}/${backup_file}" -O "$backup_path"; then
        log "No backup found for ${db}, skipping restore"
        return 0
    fi

    log "Restoring ${db} database..."
    if ! sudo -u postgres "$PG_RESTORE_BIN" -d "$db" "$backup_path"; then
        log "Error restoring ${db} database"
        return 1
    fi
    rm -f "$backup_path"
}

init_postgres() {
    ensure_permissions
    if [ -f "$POSTGRES_DATA_DIR/PG_VERSION" ]; then
        log "PostgreSQL already initialized"
        return 0
    fi

    log "Initializing PostgreSQL cluster..."
    sudo -u postgres "$INITDB_BIN" -D "$POSTGRES_DATA_DIR"

    log "Configuring network access..."
    sudo -u postgres sed -i "s/^#listen_addresses = 'localhost'/listen_addresses = '*'" "$POSTGRES_DATA_DIR/postgresql.conf"
    echo "host all all 0.0.0.0/0 md5" | sudo -u postgres tee -a "$POSTGRES_DATA_DIR/pg_hba.conf" >/dev/null

    log "Starting temporary PostgreSQL instance..."
    sudo -u postgres "$PGCTL_BIN" -D "$POSTGRES_DATA_DIR" start -l "$POSTGRES_DATA_DIR/postgres_init.log"

    local init_ok=false
    for i in $(seq 1 $PG_MAX_WAIT); do
        if psql_check; then
            log "Securing PostgreSQL user..."
            sudo -u postgres psql -c "ALTER USER postgres WITH PASSWORD 'postgres';"

            log "Creating databases..."
            for db in $PG_DATABASES; do
                if ! sudo -u postgres psql -tc "SELECT 1 FROM pg_database WHERE datname = '$db'" | grep -q 1; then
                    sudo -u postgres psql -c "CREATE DATABASE $db WITH OWNER postgres;"
                    log "Created database: $db"
                fi
                
                if ! restore_backup "$db"; then
                    return 1
                fi
            done

            init_ok=true
            break
        fi
        sleep 1
    done

    if [ "$init_ok" = false ]; then
        log "FATAL: PostgreSQL initialization failed"
        sudo -u postgres "$PGCTL_BIN" -D "$POSTGRES_DATA_DIR" stop &>/dev/null
        return 1
    fi

    log "Stopping initialization instance..."
    sudo -u postgres "$PGCTL_BIN" -D "$POSTGRES_DATA_DIR" stop
    sleep 2
}

# Root Check
if [ "$EUID" -ne 0 ]; then
    log "This script must be run as root (use sudo)"
    exit 1
fi

# Main Installation Process
log "Starting system provisioning..."

# 1. Package Installation
log "Installing system packages..."
dnf -y install \
    epel-release \
    wget \
    git \
    curl \
    gcc \
    gcc-c++ \
    make \
    zlib-devel \
    bzip2 \
    readline-devel \
    openssl-devel \
    libffi-devel \
    xz-devel \
    tar \
    java-21-openjdk \
    cronie \
    logrotate \
    sudo \
    iproute \
    postgresql13-server \
    postgresql13-contrib \
    redis \
    python3.11 \
    python3.11-devel \
    nodejs

# 2. PostgreSQL Setup
log "Configuring PostgreSQL..."
systemctl enable postgresql-13
if ! init_postgres; then
    exit 1
fi
systemctl start postgresql-13

# 3. Redis Configuration
log "Setting up Redis..."
sed -i "s/^# bind 127.0.0.1 ::1/bind 0.0.0.0/" /etc/redis.conf
sed -i "s/^protected-mode yes/protected-mode no/" /etc/redis.conf
systemctl enable redis
systemctl start redis

# 4. Node.js Environment
log "Configuring Node.js..."
npm install -g yarn

# 5. Python Setup
log "Setting up Python..."
python3.11 -m ensurepip --upgrade
python3.11 -m pip install --upgrade pip
alternatives --set python3 /usr/bin/python3.11
ln -sf /usr/bin/pip3.11 /usr/bin/pip3

# 6. Apache Superset Installation
log "Installing Apache Superset..."
pip3 install --upgrade setuptools wheel
pip3 install "apache-superset[postgres]==4.1.0rc3"

# 7. File Management
log "Creating application directories..."
mkdir -p "$SUPERSET_HOME" "$METABASE_HOME" "$AFFINE_HOME"

# 8. Configuration Downloads
log "Retrieving configurations from Minio..."
declare -A config_files=(
    ["our-logs.conf"]="/etc/logrotate.d/our-logs"
    ["backup_postgres.sh"]="/usr/local/bin/backup_postgres.sh"
    ["superset_config.py"]="$SUPERSET_CONFIG_PATH"
    ["services.sh"]="/usr/local/bin/services.sh"
    ["metabase.jar"]="$METABASE_HOME/metabase.jar"
    ["affine.tar.gz"]="$AFFINE_HOME/affine.tar.gz"
)

for file in "${!config_files[@]}"; do
    log "Downloading $file..."
    if ! wget -q "$MINIO_BASE_URL/$file" -O "${config_files[$file]}"; then
        log "ERROR: Failed to download $file"
        exit 1
    fi
done

# 9. Affine Setup
log "Deploying Affine..."
tar -xzf "$AFFINE_HOME/affine.tar.gz" -C "$AFFINE_HOME" --strip-components=1
rm -f "$AFFINE_HOME/affine.tar.gz"
chown -R $SUDO_USER:$SUDO_USER "$AFFINE_HOME"
find "$AFFINE_HOME" -type d -exec chmod 755 {} \;
find "$AFFINE_HOME" -type f -exec chmod 644 {} \;

# 10. Maintenance Configuration
log "Configuring maintenance jobs..."
chmod +x /usr/local/bin/backup_postgres.sh
chmod +x /usr/local/bin/services.sh
mkdir -p /var/lib/logs /var/log/redis /mnt/pgdb_backups

echo '0 2 * * * /usr/sbin/logrotate /etc/logrotate.conf' > /etc/cron.d/logrotate
echo '0 3 * * * /usr/local/bin/backup_postgres.sh' > /etc/cron.d/pgbackup

# Finalization
log "Provisioning complete!"
echo "=================================================="
echo "Service Summary:"
echo "- PostgreSQL: 5432 (Databases: $PG_DATABASES)"
echo "- Redis: 6379"
echo "- Superset: 8099"
echo "- Affine: $AFFINE_HOME"
echo "=================================================="
echo "Post-Installation Steps:"
echo "1. Initialize Superset:"
echo "   superset db upgrade && superset init"
echo "2. Start Metabase:"
echo "   java -jar $METABASE_HOME/metabase.jar"
echo "3. Verify backups:"
echo "   ls -l /mnt/pgdb_backups"