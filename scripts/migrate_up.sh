#! /usr/bin/env bash

set -euo pipefail
ENV_FILE="${ENV_FILE:-.env}"
#--- Load environment variables from .env file if it exists
while IFS='=' read -r key value; do
  if [[ "$key" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]]; then
    export "$key=$value"
  fi
done < <(grep -v '^#' "$ENV_FILE" | grep '=')


#-----Required variables-----
PGHOST="${PGHOST:-127.0.0.1}"
PGPORT="${PGPORT:-5432}"
PGUSER="${PGUSER:-ulinzi}"
PGPASSWORD="${PGPASSWORD:-ulinzi}"
PGDATABASE="${PGDATABASE:-ulinzi}"

#----Migration dir-----
MIGRATION_DIR="${MIGRATION_DIR:-db/migrations}"
LOG_PREFIX="[migrate_up.sh]"

#----Create the database if it doesn't exist-----
echo "$LOG_PREFIX Checking if database '$PGDATABASE' exists..."
psql "host=$PGHOST port=$PGPORT user=$PGUSER password=$PGPASSWORD dbname=postgres sslmode=disable"\
    -tc "SELECT 1 FROM pg_database WHERE datname = '$PGDATABASE'" | grep -q 1 || {
    echo "$LOG_PREFIX Database '$PGDATABASE' does not exist. Creating..."
    createdb -h "$PGHOST" -p "$PGPORT" -U "$PGUSER" "$PGDATABASE"
}

#----Run migrations-----
echo "$LOG_PREFIX Running migrations in directory '$MIGRATION_DIR'..."
for f in $(ls "$MIGRATION_DIR"/*.sql | sort); do
    echo "$LOG_PREFIX Applying migration: $f"
    psql "host=$PGHOST port=$PGPORT user=$PGUSER password=$PGPASSWORD dbname=$PGDATABASE sslmode=disable" \
    -V ON_ERROR_STOP -f "$f"
done

echo "$LOG_PREFIX All migrations applied successfully."