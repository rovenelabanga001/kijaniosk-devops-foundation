#!/usr/bin/env bash
# scripts/post-deploy-monitor.sh
#
# Monitors the active environment through the nginx proxy after a traffic switch.
# If health checks fail (with retries), triggers automated rollback via rollback.sh.
#
# Usage: sudo bash post-deploy-monitor.sh <confidence-window-seconds>
# Example: sudo bash post-deploy-monitor.sh 60
#
# The confidence window is how long the monitor must see consecutive healthy
# responses before declaring the deployment stable. If the health check fails
# MAX_RETRIES times in a row at any point during the window, rollback is triggered.

set -euo pipefail

# ── Configuration ─────────────────────────────────────────────────────────────
CONFIDENCE_WINDOW="${1:?Usage: bash post-deploy-monitor.sh <confidence-window-seconds>}"
PROXY_HEALTH_URL="http://127.0.0.1:80/health"
CHECK_INTERVAL=5          # seconds between each health check
MAX_RETRIES=3             # consecutive failures before rollback fires
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROLLBACK_SCRIPT="${SCRIPT_DIR}/rollback.sh"
STATE_DIR="/opt/kijanikiosk"
ACTIVE_ENV_FILE="${STATE_DIR}/.active-env"

# ── Logging ───────────────────────────────────────────────────────────────────
log() { echo "[$(date -u +%H:%M:%S)] $*"; }
log_fail() { echo "[$(date -u +%H:%M:%S)] [FAIL] $*" >&2; }
log_warn() { echo "[$(date -u +%H:%M:%S)] [WARN] $*"; }

# ── Sanity checks ─────────────────────────────────────────────────────────────
if [ ! -f "${ROLLBACK_SCRIPT}" ]; then
  log_fail "rollback.sh not found at ${ROLLBACK_SCRIPT}"
  log_fail "Cannot proceed without a rollback script. Exiting."
  exit 1
fi

# ── Read which environment is currently active ────────────────────────────────
MONITORED_ENV="unknown"
[ -f "${ACTIVE_ENV_FILE}" ] && MONITORED_ENV=$(cat "${ACTIVE_ENV_FILE}")

# ── Banner ────────────────────────────────────────────────────────────────────
echo ""
log "============================================================"
log "  post-deploy-monitor.sh started"
log "  Monitoring environment : ${MONITORED_ENV}"
log "  Proxy health URL       : ${PROXY_HEALTH_URL}"
log "  Confidence window      : ${CONFIDENCE_WINDOW}s"
log "  Check interval         : ${CHECK_INTERVAL}s"
log "  Max consecutive fails  : ${MAX_RETRIES} (then rollback)"
log "============================================================"
echo ""

# ── Monitor loop ──────────────────────────────────────────────────────────────
MONITOR_START=$(date +%s)
consecutive_failures=0
checks_passed=0
checks_total=0

while true; do
  NOW=$(date +%s)
  ELAPSED=$(( NOW - MONITOR_START ))

  # Check if confidence window has been reached
  if [ "${ELAPSED}" -ge "${CONFIDENCE_WINDOW}" ]; then
    echo ""
    log "============================================================"
    log "  CONFIDENCE WINDOW COMPLETE"
    log "  Duration  : ${ELAPSED}s"
    log "  Checks    : ${checks_passed}/${checks_total} passed"
    log "  Environment ${MONITORED_ENV} is STABLE. No rollback needed."
    log "============================================================"
    exit 0
  fi

  checks_total=$(( checks_total + 1 ))

  # Perform health check (with a short timeout so a hung service doesn't stall us)
  response=$(curl -sf --max-time 5 "${PROXY_HEALTH_URL}" 2>/dev/null) && \
    echo "${response}" | grep -q "\"status\":\"ok\"" && check_ok=true || check_ok=false

  if [ "${check_ok}" = "true" ]; then
    checks_passed=$(( checks_passed + 1 ))
    consecutive_failures=0
    log "CHECK PASSED [${ELAPSED}s/${CONFIDENCE_WINDOW}s] — proxy healthy. Response: ${response}"
  else
    consecutive_failures=$(( consecutive_failures + 1 ))
    log_warn "CHECK FAILED [${ELAPSED}s/${CONFIDENCE_WINDOW}s] — consecutive failures: ${consecutive_failures}/${MAX_RETRIES}"

    if [ "${consecutive_failures}" -ge "${MAX_RETRIES}" ]; then
      echo ""
      log "============================================================"
      log "  ROLLBACK THRESHOLD REACHED"
      log "  ${MAX_RETRIES} consecutive health check failures detected."
      log "  Triggering automated rollback..."
      log "  T1 (rollback trigger): $(date -u +%H:%M:%S)"
      log "============================================================"
      echo ""

      # Fire rollback — this calls switch-env.sh internally
      bash "${ROLLBACK_SCRIPT}" && rollback_ok=true || rollback_ok=false

      echo ""
      if [ "${rollback_ok}" = "true" ]; then
        # Confirm the proxy is now serving the previous environment
        sleep 2
        confirm_response=$(curl -sf --max-time 5 "${PROXY_HEALTH_URL}" 2>/dev/null) || confirm_response=""
        log "============================================================"
        log "  ROLLBACK COMPLETE"
        log "  T2 (rollback confirmed): $(date -u +%H:%M:%S)"
        log "  Proxy response: ${confirm_response}"
        NEW_ACTIVE="unknown"
        [ -f "${ACTIVE_ENV_FILE}" ] && NEW_ACTIVE=$(cat "${ACTIVE_ENV_FILE}")
        log "  Active environment is now: ${NEW_ACTIVE}"
        log "============================================================"
        exit 1   # exit non-zero: deployment was NOT stable
      else
        log_fail "============================================================"
        log_fail "  ROLLBACK FAILED — manual intervention required"
        log_fail "  Run: sudo bash ${SCRIPT_DIR}/switch-env.sh blue"
        log_fail "============================================================"
        exit 2
      fi
    fi
  fi

  sleep "${CHECK_INTERVAL}"
done