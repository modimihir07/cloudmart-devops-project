#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────
# CloudMart DevOps Project - Health Check Script
# Monitors CPU, memory, disk, and service endpoints
# ─────────────────────────────────────────────────────────────
set -euo pipefail

# ─── Configuration ──────────────────────────────────────────
NAMESPACE="${NAMESPACE:-cloudmart-dev}"
SERVICES=(
    "frontend:8080"
    "product-service:8000"
    "cart-service:8000"
    "order-service:8000"
)
THRESHOLD_CPU="${THRESHOLD_CPU:-80}"
THRESHOLD_MEM="${THRESHOLD_MEM:-80}"
THRESHOLD_DISK="${THRESHOLD_DISK:-80}"
ALERT_WEBHOOK="${ALERT_WEBHOOK:-}"

# ─── Colors ─────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
ok()   { echo -e "${GREEN}[OK]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
fail() { echo -e "${RED}[FAIL]${NC} $1"; }

RESULTS=()
STATUS=0

# ─── System Checks ──────────────────────────────────────────
check_system() {
    echo "━━━ System Health ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    # CPU
    CPU_USAGE=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d. -f1)
    if [[ -z "${CPU_USAGE}" ]]; then
        CPU_USAGE=$(awk '{u=$2+$4; t=$2+$4+$5; if (NR==1){u1=u; t1=t} else print ($2+$4-u1) * 100 / (t-t1) "%"; }' <(head -n1 /proc/stat) <(sleep 1; head -n1 /proc/stat) 2>/dev/null | cut -d. -f1 || echo "0")
    fi
    if [[ "${CPU_USAGE}" -gt "${THRESHOLD_CPU}" ]]; then
        warn "CPU: ${CPU_USAGE}% (threshold: ${THRESHOLD_CPU}%)"
        RESULTS+=("WARN:CPU:${CPU_USAGE}%")
    else
        ok "CPU: ${CPU_USAGE}%"
    fi

    # Memory
    MEM_TOTAL=$(free -m | awk '/^Mem:/{print $2}')
    MEM_USED=$(free -m | awk '/^Mem:/{print $3}')
    MEM_PCT=$(( MEM_USED * 100 / MEM_TOTAL ))
    if [[ "${MEM_PCT}" -gt "${THRESHOLD_MEM}" ]]; then
        warn "Memory: ${MEM_PCT}% (${MEM_USED}MB/${MEM_TOTAL}MB, threshold: ${THRESHOLD_MEM}%)"
        RESULTS+=("WARN:MEM:${MEM_PCT}%")
    else
        ok "Memory: ${MEM_PCT}% (${MEM_USED}MB/${MEM_TOTAL}MB)"
    fi

    # Disk
    DISK_PCT=$(df / | awk 'NR==2{print $5}' | tr -d '%')
    if [[ "${DISK_PCT}" -gt "${THRESHOLD_DISK}" ]]; then
        warn "Disk: ${DISK_PCT}% (threshold: ${THRESHOLD_DISK}%)"
        RESULTS+=("WARN:DISK:${DISK_PCT}%")
    else
        ok "Disk: ${DISK_PCT}%"
    fi
}

# ─── K8s Node Health ────────────────────────────────────────
check_k8s_nodes() {
    echo ""
    echo "━━━ Kubernetes Node Health ─━━━━━━━━━━━━━━━━━━━━━━"
    if ! command -v kubectl &>/dev/null; then
        warn "kubectl not found - skipping"
        return
    fi
    NODES=$(kubectl get nodes --no-headers 2>/dev/null | wc -l)
    NOT_READY=$(kubectl get nodes --no-headers 2>/dev/null | grep -v " Ready" | wc -l || true)
    ok "Nodes: ${NODES} total, ${NOT_READY} not ready"
    if [[ "${NOT_READY}" -gt 0 ]]; then
        RESULTS+=("WARN:NODES:${NOT_READY} not ready")
    fi
}

# ─── Service Endpoint Checks ────────────────────────────────
check_services() {
    echo ""
    echo "━━━ Service Endpoints ━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    for svc in "${SERVICES[@]}"; do
        NAME="${svc%%:*}"
        PORT="${svc##*:}"
        URL="http://${NAME}.${NAMESPACE}.svc.cluster.local:${PORT}/health"

        if command -v kubectl &>/dev/null; then
            POD=$(kubectl get pods -n "${NAMESPACE}" -l "app=${NAME}" --no-headers 2>/dev/null | head -1 | awk '{print $1}')
            if [[ -z "${POD}" ]]; then
                warn "${NAME}: no running pods found"
                RESULTS+=("FAIL:${NAME}:no pods")
                continue
            fi
            READY=$(kubectl get pod -n "${NAMESPACE}" "${POD}" -o jsonpath='{.status.containerStatuses[0].ready}' 2>/dev/null)
            if [[ "${READY}" != "true" ]]; then
                fail "${NAME}: pod ${POD} is not ready"
                RESULTS+=("FAIL:${NAME}:not ready")
                continue
            fi
            ok "${NAME}: pod ${POD} ready"
        else
            # Direct curl when kubectl not available
            if curl -sf --connect-timeout 5 "${URL}" >/dev/null 2>&1; then
                ok "${NAME}: ${URL}"
            else
                fail "${NAME}: ${URL} unreachable"
                RESULTS+=("FAIL:${NAME}:unreachable")
            fi
        fi
    done
}

# ─── Alert Webhook ──────────────────────────────────────────
send_alert() {
    local summary="$1"
    local message="$2"
    if [[ -n "${ALERT_WEBHOOK}" ]]; then
        curl -sf -X POST \
            -H "Content-Type: application/json" \
            -d "{\"summary\":\"${summary}\",\"message\":\"${message}\",\"source\":\"health-check.sh\"}" \
            "${ALERT_WEBHOOK}" >/dev/null 2>&1 || warn "Failed to send alert"
    fi
}

# ─── Main ───────────────────────────────────────────────────
main() {
    echo "CloudMart DevOps Project - Health Check"
    echo "Started: $(date)"
    echo ""

    check_system
    check_k8s_nodes
    check_services

    echo ""
    echo "━━━ Summary ─━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    FAIL_COUNT=$(echo "${RESULTS[@]}" | tr ' ' '\n' | grep -c "^FAIL" || true)
    WARN_COUNT=$(echo "${RESULTS[@]}" | tr ' ' '\n' | grep -c "^WARN" || true)

    if [[ "${FAIL_COUNT}" -gt 0 ]]; then
        echo -e "${RED}${FAIL_COUNT} failures, ${WARN_COUNT} warnings${NC}"
        send_alert "CloudMart Health Check: ${FAIL_COUNT} failures" "${RESULTS[*]}"
        STATUS=1
    elif [[ "${WARN_COUNT}" -gt 0 ]]; then
        echo -e "${YELLOW}0 failures, ${WARN_COUNT} warnings${NC}"
    else
        echo -e "${GREEN}All checks passed${NC}"
    fi

    echo ""
    echo "Completed: $(date)"
    exit "${STATUS}"
}

main
