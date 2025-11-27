#! /usr/bin/env bash

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

#--- Load environment variables from .env file if it exists
# This is now handled by dev_bootstrap.sh, so we remove the redundant block.


#-----Required variables-----
PGHOST="${PGHOST:-127.0.0.1}"
PGPORT="${PGPORT:-5432}"
PGUSER="${PGUSER:-admin}"
PGPASSWORD="${PGPASSWORD:-admin}"
PGDATABASE="${PGDATABASE:-ulinzimesh}"

#----Migration dir-----
MIGRATION_DIR="${MIGRATION_DIR:-$REPO_ROOT/db/migrations}"
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
set -x # Enable command tracing
for f in $(ls "$MIGRATION_DIR"/*.sql | sort); do
    echo "$LOG_PREFIX Applying migration: $f"
    psql "host=$PGHOST port=$PGPORT user=$PGUSER password=$PGPASSWORD dbname=$PGDATABASE sslmode=disable" \
    -f "$f"
done
set +x # Disable command tracing

echo "$LOG_PREFIX All migrations applied successfully."