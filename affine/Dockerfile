# Use the previously built base image
FROM elara.butterflycluster.com/repository/prod-docker/affine:0.17.0-canary.3-fork
WORKDIR /AFFiNE

# Set environment variables
ENV REDIS_SERVER_HOST=192.168.1.88
ENV DATABASE_URL=postgres://affine:affine@192.168.1.88:5432/affine
ENV AFFINE_SERVER_HOST={AFFINE_SERVER_HOST}

# Run the yarn command
RUN yarn workspace @affine/server prisma db push

# Set the working directory
WORKDIR /app

# Copy or move files within the container's filesystem
RUN cp -r /AFFiNE/packages/backend/server/* /app/ && \
    mkdir -p /app/static && \
    cp -r /AFFiNE/packages/frontend/web/dist/* /app/static/ && \
    mkdir -p /app/static/admin && \
    cp -r /AFFiNE/packages/frontend/admin/dist/* /app/static/admin/ && \
    cp /AFFiNE/packages/backend/native/server-native.node /app

# Expose port 3010
EXPOSE 3010

# Command to run the application
# CMD ["/bin/bash"]
CMD ["node", "--import", "./scripts/register.js", "./dist/index.js"]
