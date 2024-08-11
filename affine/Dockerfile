# Use the official Red Hat Universal Base Image (UBI) 8 as the base
FROM registry.access.redhat.com/ubi8/ubi:latest

LABEL maintainer="Your Name <your.email@example.com>"

  # Install required packages and dependencies
  RUN yum install -y \
  # Install PostgreSQL repository
  https://download.postgresql.org/pub/repos/yum/reporpms/EL-8-x86_64/pgdg-redhat-repo-latest.noarch.rpm && \
  # Install PostgreSQL 13 directly without disabling modules
  dnf install -y postgresql13-server postgresql13 && \
  # Install Node.js 18 and Yarn
  dnf module enable -y nodejs:18 && \
  dnf install -y nodejs && \
  npm install -g yarn && \
  # Install essential development tools manually (as the group wasn't found)
  dnf install -y gcc automake autoconf gcc-c++ openssl-devel bzip2-devel libffi-devel zlib-devel wget && \
  # Install Python 3.12 from a third-party repository
  dnf install -y python3.12 && \
  # Install networking tools and utilities (without telnet)
  dnf install -y bind-utils wget curl iproute iputils net-tools && \
  # Manually create PostgreSQL data directory and initialize the database
  mkdir -p /var/lib/pgsql/13/data && \
  chown -R postgres:postgres /var/lib/pgsql/13/data && \
  su - postgres -c "/usr/pgsql-13/bin/initdb -D /var/lib/pgsql/13/data" && \
  # Clean up
  dnf clean all && \
  rm -rf /var/cache/yum

  # Expose PostgreSQL port
  EXPOSE 5432

  # Set the default command to start PostgreSQL
  CMD ["su", "-", "postgres", "-c", "/usr/pgsql-13/bin/postgres -D /var/lib/pgsql/13/data"]