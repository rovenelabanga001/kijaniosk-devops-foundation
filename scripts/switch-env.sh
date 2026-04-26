#!/usr/bin/env bash
# scripts/switch-env.sh
# Switches nginx traffic between blue and green environments.
#
# Usage: bash switch-env.sh <target-environment>
# Example: bash switch-env.sh green
#
# Required environment variables (or defaults used):
#   BLUE_PORT  - Port the blue service listens on (default: 3000)
#   GREEN_PORT - Port the green service listens on (default: 3000)
#   BLUE_HOST  - Host for blue service (default: 172.19.0.4)
#   GREEN_HOST - Host for green service (default: 172.19.0.3)
#
# State files:
#   /opt/kijanikiosk/.active-env   - currently active environment
#   /opt/kijanikiosk/.previous-env - previously active environment

set -euo pipefail

# ── Configuration ─────────────────────────────────────────────────────────────
TARGET_ENV="${1:?Usage: switch-env.sh <blue|green>}"
BLUE_HOST="${BLUE_HOST:-172.19.0.4}"
GREEN_HOST="${GREEN_HOST:-172.19.0.3}"
BLUE_PORT="${BLUE_PORT:-3000}"
GREEN_PORT="${GREEN_PORT:-3000}"
NGINX_ACTIVE_ENV="/etc/nginx/kijanikiosk-active-env.conf"
STATE_DIR="/opt/kijanikiosk"
ACTIVE_ENV_FILE="${STATE_DIR}/.active-env"
PREVIOUS_ENV_FILE="${STATE_DIR}/.previous-env"

# Validate target
case "${TARGET_ENV}" in
  blue|green) ;;
  *) echo "ERROR: target must be 'blue' or 'green', got '${TARGET_ENV}'"; exit 1 ;;
esac

# ── Logging ───────────────────────────────────────────────────────────────────
SCRIPT_START=$(date +%s)
log() { local e=$(( $(date +%s) - SCRIPT_START )); echo "[$(date -u +%H:%M:%S)] [+${e}s] $*"; }
log_fail() { echo "[$(date -u +%H:%M:%S)] [FAIL] $*" >&2; }

# ── Helpers ───────────────────────────────────────────────────────────────────
get_active_env() {
  if [ -f "${ACTIVE_ENV_FILE}" ]; then
    cat "${ACTIVE_ENV_FILE}"
  elif grep -q "kk-api-blue" "${NGINX_ACTIVE_ENV}" 2>/dev/null; then
    echo "blue"
  elif grep -q "kk-api-green" "${NGINX_ACTIVE_ENV}" 2>/dev/null; then
    echo "green"
  else
    echo "unknown"
  fi
}

# ── Main ──────────────────────────────────────────────────────────────────────
CURRENT_ENV=$(get_active_env)

log "Current environment: ${CURRENT_ENV}"
log "Target environment:  ${TARGET_ENV}"

if [ "${CURRENT_ENV}" = "${TARGET_ENV}" ]; then
  log "Already on ${TARGET_ENV}. Nothing to do."
  exit 0
fi

# Determine target host and port
if [ "${TARGET_ENV}" = "blue" ]; then
  TARGET_HOST="${BLUE_HOST}"
  TARGET_PORT="${BLUE_PORT}"
else
  TARGET_HOST="${GREEN_HOST}"
  TARGET_PORT="${GREEN_PORT}"
fi

# Step 1: Verify target is healthy before touching nginx
log "Step 1: Verifying ${TARGET_ENV} is healthy on port ${TARGET_PORT}..."
response=$(curl -sf --max-time 5 "http://${TARGET_HOST}:${TARGET_PORT}/health" 2>/dev/null) || {
  log_fail "Pre-switch health check FAILED: ${TARGET_ENV} (port ${TARGET_PORT}) is not responding"
  log_fail "Refusing to switch. Run the deployment script first."
  exit 1
}
echo "${response}" | grep -q "\"status\":\"ok\"" || {
  log_fail "Pre-switch health check FAILED: ${TARGET_ENV} responded but status is not ok"
  log_fail "Response: ${response}"
  exit 1
}
log "Pre-switch health check passed: ${TARGET_ENV} is healthy"

# Step 2: Write new nginx active-env configuration
log "Step 2: Writing new nginx active-env configuration..."
mkdir -p "${STATE_DIR}"
cat > "${NGINX_ACTIVE_ENV}" << EOF
location / {
    proxy_pass         http://kk-api-${TARGET_ENV};
    proxy_http_version 1.1;
    proxy_set_header   Host \$host;
    proxy_cache_bypass \$http_upgrade;
}

location /health {
    proxy_pass http://kk-api-${TARGET_ENV};
}
EOF
log "Written: ${NGINX_ACTIVE_ENV}"

# Step 3: Validate nginx configuration
log "Step 3: Validating nginx configuration..."
nginx -t 2>&1 || {
  log_fail "nginx configuration validation FAILED"
  log_fail "Restoring previous configuration..."
  # Restore previous config pointing to current env
  cat > "${NGINX_ACTIVE_ENV}" << EOF
location / {
    proxy_pass         http://kk-api-${CURRENT_ENV};
    proxy_http_version 1.1;
    proxy_set_header   Host \$host;
    proxy_cache_bypass \$http_upgrade;
}

location /health {
    proxy_pass http://kk-api-${CURRENT_ENV};
}
EOF
  exit 1
}
log "nginx configuration is valid"

# Step 4: Reload nginx
log "Step 4: Reloading nginx..."
nginx -s reload
log "nginx reloaded. Traffic now routing to ${TARGET_ENV}."

# Step 5: Confirm switch via health check through nginx proxy
log "Step 5: Confirming switch via proxy health check..."
sleep 1
retries=0
while [ ${retries} -lt 5 ]; do
  proxy_response=$(curl -sf --max-time 5 "http://127.0.0.1:80/health" 2>/dev/null) && {
    echo "${proxy_response}" | grep -q "\"status\":\"ok\"" && {
      log "Post-switch confirmation passed: proxy is routing to ${TARGET_ENV}"
      log "Response: ${proxy_response}"
      break
    }
  }
  sleep 2
  retries=$((retries + 1))
done

if [ ${retries} -eq 5 ]; then
  log_fail "Post-switch health check FAILED: proxy not responding correctly after switch"
  exit 1
fi

# Update state files
echo "${TARGET_ENV}" > "${ACTIVE_ENV_FILE}"
echo "${CURRENT_ENV}" > "${PREVIOUS_ENV_FILE}"
log "State files updated: active=${TARGET_ENV}, previous=${CURRENT_ENV}"

echo ""
log "=== Switch to ${TARGET_ENV} complete ==="
exit 0