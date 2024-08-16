# Use the official Red Hat Universal Base Image (UBI) 8 as the base
FROM registry.access.redhat.com/ubi8/ubi:latest

# Install Git, Node.js 18, Yarn, and Rust
RUN yum install -y git curl gcc gcc-c++ glibc-devel make && \
    curl -fsSL https://rpm.nodesource.com/setup_18.x | bash - && \
    yum install -y nodejs && \
    npm install -g yarn && \
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y && \
    source $HOME/.cargo/env && \
    rustup update && \
    rustup default stable && \
    # Smoke test to ensure Cargo is installed correctly
    cargo --version && \
    rustc --version && \
    # Clean up
    yum clean all && \
    rm -rf /var/cache/yum nodesource_setup.sh

# Set the PATH environment variable for Cargo
ENV PATH="/root/.cargo/bin:${PATH}"

# Clone the AFFiNE repository and checkout the specific tag
RUN git clone https://github.com/toeverything/AFFiNE.git --branch stable && \
    cd AFFiNE && \
    git checkout tags/v0.17.0-canary.3

# List contents of the AFFiNE directory to confirm successful cloning
RUN echo "Listing contents of AFFiNE directory after clone:" && ls -l /AFFiNE

# Set the working directory to /AFFiNE
WORKDIR /AFFiNE

# Set environment variables
ENV REDIS_SERVER_HOST=192.168.1.88 \
    DATABASE_URL=postgres://affine:affine@192.168.1.88:5432/affine \
    BUILD_TYPE=stable

# Install dependencies
RUN echo "Installing dependencies..." && \
    yarn install && \
    echo "Dependencies installed."

# Build the server-native project
RUN echo "Building server-native project..." && \
    yarn build:server-native && \
    echo "Server-native project built."

# Build the @affine/server workspace
RUN echo "Building @affine/server workspace..." && \
    yarn workspace @affine/server build && \
    echo "@affine/server workspace built."

# Run postinstall for @affine/server workspace
RUN echo "Running postinstall for @affine/server workspace..." && \
    yarn workspace @affine/server postinstall && \
    echo "Postinstall for @affine/server completed."

# Run Prisma database push for @affine/server workspace
    RUN echo "Running Prisma database push for @affine/server workspace..." && \    
    yarn workspace @affine/server prisma db push && \    
    echo "Prisma database push completed."

#RUN echo "Running data migration for @affine/server workspace..." && \
#    yarn workspace @affine/server data-migration && \
#    echo "Data migration for @affine/server completed."

# Run predeploy for @affine/server workspace
RUN echo "Running predeploy for @affine/server workspace..." && \
    yarn workspace @affine/server predeploy && \
    echo "Predeploy for @affine/server completed."

# Clone the additional repository and copy static files
RUN echo "Cloning the additional repository..." && \
    git clone https://github.com/kingfadzi/affinity.git && \
    echo "Cloned additional repository." && \
    cd affinity && \
    cp -r ./static /AFFiNE && \
    echo "Copied static files to /AFFiNE."

# Command to run the application
CMD ["node", "--import", "./scripts/register.js", "./dist/index.js"]
