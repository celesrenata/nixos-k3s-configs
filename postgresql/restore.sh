#!/usr/bin/env bash

NFS_SERVER="192.168.42.8:/volume1/Kubernetes/postgresql"
BACKUP_DIR="/mnt/nfs-restore"
HOST="10.1.1.12"
PGPASSWORD="PSCh4ng3me!"

# Mount NFS
mkdir -p "$BACKUP_DIR"
sudo mount -t nfs "$NFS_SERVER" "$BACKUP_DIR"

# Find latest backups
LATEST_POSTGRESQL=$(ls -t "$BACKUP_DIR"/postgresql_*.sql | head -1)
LATEST_TESTDB=$(ls -t "$BACKUP_DIR"/testdb_*.sql | head -1)
LATEST_JELLYFIN=$(ls -t "$BACKUP_DIR"/clusterjellyfin_*.sql | head -1)

echo "Restoring from:"
echo "  PostgreSQL: $LATEST_POSTGRESQL"
echo "  TestDB: $LATEST_TESTDB"
echo "  Jellyfin: $LATEST_JELLYFIN"

# Wait for cluster to be ready
kubectl wait --for=condition=Ready cluster/postgresql -n postgresql-service --timeout=300s

export PGPASSWORD

# Restore databases
psql -h "$HOST" -U celes -d postgresql < "$LATEST_POSTGRESQL"
psql -h "$HOST" -U celes -d testdb < "$LATEST_TESTDB"
psql -h "$HOST" -U jellyfin -d clusterjellyfin < "$LATEST_JELLYFIN"

# Unmount NFS
sudo umount "$BACKUP_DIR"

echo "Restore complete!"
