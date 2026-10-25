#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────
# CloudMart DevOps Project - RDS Backup Script
# Dumps PostgreSQL databases, encrypts with KMS, uploads to S3
# ─────────────────────────────────────────────────────────────
set -euo pipefail

# ─── Configuration (override via environment) ───────────────
AWS_REGION="${AWS_REGION:-us-east-1}"
S3_BUCKET="${S3_BUCKET:-cloudmart-dev-backups-YOUR_ACCOUNT_ID}"
KMS_KEY_ID="${KMS_KEY_ID:-alias/cloudmart-dev-rds-kms}"
RETENTION_DAYS="${RETENTION_DAYS:-30}"

PRODUCTS_HOST="${PRODUCTS_HOST:-}"
PRODUCTS_PORT="${PRODUCTS_PORT:-5432}"
PRODUCTS_DB="${PRODUCTS_DB:-products}"
PRODUCTS_USER="${PRODUCTS_USER:-cloudmart}"
PRODUCTS_PASSWORD="${PRODUCTS_PASSWORD:-}"

ORDERS_HOST="${ORDERS_HOST:-}"
ORDERS_PORT="${ORDERS_PORT:-5432}"
ORDERS_DB="${ORDERS_DB:-orders}"
ORDERS_USER="${ORDERS_USER:-cloudmart}"
ORDERS_PASSWORD="${ORDERS_PASSWORD:-}"

BACKUP_DATE=$(date +%Y%m%d-%H%M%S)
BACKUP_DIR="/tmp/cloudmart-backup-${BACKUP_DATE}"

# ─── Prerequisites ──────────────────────────────────────────
command -v pg_dump >/dev/null 2>&1 || { echo "ERROR: pg_dump not found"; exit 1; }
command -v aws >/dev/null 2>&1 || { echo "ERROR: aws CLI not found"; exit 1; }
command -v gpg >/dev/null 2>&1 || { echo "ERROR: gpg not found"; exit 1; }

mkdir -p "${BACKUP_DIR}"
echo "[INFO] Backup started at $(date)"

# ─── Helper: dump with .pgpass ─────────────────────────────
dump_db() {
    local host="$1" port="$2" db="$3" user="$4" password="$5" label="$6"
    if [[ -z "${host}" ]]; then
        echo "[WARN] ${label}_HOST not set - skipping ${label} backup"
        return
    fi
    echo "[INFO] Dumping ${label} database..."
    local passfile
    passfile=$(mktemp)
    echo "${host}:${port}:${db}:${user}:${password}" > "${passfile}"
    chmod 600 "${passfile}"
    PGPASSFILE="${passfile}" pg_dump \
        -h "${host}" \
        -p "${port}" \
        -U "${user}" \
        -d "${db}" \
        -F c \
        -f "${BACKUP_DIR}/${label}-${BACKUP_DATE}.dump"
    rm -f "${passfile}"
    gzip "${BACKUP_DIR}/${label}-${BACKUP_DATE}.dump"
    echo "[OK] ${label} dump: ${BACKUP_DIR}/${label}-${BACKUP_DATE}.dump.gz"
}

dump_db "${PRODUCTS_HOST}" "${PRODUCTS_PORT}" "${PRODUCTS_DB}" \
        "${PRODUCTS_USER}" "${PRODUCTS_PASSWORD}" "products"

dump_db "${ORDERS_HOST}" "${ORDERS_PORT}" "${ORDERS_DB}" \
        "${ORDERS_USER}" "${ORDERS_PASSWORD}" "orders"

# ─── Encrypt with KMS ───────────────────────────────────────
echo "[INFO] Encrypting backups with KMS..."
for f in "${BACKUP_DIR}"/*.dump.gz; do
    if [[ -f "${f}" ]]; then
        aws kms encrypt \
            --region "${AWS_REGION}" \
            --key-id "${KMS_KEY_ID}" \
            --plaintext "fileb://${f}" \
            --output text \
            --query CiphertextBlob \
        > "${f}.encrypted"
        rm -f "${f}"
        echo "[OK] Encrypted: $(basename "${f}").encrypted"
    fi
done

# ─── Upload to S3 ───────────────────────────────────────────
echo "[INFO] Uploading to s3://${S3_BUCKET}/rds-backups/"
aws s3 sync \
    "${BACKUP_DIR}" \
    "s3://${S3_BUCKET}/rds-backups/${BACKUP_DATE}/" \
    --region "${AWS_REGION}" \
    --sse aws:kms \
    --ssekms-key-id "${KMS_KEY_ID}"

echo "[OK] Upload complete"

# ─── Apply Retention ────────────────────────────────────────
echo "[INFO] Applying ${RETENTION_DAYS}-day retention policy..."
CUTOFF=$(date -d "-${RETENTION_DAYS} days" +%Y%m%d)
aws s3 ls "s3://${S3_BUCKET}/rds-backups/" --region "${AWS_REGION}" | while IFS= read -r line; do
    DATE_PART=$(echo "${line}" | awk '{print $1}' | tr -d '/')
    if [[ "${DATE_PART}" < "${CUTOFF}" ]]; then
        PREFIX=$(echo "${line}" | awk '{print $2}')
        echo "[CLEANUP] Removing rds-backups/${PREFIX}"
        aws s3 rm "s3://${S3_BUCKET}/rds-backups/${PREFIX}" --recursive --region "${AWS_REGION}"
    fi
done

# ─── Cleanup ────────────────────────────────────────────────
rm -rf "${BACKUP_DIR}"
echo "[OK] Backup completed successfully at $(date)"
