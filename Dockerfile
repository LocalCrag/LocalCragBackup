FROM ubuntu:22.04

# Set environment variable to suppress interactive prompts
ENV DEBIAN_FRONTEND=noninteractive

# Set working directory
WORKDIR /app

# Install required dependencies, Python 3.13, and PostgreSQL 17
RUN apt-get update && apt-get install -y \
    software-properties-common wget gnupg curl \
    && add-apt-repository ppa:deadsnakes/ppa \
    && apt-get update && apt-get install -y \
    python3.13 \
    && curl -sS https://bootstrap.pypa.io/get-pip.py | python3.13 \
    && python3.13 -m pip install --no-cache-dir setuptools \
    && wget -qO - https://www.postgresql.org/media/keys/ACCC4CF8.asc | apt-key add - \
    && echo "deb http://apt.postgresql.org/pub/repos/apt/ jammy-pgdg main" > /etc/apt/sources.list.d/pgdg.list \
    && apt-get update && apt-get install -y \
    postgresql-17 \
    && apt-get clean && rm -rf /var/lib/apt/lists/* \
    && wget -qO /usr/bin/yq https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64 \
    && chmod +x /usr/bin/yq \
    && wget -qO /usr/bin/mc https://dl.min.io/client/mc/release/linux-amd64/mc \
    && chmod +x /usr/bin/mc

# Install Pipenv
RUN pip3 install --no-cache-dir pipenv

# Copy the backup script and configuration files
COPY backup.sh config.yml send_error_email.py Pipfile Pipfile.lock /app/

# Install dependencies using Pipenv
RUN pipenv install --deploy --ignore-pipfile

# Make the script executable
RUN chmod +x /app/backup.sh

# Default command
CMD ["/app/backup.sh"]