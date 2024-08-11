FROM redhat/ubi8:latest

LABEL maintainer="Red Hat, Inc."

# Install Node.js and developer tools
RUN dnf module enable nodejs:18 -y && \
    dnf install -y nodejs vim git wget

# Clean up
RUN rm -rf /var/log/* && \
    mkdir -p /var/log/rhsm

CMD ["/bin/bash"]
