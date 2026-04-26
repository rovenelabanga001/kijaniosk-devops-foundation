#!/usr/bin/env bash
# scripts/rollback.sh
# Rolls back to the previous environment by reading the .previous-env state file
# and calling switch-env.sh with that environment.
#
# Usage: bash rollback.sh
# No arguments required — reads state from /opt/kijanikiosk/.previous-env

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
STATE_DIR="/opt/kijanikiosk"
PREVIOUS_ENV_FILE="${STATE_DIR}/.previous-env"
ACTIVE_ENV_FILE="${STATE_DIR}/.active-env"

log() { echo "[$(date -u +%H:%M:%S)] $*"; }
log_fail() { echo "[$(date -u +%H:%M:%S)] [FAIL] $*" >&2; }

log "=== Rollback initiated ==="

# Read current and previous environments
CURRENT_ENV="unknown"
PREVIOUS_ENV="unknown"

[ -f "${ACTIVE_ENV_FILE}" ] && CURRENT_ENV=$(cat "${ACTIVE_ENV_FILE}")
[ -f "${PREVIOUS_ENV_FILE}" ] && PREVIOUS_ENV=$(cat "${PREVIOUS_ENV_FILE}")

log "Current environment:  ${CURRENT_ENV}"
log "Rolling back to:      ${PREVIOUS_ENV}"

# Validate previous env is known
case "${PREVIOUS_ENV}" in
  blue|green) ;;
  *)
    log_fail "No valid previous environment found in ${PREVIOUS_ENV_FILE}"
    log_fail "Cannot rollback automatically. Switch manually using switch-env.sh"
    exit 1
    ;;
esac

# Call switch-env.sh with the previous environment
log "Calling switch-env.sh ${PREVIOUS_ENV}..."
sh "${SCRIPT_DIR}/switch-env.sh" "${PREVIOUS_ENV}"

log "=== Rollback to ${PREVIOUS_ENV} complete ==="
exit 0