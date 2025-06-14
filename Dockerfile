# Use a lightweight base image
FROM debian:bullseye-slim

# Install required tools
RUN apt-get update && apt-get install -y wget gnupg \
    && wget -qO - https://www.postgresql.org/media/keys/ACCC4CF8.asc | apt-key add - \
    && echo "deb http://apt.postgresql.org/pub/repos/apt bullseye-pgdg main" > /etc/apt/sources.list.d/pgdg.list \
    && apt-get update \
    && apt-get install -y \
        postgresql-client-17 \
        zip \
        curl \
        jq \
    && curl -sL https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64 -o /usr/bin/yq \
    && chmod +x /usr/bin/yq \
    && curl -sL https://dl.min.io/client/mc/release/linux-amd64/mc -o /usr/bin/mc \
    && chmod +x /usr/bin/mc \
    && apt-get clean

# Set working directory
WORKDIR /app

# Copy the backup script and configuration files
COPY backup.sh config.yml /app/

# Make the script executable
RUN chmod +x /app/backup.sh

# Default command
CMD ["/app/backup.sh"]