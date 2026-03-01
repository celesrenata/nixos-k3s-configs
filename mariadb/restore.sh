#!/usr/bin/env bash
set -euo pipefail

# --- defaults match your runmefirst + backup CR ---
NAMESPACE="${NAMESPACE:-mariadb-service}"
JOB_NAME="${JOB_NAME:-mariadb-restore}"
MARIADB_HOST="${MARIADB_HOST:-mariadb}"          # service name
MARIADB_PORT="${MARIADB_PORT:-3306}"
MARIADB_USER="${MARIADB_USER:-root}"

DB_SECRET_NAME="${DB_SECRET_NAME:-mariadb}"
DB_SECRET_KEY="${DB_SECRET_KEY:-root-password}"

NFS_SERVER="${NFS_SERVER:-192.168.42.8}"
NFS_PATH="${NFS_PATH:-/volume1/Kubernetes/mariadb/backup}"

# optional: relative to /backup (the NFS mount path inside the pod)
BACKUP_FILE="${BACKUP_FILE:-}"   # e.g. "backup-2026-02-28.sql.gz" or "subdir/backup.sql.gz"

SERVICE_ACCOUNT="${SERVICE_ACCOUNT:-backup}" # your Backup CR uses serviceAccountName: backup
IMAGE="${IMAGE:-bitnami/mariadb:11.4}"       # includes mariadb client + bash

echo "Namespace: ${NAMESPACE}"
echo "MariaDB svc: ${MARIADB_HOST}:${MARIADB_PORT}"
echo "NFS: ${NFS_SERVER}:${NFS_PATH}"

kubectl get ns "${NAMESPACE}" >/dev/null

# Ensure the service exists (helps avoid restoring before install finishes)
echo "Waiting for Service/${MARIADB_HOST} to exist..."
for i in {1..60}; do
  if kubectl -n "${NAMESPACE}" get svc "${MARIADB_HOST}" >/dev/null 2>&1; then
    break
  fi
  sleep 2
done
kubectl -n "${NAMESPACE}" get svc "${MARIADB_HOST}" >/dev/null

# Create/replace restore job
cat <<YAML | kubectl -n "${NAMESPACE}" apply -f -
apiVersion: batch/v1
kind: Job
metadata:
  name: ${JOB_NAME}
spec:
  backoffLimit: 0
  template:
    metadata:
      annotations:
        sidecar.istio.io/inject: "false"
    spec:
      restartPolicy: Never
      serviceAccountName: ${SERVICE_ACCOUNT}
      containers:
        - name: restore
          image: ${IMAGE}
          imagePullPolicy: IfNotPresent
          env:
            - name: MARIADB_PASSWORD
              valueFrom:
                secretKeyRef:
                  name: ${DB_SECRET_NAME}
                  key: ${DB_SECRET_KEY}
            - name: MARIADB_HOST
              value: ${MARIADB_HOST}
            - name: MARIADB_PORT
              value: "${MARIADB_PORT}"
            - name: MARIADB_USER
              value: ${MARIADB_USER}
            - name: BACKUP_FILE
              value: "${BACKUP_FILE}"
          volumeMounts:
            - name: backup
              mountPath: /backup
          command: ["/bin/bash","-lc"]
          args:
            - |
              set -euo pipefail

              echo "Waiting for MariaDB to accept connections..."
              for i in {1..120}; do
                if mariadb-admin ping \
                    -h "\${MARIADB_HOST}" -P "\${MARIADB_PORT}" \
                    -u "\${MARIADB_USER}" -p"\${MARIADB_PASSWORD}" --silent; then
                  echo "MariaDB is up."
                  break
                fi
                sleep 2
              done

              if ! mariadb-admin ping \
                    -h "\${MARIADB_HOST}" -P "\${MARIADB_PORT}" \
                    -u "\${MARIADB_USER}" -p"\${MARIADB_PASSWORD}" --silent; then
                echo "ERROR: MariaDB did not become ready in time."
                exit 1
              fi

              if [[ -n "\${BACKUP_FILE}" ]]; then
                FILE="/backup/\${BACKUP_FILE}"
              else
                # Pick the newest gzip'd SQL dump. Adjust if your naming differs.
                FILE="$(ls -1t /backup/**/*.sql.gz /backup/*.sql.gz 2>/dev/null | head -n1 || true)"
              fi

              if [[ -z "\${FILE}" || ! -f "\${FILE}" ]]; then
                echo "ERROR: Could not find backup file."
                echo "Set BACKUP_FILE to a path relative to /backup, or check NFS contents."
                echo "Listing /backup (first 200 files):"
                find /backup -type f | head -n 200 || true
                exit 1
              fi

              echo "Restoring from: \${FILE}"
              gzip -dc "\${FILE}" | mariadb \
                -h "\${MARIADB_HOST}" -P "\${MARIADB_PORT}" \
                -u "\${MARIADB_USER}" -p"\${MARIADB_PASSWORD}" \
                --binary-mode

              echo "Restore complete."
      volumes:
        - name: backup
          nfs:
            server: ${NFS_SERVER}
            path: ${NFS_PATH}
YAML

echo "Restore Job created: ${JOB_NAME}"
echo "Logs:"
echo "  kubectl -n ${NAMESPACE} logs -f job/${JOB_NAME}"
echo "Cleanup:"
echo "  kubectl -n ${NAMESPACE} delete job/${JOB_NAME}"
