#!/bin/bash
set -e

# Function to send error notification
send_error_notification() {
  ERROR_MESSAGE=$(<"$ERROR_LOG_FILE")
  echo "Sending error notification with the following message:"
  echo "$ERROR_MESSAGE"

  PIPENV_OUTPUT=$(pipenv run python3 send_error_email.py "$ERROR_MESSAGE" 2>&1)
  if [ $? -ne 0 ]; then
    echo "Failed to send error notification using send_error_email.py. Error details:"
    echo "$PIPENV_OUTPUT"
  fi
}

# Trap errors and call the notification function
ERROR_LOG_FILE=$(mktemp)
trap 'echo "An error occurred. Check the log for details."; send_error_notification' ERR

# Redirect all output to the error log file
exec 2>"$ERROR_LOG_FILE"

# Load configuration from YAML file
CONFIG_FILE="config.yml"
DB_HOST=$(yq '.db.host' "$CONFIG_FILE")
DB_PORT=$(yq '.db.port' "$CONFIG_FILE")
DB_USER=$(yq '.db.user' "$CONFIG_FILE")
DB_PASSWORD=$(yq '.db.password' "$CONFIG_FILE")
DB_NAME=$(yq '.db.name' "$CONFIG_FILE")
MINIO_HOST=$(yq '.minio.host' "$CONFIG_FILE")
MINIO_USER=$(yq '.minio.user' "$CONFIG_FILE")
MINIO_PASSWORD=$(yq '.minio.password' "$CONFIG_FILE")
MINIO_BUCKET=$(yq '.minio.bucket' "$CONFIG_FILE")
BACKUP_DIR=$(yq '.backup.dir' "$CONFIG_FILE")
BACKUP_KEEP=$(yq '.backup.keep' "$CONFIG_FILE")
STORAGE_TYPE=$(yq '.storage.type' "$CONFIG_FILE")
SFTP_HOST=$(yq '.sftp.host' "$CONFIG_FILE")
SFTP_USER=$(yq '.sftp.user' "$CONFIG_FILE")
SFTP_PASSWORD=$(yq '.sftp.password' "$CONFIG_FILE")
SFTP_DIR=$(yq '.sftp.dir' "$CONFIG_FILE")

# Timestamp and file paths
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
DB_BACKUP_FILE="$BACKUP_DIR/db_backup_$TIMESTAMP.sql"
MINIO_BACKUP_DIR="$BACKUP_DIR/minio_backup_$TIMESTAMP"
ZIP_FILE="$BACKUP_DIR/backup_$TIMESTAMP.zip"

# Ensure backup directory exists
mkdir -p "$BACKUP_DIR"

# Backup PostgreSQL database
export PGPASSWORD=$DB_PASSWORD
pg_dump -h $DB_HOST -p $DB_PORT -U $DB_USER $DB_NAME > "$DB_BACKUP_FILE"

# Backup MinIO files
mkdir -p "$MINIO_BACKUP_DIR"
mc alias set minio $MINIO_HOST $MINIO_USER $MINIO_PASSWORD
mc cp --recursive minio/$MINIO_BUCKET "$MINIO_BACKUP_DIR"

# Create zip archive
zip -r "$ZIP_FILE" "$DB_BACKUP_FILE" "$MINIO_BACKUP_DIR"

# Cleanup temporary files
rm -rf "$DB_BACKUP_FILE" "$MINIO_BACKUP_DIR"

# Handle storage type
if [[ "$STORAGE_TYPE" == "sftp" ]]; then
  # Upload backup to SFTP server
  echo "Uploading backup to SFTP server..."
  sshpass -p "$SFTP_PASSWORD" sftp -oStrictHostKeyChecking=no -oBatchMode=no -b - "$SFTP_USER@$SFTP_HOST" <<EOF
-mkdir $SFTP_DIR
put $ZIP_FILE $SFTP_DIR/
EOF

  # Retain only the specified number of backups on the SFTP server
  if [[ $BACKUP_KEEP -ne -1 ]]; then
    echo "Managing backups on SFTP server..."
    FILES=$(sshpass -p "$SFTP_PASSWORD" sftp -oStrictHostKeyChecking=no -oBatchMode=no -b - "$SFTP_USER@$SFTP_HOST" <<EOF
ls -1 $SFTP_DIR/
EOF
)

    # Skip the first line of the output (repeats the command in the sftp session)
    FILES=$(echo "$FILES" | tail -n +2)

    FILE_COUNT=$(echo "$FILES" | wc -l)
    if [[ $FILE_COUNT -gt $BACKUP_KEEP ]]; then
      DELETE_COUNT=$((FILE_COUNT - BACKUP_KEEP))
      DELETE_FILES=$(echo "$FILES" | head -n "$DELETE_COUNT")
      for FILE in $DELETE_FILES; do
        sshpass -p "$SFTP_PASSWORD" sftp -oStrictHostKeyChecking=no -oBatchMode=no -b - "$SFTP_USER@$SFTP_HOST" <<EOF
rm $FILE
EOF
      done
    fi
  fi

  # Delete all local backups
  echo "Deleting all local backups..."
  rm -f "$BACKUP_DIR"/backup_*.zip
else
  # Retain only the specified number of backups locally
  if [[ $BACKUP_KEEP -ne -1 ]]; then
    BACKUP_FILES=($(ls -t "$BACKUP_DIR"/backup_*.zip))
    if [[ ${#BACKUP_FILES[@]} -gt $BACKUP_KEEP ]]; then
      DELETE_FILES=("${BACKUP_FILES[@]:$BACKUP_KEEP}")
      for FILE in "${DELETE_FILES[@]}"; do
        rm -f "$FILE"
      done
    fi
  fi
fi

echo "Backup completed: $ZIP_FILE"