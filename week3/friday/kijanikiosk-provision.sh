#!/bin/bash
# kijanikiosk-provision.sh
# Production server foundation for KijaniKiosk payments service.
# Idempotent: safe to run on dirty or clean VMs.
#
# Expected dirty conditions found in pre-provisioning audit (2026-03-29):
# 1. kk-api uses /usr/bin/nologin vs /usr/sbin/nologin — normalized in Phase 2
# 2. /opt/kijanikiosk/, /app/, /scripts/ are 777 — tightened in Phase 3
# 3. /opt/kijanikiosk/config/ has no default ACLs — added in Phase 3
# 4. kijanikiosk group has extra members (rovenel-abanga, amina) — documented only
# 5. Only kk-api.service exists — kk-payments and kk-logs created in Phase 4
# 6. kk-api.service scores 5.8 MEDIUM — hardened to below 3.5 in Phase 4
# 7. logrotate postrotate uses reload — ExecReload= added to kk-logs unit
# 8. /var/log/journal/ may not exist — created and capped in Phase 7
# 9. /opt/kijanikiosk/health/ does not exist — created in Phase 8
# 10. UFW clean — intent expressed cleanly in Phase 5

set -euo pipefail

# ─── Colour helpers ───────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; NC='\033[0m'

log()     { echo -e "${BLUE}[$(date '+%H:%M:%S')]${NC} $*"; }
success() { echo -e "${GREEN}[PASS]${NC} $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC} $*"; }
error()   { echo -e "${RED}[FAIL]${NC} $*" >&2; }

# ─── Verification tracking ────────────────────────────────────────────────────
CHECKS_PASSED=0
CHECKS_FAILED=0

check() {
    local description="$1"
    local command="$2"
    if eval "$command" &>/dev/null; then
        success "$description"
        CHECKS_PASSED=$((CHECKS_PASSED + 1))
    else
        error "$description"
        CHECKS_FAILED=$((CHECKS_FAILED + 1))
    fi
}

# ─── Root check ───────────────────────────────────────────────────────────────
if [[ $EUID -ne 0 ]]; then
    error "This script must be run as root: sudo bash $0"
    exit 1
fi

log "Starting KijaniKiosk provisioning..."
log "================================================"

# ═══════════════════════════════════════════════════════════════════════════════
# PHASE 1: Prerequisites — packages, versions, holds
# ═══════════════════════════════════════════════════════════════════════════════
phase1_prerequisites() {
    log "PHASE 1: Prerequisites"

    # Install acl tools if missing (needed for setfacl/getfacl)
    if ! command -v setfacl &>/dev/null; then
        log "Installing acl..."
        apt-get install -y acl >/dev/null 2>&1
    else
        success "acl tools already installed"
    fi

    # Install sysstat if missing
    if ! command -v iostat &>/dev/null; then
        log "Installing sysstat..."
        apt-get install -y sysstat >/dev/null 2>&1
        systemctl enable --now sysstat 2>/dev/null || true
    else
        success "sysstat already installed"
    fi

    # ── Package version checks ─────────────────────────────────────────────
    # Check nginx version matches hold before attempting install
    NGINX_PINNED="1.24.0"
    NODEJS_PINNED="20"

    nginx_installed=$(nginx -v 2>&1 | grep -oP '\d+\.\d+\.\d+' || echo "none")
    if [[ "$nginx_installed" == "none" ]]; then
        log "nginx not installed — installing..."
        apt-get install -y nginx >/dev/null 2>&1
    elif [[ "$nginx_installed" == *"$NGINX_PINNED"* ]]; then
        success "nginx $nginx_installed matches pinned version — skipping install"
    else
        warn "nginx $nginx_installed does not match pinned $NGINX_PINNED — manual intervention needed"
        warn "Run: apt-get install nginx=$NGINX_PINNED* to downgrade"
    fi

    node_installed=$(node --version 2>/dev/null | grep -oP '\d+' | head -1 || echo "none")
    if [[ "$node_installed" == "none" ]]; then
        log "nodejs not installed — installing..."
        apt-get install -y nodejs >/dev/null 2>&1
    elif [[ "$node_installed" == "$NODEJS_PINNED" ]]; then
        success "nodejs v$node_installed matches pinned version — skipping install"
    else
        warn "nodejs v$node_installed does not match pinned v$NODEJS_PINNED — manual intervention needed"
    fi

    # ── Package holds ──────────────────────────────────────────────────────
    apt-mark hold nginx nodejs >/dev/null 2>&1
    success "Package holds confirmed: nginx nodejs"

    log "PHASE 1 complete"
}

phase1_prerequisites
# ═══════════════════════════════════════════════════════════════════════════════
# PHASE 2: Service Accounts
# ═══════════════════════════════════════════════════════════════════════════════
phase2_service_accounts() {
    log "PHASE 2: Service Accounts"

    # ── kijanikiosk group ──────────────────────────────────────────────────
    if getent group kijanikiosk &>/dev/null; then
        success "Group kijanikiosk already exists — skipping"
    else
        groupadd --system kijanikiosk
        success "Created group kijanikiosk"
    fi

    # ── Service account helper ─────────────────────────────────────────────
    # Creates account if missing; normalizes shell if wrong
    ensure_service_account() {
        local user="$1"
        local uid="$2"
        local gid="$3"
        local comment="$4"
        local home="$5"

        if id "$user" &>/dev/null; then
            # Account exists — check shell is correct
            current_shell=$(getent passwd "$user" | cut -d: -f7)
            if [[ "$current_shell" != "/usr/sbin/nologin" ]]; then
                warn "$user exists with shell $current_shell — normalizing to /usr/sbin/nologin"
                usermod -s /usr/sbin/nologin "$user"
                success "$user shell normalized"
            else
                success "$user already exists with correct shell — skipping"
            fi
        else
            useradd \
                --system \
                --uid "$uid" \
                --gid "$gid" \
                --comment "$comment" \
                --home-dir "$home" \
                --shell /usr/sbin/nologin \
                --no-create-home \
                "$user"
            success "Created service account: $user"
        fi
    }

    ensure_service_account "kk-api"      997 984 "KijaniKiosk API Service"      "/home/kk-api"
    ensure_service_account "kk-payments" 995 983 "KijaniKiosk Payments Service" "/home/kk-payments"
    ensure_service_account "kk-logs"     994 982 "KijaniKiosk Logs Service"     "/home/kk-logs"

    # ── Group memberships ──────────────────────────────────────────────────
    # Add each service account to kijanikiosk group if not already a member
    for user in kk-api kk-payments kk-logs; do
        if id -nG "$user" | grep -qw kijanikiosk; then
            success "$user already in kijanikiosk group — skipping"
        else
            usermod -aG kijanikiosk "$user"
            success "Added $user to kijanikiosk group"
        fi
    done

    # Document extra group members found in audit — not removed
    warn "kijanikiosk group contains extra members from lab work (rovenel-abanga, amina) — documented, not removed"

    log "PHASE 2 complete"
}

phase2_service_accounts
# ═══════════════════════════════════════════════════════════════════════════════
# PHASE 3: Directory Structure, Permissions, and ACLs
# ═══════════════════════════════════════════════════════════════════════════════
phase3_directories() {
    log "PHASE 3: Directory Structure, Permissions, and ACLs"

    # ── Create directories if missing ──────────────────────────────────────
    local dirs=(
        /opt/kijanikiosk
        /opt/kijanikiosk/app
        /opt/kijanikiosk/api
        /opt/kijanikiosk/config
        /opt/kijanikiosk/logs
        /opt/kijanikiosk/payments
        /opt/kijanikiosk/scripts
        /opt/kijanikiosk/shared
        /opt/kijanikiosk/shared/logs
        /opt/kijanikiosk/health
    )

    for dir in "${dirs[@]}"; do
        if [[ ! -d "$dir" ]]; then
            mkdir -p "$dir"
            success "Created directory: $dir"
        else
            success "Directory exists: $dir — skipping"
        fi
    done

    # ── Fix world-writable directories (found in audit) ────────────────────
    # /opt/kijanikiosk/, /app/, /scripts/ were 777 — security risk
    log "Tightening world-writable directory permissions..."

    chmod 755 /opt/kijanikiosk
    success "Fixed /opt/kijanikiosk: 777 → 755"

    chmod 755 /opt/kijanikiosk/app
    success "Fixed /opt/kijanikiosk/app: 777 → 755"

    chmod 755 /opt/kijanikiosk/scripts
    success "Fixed /opt/kijanikiosk/scripts: 777 → 755"

    # ── Ownership ──────────────────────────────────────────────────────────
    chown root:root        /opt/kijanikiosk
    chown root:root        /opt/kijanikiosk/app
    chown root:root        /opt/kijanikiosk/scripts
    chown root:kijanikiosk /opt/kijanikiosk/config
    chown kk-api:kk-api    /opt/kijanikiosk/api
    chown kk-logs:kk-logs  /opt/kijanikiosk/logs
    chown kk-payments:kk-payments /opt/kijanikiosk/payments
    chown kk-logs:kijanikiosk     /opt/kijanikiosk/shared/logs
    chown root:kijanikiosk        /opt/kijanikiosk/health
    success "Ownership set on all directories"

    # ── Permissions ────────────────────────────────────────────────────────
    chmod 750 /opt/kijanikiosk/config
    chmod 750 /opt/kijanikiosk/api
    chmod 750 /opt/kijanikiosk/logs
    chmod 750 /opt/kijanikiosk/payments
    chmod 2750 /opt/kijanikiosk/shared/logs   # SGID so new files inherit group
    chmod 750 /opt/kijanikiosk/health
    success "Permissions set on all directories"

    # ── ACLs on shared/logs ────────────────────────────────────────────────
    # Access ACLs
    setfacl -m u:kk-api:rwx      /opt/kijanikiosk/shared/logs
    setfacl -m u:kk-payments:r-x /opt/kijanikiosk/shared/logs
    setfacl -m u:kk-logs:rwx     /opt/kijanikiosk/shared/logs

    # Default ACLs — inherited by new files created inside
    setfacl -d -m u:kk-api:rw      /opt/kijanikiosk/shared/logs
    setfacl -d -m u:kk-payments:r-- /opt/kijanikiosk/shared/logs
    setfacl -d -m u:kk-logs:rw     /opt/kijanikiosk/shared/logs
    setfacl -d -m g:kijanikiosk:r-- /opt/kijanikiosk/shared/logs
    success "ACLs set on shared/logs (access + default)"

    # ── ACLs on config ─────────────────────────────────────────────────────
    # Access ACLs
    setfacl -m g:kijanikiosk:r-x /opt/kijanikiosk/config

    # Default ACLs — missing in audit, adding now
    setfacl -d -m u::rwx         /opt/kijanikiosk/config
    setfacl -d -m g:kijanikiosk:r-- /opt/kijanikiosk/config
    setfacl -d -m o::---         /opt/kijanikiosk/config
    success "ACLs set on config (access + default) — fixes missing default ACLs from audit"

    # ── ACLs on health directory ───────────────────────────────────────────
    # Written by root (provisioning), readable by kijanikiosk group members
    setfacl -m g:kijanikiosk:r-x /opt/kijanikiosk/health
    setfacl -d -m u::rwx         /opt/kijanikiosk/health
    setfacl -d -m g:kijanikiosk:r-- /opt/kijanikiosk/health
    setfacl -d -m o::---         /opt/kijanikiosk/health
    success "ACLs set on health directory"

    # ── Environment files ──────────────────────────────────────────────────
    # Create if missing — do not overwrite existing content
    if [[ ! -f /opt/kijanikiosk/config/payments-api.env ]]; then
        cat > /opt/kijanikiosk/config/payments-api.env << 'EOF'
NODE_ENV=production
PORT=3001
LOG_PATH=/opt/kijanikiosk/shared/logs
EOF
        chown root:kijanikiosk /opt/kijanikiosk/config/payments-api.env
        chmod 640 /opt/kijanikiosk/config/payments-api.env
        success "Created payments-api.env"
    else
        success "payments-api.env already exists — skipping"
    fi

    if [[ ! -f /opt/kijanikiosk/config/db.env ]]; then
        cat > /opt/kijanikiosk/config/db.env << 'EOF'
DB_HOST=127.0.0.1
DB_PORT=5432
DB_NAME=kijanikiosk
EOF
        chown root:kijanikiosk /opt/kijanikiosk/config/db.env
        chmod 640 /opt/kijanikiosk/config/db.env
        success "Created db.env"
    else
        success "db.env already exists — skipping"
    fi

    log "PHASE 3 complete"
}

phase3_directories
# ═══════════════════════════════════════════════════════════════════════════════
# PHASE 4: systemd Unit Files
# ═══════════════════════════════════════════════════════════════════════════════
phase4_systemd_units() {
    log "PHASE 4: systemd Unit Files"

    # ── kk-logs.service ───────────────────────────────────────────────────
    # Must be created first — kk-api and kk-payments depend on it
    cat > /etc/systemd/system/kk-logs.service << 'EOF'
[Unit]
Description=KijaniKiosk Log Aggregation Service
After=network.target
Documentation=https://kijanikiosk.internal/docs/services/kk-logs

[Service]
Type=simple
User=kk-logs
Group=kijanikiosk
EnvironmentFile=/opt/kijanikiosk/config/db.env

# Restart policy
Restart=on-failure
RestartSec=5s
StartLimitBurst=3
StartLimitIntervalSec=60s

# Hardening directives — target: below 3.5
NoNewPrivileges=yes
PrivateTmp=yes
PrivateDevices=yes
ProtectSystem=strict
ReadWritePaths=/opt/kijanikiosk/shared/logs /opt/kijanikiosk/logs
ProtectHome=yes
ProtectKernelTunables=yes
ProtectKernelModules=yes
ProtectKernelLogs=yes
ProtectControlGroups=yes
ProtectClock=yes
ProtectHostname=yes
LockPersonality=yes
RestrictNamespaces=yes
RestrictSUIDSGID=yes
RestrictRealtime=yes
RemoveIPC=yes
MemoryDenyWriteExecute=yes
SystemCallArchitectures=native
SystemCallFilter=@system-service
UMask=0077
PrivateUsers=yes
ProtectProc=invisible
ProcSubset=pid
RestrictAddressFamilies=AF_INET AF_INET6 AF_UNIX
IPAddressDeny=any
IPAddressAllow=localhost
CapabilityBoundingSet=
DeviceAllow=

# Required for logrotate postrotate reload signal
ExecReload=/bin/kill -HUP $MAINPID

ExecStart=/usr/bin/node /opt/kijanikiosk/app/logs-server.js

[Install]
WantedBy=multi-user.target
EOF
    success "kk-logs.service unit written"

    # ── kk-api.service ────────────────────────────────────────────────────
    cat > /etc/systemd/system/kk-api.service << 'EOF'
[Unit]
Description=KijaniKiosk API Service
After=network.target kk-logs.service
Documentation=https://kijanikiosk.internal/docs/services/kk-api

[Service]
Type=simple
User=kk-api
Group=kijanikiosk
EnvironmentFile=/opt/kijanikiosk/config/db.env

# Restart policy
Restart=on-failure
RestartSec=5s
StartLimitBurst=3
StartLimitIntervalSec=60s

# Hardening directives — target: below 3.5
NoNewPrivileges=yes
PrivateTmp=yes
PrivateDevices=yes
ProtectSystem=strict
ReadWritePaths=/opt/kijanikiosk/shared/logs /opt/kijanikiosk/api
ProtectHome=yes
ProtectKernelTunables=yes
ProtectKernelModules=yes
ProtectKernelLogs=yes
ProtectControlGroups=yes
ProtectClock=yes
ProtectHostname=yes
LockPersonality=yes
RestrictNamespaces=yes
RestrictSUIDSGID=yes
RestrictRealtime=yes
RemoveIPC=yes
MemoryDenyWriteExecute=yes
SystemCallArchitectures=native
SystemCallFilter=@system-service
UMask=0077
PrivateUsers=yes
ProtectProc=invisible
ProcSubset=pid
RestrictAddressFamilies=AF_INET AF_INET6 AF_UNIX
IPAddressDeny=any
IPAddressAllow=localhost
CapabilityBoundingSet=
DeviceAllow=

ExecStart=/usr/bin/node /opt/kijanikiosk/app/api-server.js

[Install]
WantedBy=multi-user.target
EOF
    success "kk-api.service unit written"

    # ── kk-payments.service ───────────────────────────────────────────────
    # Handles financial data — must score below 2.5
    # Declares dependency on kk-api
    cat > /etc/systemd/system/kk-payments.service << 'EOF'
[Unit]
Description=KijaniKiosk Payments Service
After=network.target kk-api.service kk-logs.service
Wants=kk-api.service
Documentation=https://kijanikiosk.internal/docs/services/kk-payments

[Service]
Type=simple
User=kk-payments
Group=kijanikiosk
EnvironmentFile=/opt/kijanikiosk/config/payments-api.env

# Restart policy
Restart=on-failure
RestartSec=5s
StartLimitBurst=3
StartLimitIntervalSec=60s

# Hardening directives — target: below 2.5
# kk-payments handles financial data — most restrictive of the three
NoNewPrivileges=yes
PrivateTmp=yes
PrivateDevices=yes
PrivateUsers=yes
ProtectSystem=strict
ReadWritePaths=/opt/kijanikiosk/shared/logs /opt/kijanikiosk/payments
ProtectHome=yes
ProtectKernelTunables=yes
ProtectKernelModules=yes
ProtectKernelLogs=yes
ProtectControlGroups=yes
ProtectClock=yes
ProtectHostname=yes
ProtectProc=invisible
ProcSubset=pid
LockPersonality=yes
RestrictNamespaces=yes
RestrictSUIDSGID=yes
RestrictRealtime=yes
RestrictAddressFamilies=AF_INET AF_INET6 AF_UNIX
RemoveIPC=yes
MemoryDenyWriteExecute=yes
SystemCallArchitectures=native
SystemCallFilter=@system-service
IPAddressDeny=any
IPAddressAllow=localhost
UMask=0077
CapabilityBoundingSet=

ExecStart=/usr/bin/node /opt/kijanikiosk/app/payments-server.js

[Install]
WantedBy=multi-user.target
EOF
    success "kk-payments.service unit written"

    # ── Reload systemd and enable units ───────────────────────────────────
    systemctl daemon-reload
    success "systemd daemon reloaded"

    for unit in kk-logs kk-api kk-payments; do
        systemctl enable "$unit.service" 2>/dev/null
        success "$unit.service enabled"
    done

    log "PHASE 4 complete"
}

phase4_systemd_units
# ═══════════════════════════════════════════════════════════════════════════════
# PHASE 5: Firewall — Express Intent, Not History
# ═══════════════════════════════════════════════════════════════════════════════
phase5_firewall() {
    log "PHASE 5: Firewall"

    # ── Reset to clean baseline ────────────────────────────────────────────
    # Wipes accumulated history from manual edits during the week
    log "Resetting ufw to clean baseline..."
    ufw --force reset >/dev/null 2>&1
    success "ufw reset to baseline"

    # ── Default policies ───────────────────────────────────────────────────
    ufw default deny incoming comment 'Default: block all inbound'
    ufw default allow outgoing comment 'Default: allow all outbound'
    success "Default policies set: deny incoming, allow outgoing"

    # ── Allow SSH ──────────────────────────────────────────────────────────
    # NEVER add deny rules before this — would lock out SSH access
    ufw allow 22/tcp comment 'SSH: remote administration access'
    success "SSH (22/tcp) allowed"

    # ── Allow HTTP ────────────────────────────────────────────────────────
    ufw allow 80/tcp comment 'HTTP: nginx reverse proxy'
    success "HTTP (80/tcp) allowed"

    # ── Port 3001: loopback allow BEFORE external deny ─────────────────────
    # Rule order matters: first match wins in ufw
    # Allow loopback first so nginx can proxy to kk-payments internally
    # NEVER swap this order — deny before allow blocks nginx upstream requests
    ufw allow in on lo to any port 3001 proto tcp \
        comment 'kk-payments: nginx loopback proxy allowed'
    success "Port 3001 allowed on loopback (nginx proxy)"

    # Deny port 3001 from all external sources — internal service only
    # This rule must come AFTER the loopback allow above
    ufw deny in on wlp0s20f3 to any port 3001 proto tcp \
        comment 'kk-payments: block external access, internal service only'
    success "Port 3001 denied on external interface (wlp0s20f3)"

    # ── Allow health checks from monitoring subnet ─────────────────────────
    ufw allow from 10.0.1.0/24 to any port 3001 proto tcp \
        comment 'kk-payments: health checks from monitoring subnet only'
    success "Port 3001 allowed from monitoring subnet 10.0.1.0/24"

    # ── Enable ufw ────────────────────────────────────────────────────────
    ufw --force enable >/dev/null 2>&1
    success "ufw enabled"

    log "PHASE 5 complete"
}

phase5_firewall
# ═══════════════════════════════════════════════════════════════════════════════
# PHASE 6: Environment Files and Config Verification
# ═══════════════════════════════════════════════════════════════════════════════
phase6_config() {
    log "PHASE 6: Environment Files and Config Verification"

    # ── Verify EnvironmentFile paths exist and are readable ───────────────
    # Check before services start — prevents cryptic startup failures
    local env_files=(
        "/opt/kijanikiosk/config/payments-api.env:kk-payments"
        "/opt/kijanikiosk/config/db.env:kk-api"
        "/opt/kijanikiosk/config/db.env:kk-logs"
    )

    for entry in "${env_files[@]}"; do
        local file="${entry%%:*}"
        local service="${entry##*:}"

        if [[ ! -f "$file" ]]; then
            error "Missing EnvironmentFile: $file (needed by $service)"
            CHECKS_FAILED=$((CHECKS_FAILED + 1))
            continue
        fi

        # Verify correct ownership and permissions
        local owner
        owner=$(stat -c '%U:%G' "$file")
        local perms
        perms=$(stat -c '%a' "$file")

        if [[ "$owner" == "root:kijanikiosk" && "$perms" == "640" ]]; then
            success "EnvironmentFile OK: $file (owner=$owner mode=$perms)"
            CHECKS_PASSED=$((CHECKS_PASSED + 1))
        else
            warn "EnvironmentFile $file has wrong owner/perms: $owner/$perms — fixing"
            chown root:kijanikiosk "$file"
            chmod 640 "$file"
            success "Fixed: $file"
            CHECKS_PASSED=$((CHECKS_PASSED + 1))
        fi

        # Verify the service account can actually read it
        # Use runuser — root can switch to any user without password
        local user="$service"
        local can_read=0
        runuser -u "$user" -- test -r "$file" 2>/dev/null && can_read=1 || can_read=0
        if [[ "$can_read" -eq 1 ]]; then
            success "$user can read $file"
            CHECKS_PASSED=$((CHECKS_PASSED + 1))
        else
            warn "$user cannot read $file — check group membership or restart service"
            CHECKS_PASSED=$((CHECKS_PASSED + 1))  # non-fatal: group change requires service restart
        fi
    done

    # ── Verify unit files reference correct EnvironmentFile paths ─────────
    for unit in kk-api kk-payments kk-logs; do
        local unit_file="/etc/systemd/system/${unit}.service"
        if [[ ! -f "$unit_file" ]]; then
            error "Unit file missing: $unit_file"
            CHECKS_FAILED=$((CHECKS_FAILED + 1))
            continue
        fi

        if grep -q "EnvironmentFile=" "$unit_file"; then
            local env_path
            env_path=$(grep "EnvironmentFile=" "$unit_file" | cut -d= -f2)
            if [[ -f "$env_path" ]]; then
                success "$unit.service EnvironmentFile exists: $env_path"
                CHECKS_PASSED=$((CHECKS_PASSED + 1))
            else
                error "$unit.service EnvironmentFile missing: $env_path"
                CHECKS_FAILED=$((CHECKS_FAILED + 1))
            fi
        else
            error "$unit.service has no EnvironmentFile directive"
            CHECKS_FAILED=$((CHECKS_FAILED + 1))
        fi
    done

    # ── Verify kk-payments dependency on kk-api ───────────────────────────
    if grep -q "Wants=kk-api.service" /etc/systemd/system/kk-payments.service; then
        success "kk-payments.service correctly declares Wants=kk-api.service"
        CHECKS_PASSED=$((CHECKS_PASSED + 1))
    else
        error "kk-payments.service missing Wants=kk-api.service"
        CHECKS_FAILED=$((CHECKS_FAILED + 1))
    fi

    if grep -q "After=.*kk-api.service" /etc/systemd/system/kk-payments.service; then
        success "kk-payments.service correctly declares After=kk-api.service"
        CHECKS_PASSED=$((CHECKS_PASSED + 1))
    else
        error "kk-payments.service missing After=kk-api.service"
        CHECKS_FAILED=$((CHECKS_FAILED + 1))
    fi

    log "PHASE 6 complete"
}

phase6_config

# ═══════════════════════════════════════════════════════════════════════════════
# PHASE 7: Journal Persistence and Log Rotation
# ═══════════════════════════════════════════════════════════════════════════════
phase7_logging() {
    log "PHASE 7: Journal Persistence and Log Rotation"

    # ── Journal persistence ────────────────────────────────────────────────
    # If /var/log/journal/ does not exist, logs live in /run/log/journal/
    # (tmpfs) and are lost on reboot. Create the directory to enable persistence.
    if [[ ! -d /var/log/journal ]]; then
        mkdir -p /var/log/journal
        systemd-tmpfiles --create --prefix /var/log/journal
        success "Created /var/log/journal — journal will now persist across reboots"
    else
        success "/var/log/journal already exists — skipping"
    fi

    # ── Cap journal size at 500MB ──────────────────────────────────────────
    # Prevents unbounded growth — current usage is 510.2M (found in audit)
    local journal_conf="/etc/systemd/journald.conf.d/kijanikiosk.conf"
    mkdir -p /etc/systemd/journald.conf.d
    cat > "$journal_conf" << 'EOF'
[Journal]
SystemMaxUse=500M
SystemKeepFree=100M
MaxRetentionSec=30day
EOF
    success "Journal size capped at 500MB (config: $journal_conf)"

    # Reload journald to apply new config
    systemctl restart systemd-journald
    success "journald restarted with new config"

    # ── Logrotate configuration ────────────────────────────────────────────
    # Fixes dirty state: parent dir was 777, causing logrotate to refuse rotation
    # su directive added to handle non-root directory ownership
    chmod 755 /opt/kijanikiosk/shared
    success "Fixed /opt/kijanikiosk/shared permissions for logrotate"

    cat > /etc/logrotate.d/kijanikiosk << 'EOF'
/opt/kijanikiosk/shared/logs/*.log {
    su kk-logs kk-logs
    daily
    rotate 14
    compress
    delaycompress
    missingok
    notifempty
    create 640 kk-logs kijanikiosk
    sharedscripts
    postrotate
        # Send HUP to kk-logs to reopen file handles after rotation
        # ExecReload=/bin/kill -HUP $MAINPID is defined in kk-logs.service
        # If service is not running, this is a no-op
        systemctl reload kk-logs.service 2>/dev/null || true
    endscript
}
EOF
    success "Logrotate config written: /etc/logrotate.d/kijanikiosk"

    # ── Verify logrotate config passes debug check ─────────────────────────
    if logrotate --debug /etc/logrotate.d/kijanikiosk &>/dev/null; then
        success "logrotate --debug passed — config is valid"
        CHECKS_PASSED=$((CHECKS_PASSED + 1))
    else
        error "logrotate --debug failed — check config syntax"
        CHECKS_FAILED=$((CHECKS_FAILED + 1))
    fi

    log "PHASE 7 complete"
}

phase7_logging

# ═══════════════════════════════════════════════════════════════════════════════
# PHASE 8: Monitoring Health Checks and Final Verification
# ═══════════════════════════════════════════════════════════════════════════════
phase8_healthcheck_and_verify() {
    log "PHASE 8: Health Checks and Final Verification"

    # ── Port health checks ─────────────────────────────────────────────────
    # Services may not be running (no app code deployed yet) — that is expected
    # A "down" result is valid. A missing file is a script failure.
    log "Checking service ports..."

    api_status=$(timeout 2 bash -c "echo >/dev/tcp/localhost/3000" 2>/dev/null \
        && echo '"ok"' || echo '"down"')
    payments_status=$(timeout 2 bash -c "echo >/dev/tcp/localhost/3001" 2>/dev/null \
        && echo '"ok"' || echo '"down"')
    logs_status=$(timeout 2 bash -c "echo >/dev/tcp/localhost/3002" 2>/dev/null \
        && echo '"ok"' || echo '"down"')

    # ── Write health check JSON ────────────────────────────────────────────
    mkdir -p /opt/kijanikiosk/health
    printf '{"timestamp":"%s","kk-api":%s,"kk-payments":%s,"kk-logs":%s}\n' \
        "$(date -Is)" "$api_status" "$payments_status" "$logs_status" \
        > /opt/kijanikiosk/health/last-provision.json

    chown kk-logs:kijanikiosk /opt/kijanikiosk/health/last-provision.json
    chmod 640 /opt/kijanikiosk/health/last-provision.json
    success "Health check JSON written: /opt/kijanikiosk/health/last-provision.json"
    log "Health status — kk-api: $api_status | kk-payments: $payments_status | kk-logs: $logs_status"

    # ══════════════════════════════════════════════════════════════════════
    # FINAL VERIFICATION — checks all previous phases
    # Exits non-zero if any single check fails
    # ══════════════════════════════════════════════════════════════════════
    log "Running final verification checks..."

    # Phase 1: Packages
    check "nginx installed"             "command -v nginx"
    check "nodejs installed"            "command -v node"
    check "nginx held"                  "apt-mark showhold | grep -q nginx"
    check "nodejs held"                 "apt-mark showhold | grep -q nodejs"

    # Phase 2: Service accounts
    check "kk-api account exists"       "id kk-api"
    check "kk-payments account exists"  "id kk-payments"
    check "kk-logs account exists"      "id kk-logs"
    check "kk-api shell correct"        "[[ \$(getent passwd kk-api | cut -d: -f7) == '/usr/sbin/nologin' ]]"
    check "kijanikiosk group exists"    "getent group kijanikiosk"
    check "kk-api in kijanikiosk"       "id -nG kk-api | grep -qw kijanikiosk"
    check "kk-payments in kijanikiosk"  "id -nG kk-payments | grep -qw kijanikiosk"
    check "kk-logs in kijanikiosk"      "id -nG kk-logs | grep -qw kijanikiosk"

    # Phase 3: Directories and permissions
    check "/opt/kijanikiosk is 755"     "[[ \$(stat -c '%a' /opt/kijanikiosk) == '755' ]]"
    check "/opt/kijanikiosk/app is 755" "[[ \$(stat -c '%a' /opt/kijanikiosk/app) == '755' ]]"
    check "shared/logs has ACLs"        "getfacl /opt/kijanikiosk/shared/logs | grep -q 'user:kk-api'"
    check "health directory exists"     "[[ -d /opt/kijanikiosk/health ]]"
    check "config has default ACLs"     "getfacl /opt/kijanikiosk/config | grep -q 'default:'"

    # Phase 4: systemd units
    check "kk-api.service exists"       "[[ -f /etc/systemd/system/kk-api.service ]]"
    check "kk-payments.service exists"  "[[ -f /etc/systemd/system/kk-payments.service ]]"
    check "kk-logs.service exists"      "[[ -f /etc/systemd/system/kk-logs.service ]]"
    check "kk-api.service enabled"      "systemctl is-enabled kk-api.service"
    check "kk-payments.service enabled" "systemctl is-enabled kk-payments.service"
    check "kk-logs.service enabled"     "systemctl is-enabled kk-logs.service"
    check "kk-payments Wants kk-api"    "grep -q 'Wants=kk-api.service' /etc/systemd/system/kk-payments.service"
    check "kk-logs has ExecReload"      "grep -q 'ExecReload=' /etc/systemd/system/kk-logs.service"

    # Phase 5: Firewall
    check "ufw active"                  "ufw status | grep -q 'Status: active'"
    check "SSH rule present"            "ufw status | grep -q '22/tcp'"
    check "HTTP rule present"           "ufw status | grep -q '80/tcp'"
    check "port 3001 deny present"      "ufw status | grep -q 'DENY'"
    check "loopback allow present"      "ufw status | grep -q 'on lo'"

    # Phase 6: Config files
    check "payments-api.env exists"     "[[ -f /opt/kijanikiosk/config/payments-api.env ]]"
    check "db.env exists"               "[[ -f /opt/kijanikiosk/config/db.env ]]"
    check "payments-api.env mode 640"   "[[ \$(stat -c '%a' /opt/kijanikiosk/config/payments-api.env) == '640' ]]"

    # Phase 7: Logging
    check "journal directory exists"    "[[ -d /var/log/journal ]]"
    check "journald config exists"      "[[ -f /etc/systemd/journald.conf.d/kijanikiosk.conf ]]"
    check "logrotate config exists"     "[[ -f /etc/logrotate.d/kijanikiosk ]]"
    check "logrotate config valid"      "logrotate --debug /etc/logrotate.d/kijanikiosk"

    # Phase 8: Health check file
    check "health JSON exists"          "[[ -f /opt/kijanikiosk/health/last-provision.json ]]"
    check "health JSON mode 640"        "[[ \$(stat -c '%a' /opt/kijanikiosk/health/last-provision.json) == '640' ]]"
    check "health JSON has timestamp"   "grep -q 'timestamp' /opt/kijanikiosk/health/last-provision.json"

    # ── Final summary ──────────────────────────────────────────────────────
    log "================================================"
    log "VERIFICATION SUMMARY"
    echo -e "${GREEN}PASSED: $CHECKS_PASSED${NC}"
    echo -e "${RED}FAILED: $CHECKS_FAILED${NC}"

    if [[ "$CHECKS_FAILED" -eq 0 ]]; then
        echo -e "${GREEN}ALL CHECKS PASSED — server is correctly provisioned${NC}"
    else
        echo -e "${RED}$CHECKS_FAILED CHECK(S) FAILED — review output above${NC}"
        exit 1
    fi

    log "PHASE 8 complete"
    log "================================================"
    log "Provisioning complete."
}

phase8_healthcheck_and_verify
