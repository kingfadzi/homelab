# Use Alpine Linux as the base image for a lightweight container
FROM alpine:latest

# Install necessary dependencies
RUN apk --no-cache add curl tar

# Define the version of the OpenShift CLI
ENV OC_VERSION=4.6.0

# Download and install the OpenShift CLI
RUN curl -L "https://mirror.openshift.com/pub/openshift-v4/clients/ocp/${OC_VERSION}/openshift-client-linux-${OC_VERSION}.tar.gz" \
    | tar -xz -C /usr/local/bin/ oc

# Ensure oc is executable
RUN chmod +x /usr/local/bin/oc

# Set the working directory
WORKDIR /workspace

# Set the entrypoint to the shell
ENTRYPOINT ["/bin/sh"]
