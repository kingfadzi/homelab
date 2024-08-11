# Use the official Red Hat Universal Base Image (UBI) 8 as the base
FROM registry.access.redhat.com/ubi8/ubi:latest

LABEL maintainer="Your Name <your.email@example.com>"

  # Install required packages and dependencies
  RUN yum install -y \
  # Install PostgreSQL 13
  https://download.postgresql.org/pub/repos/yum/reporpms/EL-8-x86_64/pgdg-redhat-repo-latest.noarch.rpm \
  && dnf module disable postgresql -y \
  && dnf install -y postgresql13-server postgresql13 \
  # Install Node.js 18 and Yarn
  && dnf module enable nodejs:18 -y \
  && dnf install -y nodejs \
  && npm install -g yarn \
  # Install development tools
  && dnf groupinstall -y "Development Tools" \
  # Install Python 3.12 from source
  && dnf install -y gcc openssl-devel bzip2-devel libffi-devel zlib-devel wget make \
  && wget https://www.python.org/ftp/python/3.12.0/Python-3.12.0.tgz \
  && tar xzf Python-3.12.0.tgz \
  && cd Python-3.12.0 \
  && ./configure --enable-optimizations \
  && make altinstall \
  && cd .. \
  && rm -rf Python-3.12.0 Python-3.12.0.tgz \
  # Clean up
  && dnf clean all \
  && rm -rf /var/cache/yum

  # Initialize PostgreSQL Database
  RUN /usr/pgsql-13/bin/postgresql-13-setup initdb

  # Expose PostgreSQL port
  EXPOSE 5432

  # Set the default command to start PostgreSQL
  CMD ["postgres", "-D", "/var/lib/pgsql/13/data"]