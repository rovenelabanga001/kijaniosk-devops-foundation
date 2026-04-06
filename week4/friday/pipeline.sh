#!/bin/bash
# pipeline.sh
# Full IaC pipeline: Terraform provisions, Ansible configures.
# Exits non-zero if either stage fails.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TERRAFORM_DIR="$SCRIPT_DIR/terraform"
ANSIBLE_DIR="$SCRIPT_DIR/ansible"
INVENTORY="$ANSIBLE_DIR/inventory.ini"

log()     { echo -e "\033[0;34m[$(date '+%H:%M:%S')]\033[0m $*"; }
success() { echo -e "\033[0;32m[PASS]\033[0m $*"; }
error()   { echo -e "\033[0;31m[FAIL]\033[0m $*" >&2; }

# ── Stage 1: Terraform ────────────────────────────────────────────────────────
log "Stage 1: Terraform"
cd "$TERRAFORM_DIR"

log "Running terraform init..."
terraform init -reconfigure

log "Running terraform plan..."
terraform plan -out=tfplan

log "Running terraform apply..."
terraform apply tfplan
success "Terraform apply complete"

# ── Stage 2: Extract IPs and write inventory ──────────────────────────────────
log "Stage 2: Extracting IPs from Terraform output..."

API_IP=$(terraform output -raw api_ip)
PAYMENTS_IP=$(terraform output -raw payments_ip)
LOGS_IP=$(terraform output -raw logs_ip)

log "API IP: $API_IP"
log "Payments IP: $PAYMENTS_IP"
log "Logs IP: $LOGS_IP"

log "Writing inventory.ini..."
cat > "$INVENTORY" << EOF
[kijanikiosk_api]
api-staging ansible_host=${API_IP}

[kijanikiosk_payments]
payments-staging ansible_host=${PAYMENTS_IP}

[kijanikiosk_logs]
logs-staging ansible_host=${LOGS_IP}

[kijanikiosk:children]
kijanikiosk_api
kijanikiosk_payments
kijanikiosk_logs

[kijanikiosk:vars]
ansible_python_interpreter=/usr/bin/python3
ansible_user=rovenelabanga2001
ansible_ssh_private_key_file=~/.ssh/kijanikiosk-key
EOF

success "Inventory written with live IPs"

# ── Stage 3: Ansible ──────────────────────────────────────────────────────────
log "Stage 3: Ansible — waiting 30s for servers to be ready..."
sleep 30

cd "$ANSIBLE_DIR"

log "Testing connectivity..."
ansible all -i "$INVENTORY" -m ping

log "Running playbook..."
ansible-playbook -i "$INVENTORY" kijanikiosk.yml
success "Ansible playbook complete"

log "================================================"
success "Pipeline complete. Infrastructure provisioned and configured."
log "================================================"