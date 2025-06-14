# LocalCrag Backup Tool

A lightweight Docker-based tool for creating and managing backups of your database and MinIO storage.

## Setup

1. Copy the `config.template.yml` file to `config.yml`:
   ```bash
   cp config.template.yml config.yml
   ```

2. Update the config.yml file with your setup details.
3. Build the Docker image:
   ```bash
   docker build -t localcrag-backup-tool .
   ```

## Usage

To run the backup script, use the following command:

   ```bash
   docker run --rm -v $(pwd)/backups:/app/backups localcrag-backup-tool
   ```

The script will create a backup of your database and MinIO storage, storing the files in the configures backup
directory. It is recommended to run this script periodically (e.g. in cron), such as daily or weekly, to ensure you have
up-to-date backups.