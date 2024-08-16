# Use the official Red Hat Universal Base Image (UBI) 8 as the base
FROM registry.access.redhat.com/ubi8/ubi:latest

# Install Git, Node.js 18, Yarn, and Rust
RUN yum install -y git curl && \
    curl -fsSL https://rpm.nodesource.com/setup_18.x | bash - && \
    yum install -y nodejs && \
    npm install -g yarn && \
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y && \
    source $HOME/.cargo/env && \
    rustup update && \
    rustup default stable && \
    yum clean all && \
    rm -rf /var/cache/yum nodesource_setup.sh

# Clone the AFFiNE repository and checkout the specific tag
RUN git clone https://github.com/toeverything/AFFiNE.git --branch stable && \
    cd AFFiNE && \
    git checkout tags/v0.17.0-canary.3

# List contents of the AFFiNE directory to confirm successful cloning
RUN echo "Listing contents of AFFiNE directory after clone:" && ls -l /AFFiNE

# Set the working directory to /AFFiNE
WORKDIR /AFFiNE

# Install dependencies and build the project using workspaces
RUN yarn install && \
    yarn build:server-native && \
    yarn workspace @affine/server build && \
    yarn workspace @affine/server postinstall && \
    yarn workspace @affine/server data-migration && \
    yarn workspace @affine/server predeploy

# Set environment variables
ENV REDIS_SERVER_HOST=192.168.1.2 \
    DATABASE_URL=postgres://affine:affine@192.168.1.2:5432/affine \
    BUILD_TYPE=stable

# Command to run the application
CMD ["node", "--import", "./scripts/register.js", "./dist/index.js"]
