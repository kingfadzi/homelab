FROM almalinux:8

ENV LANG=en_US.UTF-8 \
    LC_ALL=en_US.UTF-8 \
    PYTHONUNBUFFERED=1

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
    && dnf clean all

# 2) Install PostgreSQL 13 from official repo (NO initdb here)
RUN dnf -y install \
        https://download.postgresql.org/pub/repos/yum/reporpms/EL-8-x86_64/pgdg-redhat-repo-latest.noarch.rpm \
    && dnf -qy module disable postgresql \
    && dnf -y install \
        postgresql13 \
        postgresql13-server \
        postgresql13-contrib \
    && dnf clean all

# 3) Configure PostgreSQL SAMPLE files for remote access
#    (When you eventually run initdb, these sample configs get copied into the data directory)
RUN sed -i "s/^#listen_addresses = 'localhost'/listen_addresses = '*'/" /usr/pgsql-13/share/postgresql.conf.sample && \
    echo "host all all 0.0.0.0/0 md5" >> /usr/pgsql-13/share/pg_hba.conf.sample

# 4) Install Redis (no custom config here, feel free to add sed lines if you need remote binding)
RUN dnf -y install \
        redis \
    && dnf clean all

# 5) Install Node.js 22 + Yarn from NodeSource
RUN curl -sL https://rpm.nodesource.com/setup_22.x | bash - && \
    dnf -y install nodejs && \
    npm install -g yarn && \
    node --version && npm --version && yarn --version

# 6) Install Python 3.11 (without pip), then bootstrap pip via ensurepip
RUN dnf -y install \
        python3.11 \
        python3.11-devel \
    && dnf clean all

RUN python3.11 -m ensurepip --upgrade && \
    python3.11 -m pip install --upgrade pip

RUN alternatives --install /usr/bin/python3 python3 /usr/bin/python3.11 1 && \
    ln -s /usr/local/bin/pip3 /usr/bin/pip3.11 && \
    alternatives --install /usr/bin/pip3 pip3 /usr/bin/pip3.11 1

# 7) Install Apache Superset
RUN pip3 install --upgrade setuptools wheel && \
    pip3 install apache-superset && \
    superset --version

# Expose PostgreSQL (5432), Redis (6379), and Superset (8088) ports
EXPOSE 5432 6379 8088

# Default command: shell (so services won't auto-start)
CMD ["/bin/bash"]
