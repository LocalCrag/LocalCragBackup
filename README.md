# LocalCrag Backup Tool

A Docker-based tool for creating and managing backups of your LocalCrag database and MinIO storage.

## Setup

### Prepare backup tool config

1. Clone the repository:
   ```bash
   git clone https://github.com/LocalCrag/LocalCragBackup.git
   cd LocalCragBackup
   ```

2. Copy the `config.template.yml` file to `config.yml`:
   ```bash
   cp config.template.yml config.yml
   ```

3. Update the config.yml file with your setup details
     - You can choose between storing backups locally or on an SFTP server.
     - Add an email configuration to receive notifications about backup errors

### Prepare LocalCrag deployment

For the backup tool to be able to access your deployments database and MinIO storage, 
you need to ensure that the database is accessible from the server where the backup tool is running. The MinIO storage 
should already be accessible via the endpoint that the LocalCrag deployment is using (normally smth like https://s3.your-domain.com).

#### Database Access

To make the database accessible, follow these steps:

1. Create a `pg_hba.conf` file in the root directory of your LocalCrag deployment with the following content:
   ```conf
   # Allow access from the backup tool's IP address
   host    all             backup             <BACKUP_TOOL_IP>/32            md5
   ```
   Replace `<BACKUP_TOOL_IP>` with the actual IP address of the server where the backup tool will run.
2. Create a `docker-compose.override.yml` file to open the database port of your LocalCrag deployment and mount the `pg_hba.conf` file to allow access from the backup tool's IP address. Also add the `POSTGRES_BACKUP_PASSWORD` environment variable to the server service. On server startup, the backup postgres user will be created using this password.
   ```yaml
   services:
     database:
       ports:
         - 5432:5432
       volumes:
         - database:/var/lib/postgresql/data/db-files # Needed in the override file as well as lists get replaced, not merged
         - ./pg_hba.conf:/var/lib/postgresql/data/pg_hba.conf
     server:
       environment:
         POSTGRES_BACKUP_PASSWORD: secure-password-for-backup-user
   ```
3. Restart your LocalCrag deployment to apply the changes:
   ```bash
   docker compose down
   docker compose up -d
   ```
4. Open the port in your firewall to allow access to the database from the backup tool's IP address. For example, if you are using `ufw`, you can run:
   ```bash
   sudo ufw allow from <BACKUP_TOOL_IP> to any port 5432
   ```

## Usage

To run the backup script, use the following command (expects to be run from the root directory of the LocalCragBackup repository, replace `$(pwd)` with the path to your LocalCragBackup directory if needed):

   ```bash
   docker run --rm -v $(pwd)/backups:/app/backups -v $(pwd)/config.yml:/app/config.yml ghcr.io/localcrag/localcrag-backup:latest
   ```

The script will create a backup of your database and MinIO storage, storing the files in the configures backup
directory. It is recommended to run this script periodically (e.g. in cron), such as daily or weekly, to ensure you have
up-to-date backups.

**Note:** The minio `mc` tool has a weird behaviour where it will fail with `mc: <ERROR> Unable to prepare URL for copying. Unable to guess the type of copy operation.` if the bucket is empty. If you get this error when setting up backups a fresh LocalCrag instance, you can work around it by e.g. setting a profile picture for your superadmin account.  