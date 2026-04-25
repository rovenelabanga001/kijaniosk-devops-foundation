#!/usr/bin/env bash
set -euo pipefail

APP_VERSION="${APP_VERSION:?APP_VERSION required}"
DEPLOY_ENV="${DEPLOY_ENV:?DEPLOY_ENV must be blue or green}"
ARTIFACT_BASE_URL="${ARTIFACT_BASE_URL:?ARTIFACT_BASE_URL required}"
NEXUS_USER="${NEXUS_USER:?NEXUS_USER required}"
NEXUS_PASS="${NEXUS_PASS:?NEXUS_PASS required}"
BLUE_PORT="${BLUE_PORT:-3000}"
GREEN_PORT="${GREEN_PORT:-3000}"

case "${DEPLOY_ENV}" in
  blue|green) ;;
  *) echo "ERROR: DEPLOY_ENV must be blue or green"; exit 1 ;;
esac

SCRIPT_START=$(date +%s)
log() { local e=$(( $(date +%s) - SCRIPT_START )); echo "[$(date -u +%H:%M:%S)] [+${e}s] $*"; }
log_fail() { echo "[$(date -u +%H:%M:%S)] [FAIL] $*" >&2; }

fetch_artifact() {
  log "=== Phase 1: Fetch artifact ==="
  local name="kijanikiosk-payments-${APP_VERSION}.tgz"
  local url="${ARTIFACT_BASE_URL}/kijanikiosk-payments/-/${name}"
  local dest="/opt/kijanikiosk/releases/${name}"
  mkdir -p /opt/kijanikiosk/releases
  if [ -f "${dest}" ]; then log "Already downloaded: ${dest}"; return 0; fi
  log "Fetching: ${url}"
  curl -fsSL --max-time 60 -u "${NEXUS_USER}:${NEXUS_PASS}" "${url}" -o "${dest}" || {
    log_fail "Phase 1 FAILED: Could not fetch ${url}"; exit 1
  }
  log "Fetched: ${dest}"
}

validate_artifact() {
  log "=== Phase 2: Validate artifact ==="
  local name="kijanikiosk-payments-${APP_VERSION}.tgz"
  local dest="/opt/kijanikiosk/releases/${name}"
  local staging="/opt/kijanikiosk/releases/staging-${APP_VERSION}"

  [ -s "${dest}" ] || { log_fail "Phase 2 FAILED: Artifact missing or empty"; exit 1; }

  rm -rf "${staging}"
  mkdir -p "${staging}"
  tar xzf "${dest}" -C "${staging}" || { log_fail "Phase 2 FAILED: Extraction failed"; exit 1; }

  # npm tarballs extract into staging/package/
  # Check for dist/index.js inside that
  local entry="${staging}/package/dist/index.js"
  [ -f "${entry}" ] || {
    log_fail "Phase 2 FAILED: dist/index.js not found. Contents:"
    find "${staging}" -type f | head -20
    exit 1
  }
  log "Artifact valid: dist/index.js found"
}

deploy_artifact() {
  log "=== Phase 3: Deploy to ${DEPLOY_ENV} environment ==="
  local target="/opt/kijanikiosk/${DEPLOY_ENV}/app"
  # npm extracts into staging/package/ - that is what we deploy
  local staging="/opt/kijanikiosk/releases/staging-${APP_VERSION}/package"
  local version_file="/opt/kijanikiosk/${DEPLOY_ENV}/.version"

  if [ -f "${version_file}" ] && [ "$(cat ${version_file})" = "${APP_VERSION}" ]; then
    log "Already deployed ${APP_VERSION} to ${DEPLOY_ENV}. Skipping."
    return 0
  fi

  mkdir -p "${target}_new"
  cp -r "${staging}/." "${target}_new/"
  rm -rf "${target}"
  mv "${target}_new" "${target}"
  echo "${APP_VERSION}" > "${version_file}"
  log "Deployed ${APP_VERSION} to ${target}"
}

restart_service() {
  log "=== Phase 4: Restart ${DEPLOY_ENV} service ==="
  local port="${BLUE_PORT}"
  [ "${DEPLOY_ENV}" = "green" ] && port="${GREEN_PORT}"
  local pid_file="/opt/kijanikiosk/${DEPLOY_ENV}/app.pid"
  local server_js="/opt/kijanikiosk/${DEPLOY_ENV}/app/dist/server.js"

  if [ -f "${pid_file}" ]; then
    local old_pid; old_pid=$(cat "${pid_file}")
    kill "${old_pid}" 2>/dev/null || true
    rm -f "${pid_file}"
    sleep 1
    log "Stopped previous process (PID ${old_pid})"
  fi

  APP_VERSION="${APP_VERSION}" PORT="${port}" node "${server_js}" &
  echo $! > "${pid_file}"
  sleep 2

  kill -0 "$(cat ${pid_file})" 2>/dev/null || {
    log_fail "Phase 4 FAILED: Service died immediately after start"
    exit 1
  }
  log "Service running (PID $(cat ${pid_file})) on port ${port}"
}

verify_service() {
  log "=== Phase 5: Verify ${DEPLOY_ENV} service health ==="
  local port="${BLUE_PORT}"
  [ "${DEPLOY_ENV}" = "green" ] && port="${GREEN_PORT}"
  local url="http://127.0.0.1:${port}/health"
  local retries=0

  while [ ${retries} -lt 10 ]; do
    response=$(curl -sf --max-time 5 "${url}" 2>/dev/null) && {
      echo "${response}" | grep -q "\"status\":\"ok\"" && {
        log "Health check passed: ${url}"
        log "Response: ${response}"
        return 0
      }
    }
    sleep 3
    retries=$((retries + 1))
  done

  log_fail "Phase 5 FAILED: Health check did not pass"
  log_fail "URL: ${url}"
  exit 1
}

main() {
  log "=== kijanikiosk-payments Deployment Script ==="
  log "Version:     ${APP_VERSION}"
  log "Environment: ${DEPLOY_ENV}"
  log "Artifact:    ${ARTIFACT_BASE_URL}/kijanikiosk-payments/-/kijanikiosk-payments-${APP_VERSION}.tgz"
  echo ""
  fetch_artifact
  validate_artifact
  deploy_artifact
  restart_service
  verify_service
  echo ""
  log "=== Deployment complete: kijanikiosk-payments ${APP_VERSION} on ${DEPLOY_ENV} ==="
  exit 0
}

main "$@"
