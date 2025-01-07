FROM almalinux:8

ENV LANG=en_US.UTF-8 \
    LC_ALL=en_US.UTF-8 \
    PYTHONUNBUFFERED=1 \
    SUPERSET_HOME=/opt/superset \
    SUPERSET_CONFIG_PATH=/opt/superset/superset_config.py

# 1) Update and install base packages
RUN dnf -y update && \
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
        sudo \
        iproute \
    && dnf clean all

# 2) Install PostgreSQL 13 from the official repo (no initdb)
RUN dnf -y install \
        https://download.postgresql.org/pub/repos/yum/reporpms/EL-8-x86_64/pgdg-redhat-repo-latest.noarch.rpm \
    && dnf -qy module disable postgresql \
    && dnf -y install \
        postgresql13 \
        postgresql13-server \
        postgresql13-contrib \
    && dnf clean all

# 3) Configure PostgreSQL sample files for remote access
RUN sed -i "s/^#listen_addresses = 'localhost'/listen_addresses = '*'/" /usr/pgsql-13/share/postgresql.conf.sample && \
    echo "host all all 0.0.0.0/0 md5" >> /usr/pgsql-13/share/pg_hba.conf.sample

# 4) Install Redis (optionally configure for remote access with sed if you wish)
RUN dnf -y install \
        redis \
    && dnf clean all

# 5) Install Node.js 22 + Yarn from NodeSource
RUN curl -sL https://rpm.nodesource.com/setup_22.x | bash - && \
    dnf -y install nodejs && \
    npm install -g yarn && \
    node --version && npm --version && yarn --version

# 6) Install Python 3.11 (no pip), then bootstrap pip via ensurepip
RUN dnf -y install \
        python3.11 \
        python3.11-devel \
    && dnf clean all

RUN python3.11 -m ensurepip --upgrade && \
    python3.11 -m pip install --upgrade pip

RUN alternatives --install /usr/bin/python3 python3 /usr/bin/python3.11 1 && \
    ln -s /usr/local/bin/pip3 /usr/bin/pip3.11 && \
    alternatives --install /usr/bin/pip3 pip3 /usr/bin/pip3.11 1

# 7) Install a specific version of Apache Superset (4.1.0rc3) with Postgres extras
RUN pip3 install --upgrade setuptools wheel && \
    pip3 install "apache-superset[postgres]==4.1.0rc3"

# 8) Optionally create a directory for a custom superset_config.py
RUN mkdir -p "$SUPERSET_HOME"

# COPY superset_config.py if you have a local file. Example:
# COPY superset_config.py "$SUPERSET_HOME/superset_config.py"

# 9) Copy your manual services script into the container
#    We'll call it services.sh
COPY services.sh /usr/local/bin/services.sh
RUN chmod +x /usr/local/bin/services.sh

# Expose Postgres, Redis, and Superset ports
EXPOSE 5432 6379 8088

# Default command: do nothing (just give a shell)
CMD ["/bin/bash"]
