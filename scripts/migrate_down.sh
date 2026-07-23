#! /usr/bin/env bash

set -euo pipefail

ENV_FILE="${ENV_FILE:-.env}"
if [[ -f "$ENV_FILE" ]]; then
    export $(grep -v '^#' "$ENV_FILE" | xargs -d '\n')
else
    echo "Warning: $ENV_FILE file not found. Proceeding without it."
    exit 1
fi

#-----Required variables-----
PGHOST="${PGHOST:-127.0.0.1}"
PGPORT="${PGPORT:-5432}"
PGUSER="${PGUSER:-admin}"
PGPASSWORD="${PGPASSWORD:-admin}"
PGDATABASE="${PGDATABASE:-ulinzimesh}"

LOG_PREFIX="[migrate_down.sh]"

#----Drop the database-----
echo "$LOG_PREFIX Dropping database '$PGDATABASE' if it exists..."
psql "host=$PGHOST port=$PGPORT user=$PGUSER password=$PGPASSWORD dbname=postgres sslmode=disable" \
    -c "DROP DATABASE IF EXISTS \"$PGDATABASE\" WITH (FORCE);"

echo "$LOG_PREFIX Database '$PGDATABASE' dropped successfully."