FROM elara.butterflycluster.com/repository/prod-docker/affine:0.17.0-canary.3-fork

# Set the working directory
WORKDIR /AFFiNE

# Set environment variables
ENV REDIS_SERVER_HOST=192.168.1.88
ENV DATABASE_URL=postgres://affine:affine@192.168.1.88:5432/affine
# ENV AFFINE_SERVER_HOST={AFFINE_SERVER_HOST}

# Run the yarn command
RUN yarn workspace @affine/server prisma db push

# Clone the repository
RUN git clone https://github.com/kingfadzi/affinity.git /app

# Copy the node_modules folder from /AFFiNE to /app
RUN cp -r /AFFiNE/node_modules /app/node_modules

# Copy the necessary file within the container
RUN cp /AFFiNE/packages/backend/native/server-native.node /app/server-native.node

# Set the working directory to the cloned repository
WORKDIR /app

# Expose port 3010
EXPOSE 3010

# Command to run the application
# CMD ["node", "--import", "./scripts/register.js", "./dist/index.js"]
CMD ["sh", "-c", "node ./scripts/self-host-predeploy && node ./dist/index.js"]