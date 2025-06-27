FROM python:3.11-slim

# Set working directory
WORKDIR /app

# Copy the backup script and configuration files
COPY backup.sh config.yml send_error_email.py Pipfile Pipfile.lock /app/

# Install Pipenv and dependencies
RUN pip install --no-cache-dir pipenv
RUN pipenv install --deploy --ignore-pipfile

# Make the script executable
RUN chmod +x /app/backup.sh

# Default command
CMD ["/app/backup.sh"]