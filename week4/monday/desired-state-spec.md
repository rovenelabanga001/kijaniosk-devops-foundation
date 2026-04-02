# KijaniKiosk API Server - Desired State Specification
Date: 2026-04-01
Engineer: Rovenel Abanga
Purpose: Declarative specification for Tuesday's Terraform configuration

---

## Identity
- Name: kijanikiosk-api-staging
- Environment tag: staging
- Owner tag: amina
- Project: kijanikiosk (GCP project)

---

## Compute
- Provider: Google Cloud Platform (GCP)
- Region: europe-west1 (Belgium)
- Zone: europe-west1-b
- Instance type: e2-micro
- Operating system: Ubuntu 22.04 LTS
- Exact image ID: projects/ubuntu-os-cloud/global/images/ubuntu-2204-jammy-v20260313
- vCPU: 2 (shared)
- RAM: 1GB (958MB usable)

---

## Networking
- VPC: default (10.132.0.0/20)
- Subnet: default-europe-west1
- Internal IP: assigned automatically (DHCP)
- External IP: ephemeral public IP (assigned automatically)
- Assign public IP: yes — required for SSH access and HTTP traffic
- Network interface: ens4
- MTU: 1460 (GCP default — lower than standard 1500)

---

## Access Control
- SSH access: port 22, source 41.90.187.119/32 only
- HTTP access: port 80, source 0.0.0.0/0
- All other inbound: deny
- All outbound: allow

### Firewall Rules
| Rule name                | Direction | Action | Port | Source            |
|--------------------------|-----------|--------|------|-------------------|
| allow-ssh-kijanikiosk    | Ingress   | Allow  | 22   | 41.90.187.119/32  |
| allow-http-kijanikiosk   | Ingress   | Allow  | 80   | 0.0.0.0/0         |
| default-deny-all         | Ingress   | Deny   | all  | 0.0.0.0/0         |

---

## Storage
- Root volume: 10GB standard persistent disk
- Type: pd-standard (standard persistent disk)
- Boot disk: yes
- Auto-delete on instance termination: yes

---

## Authentication
- SSH key pair name: kijanikiosk-key
- Key type: ed25519
- Public key location: ~/.ssh/kijanikiosk-key.pub
- Private key location: ~/.ssh/kijanikiosk-key (local machine only)
- SSH username: rovenelabanga2001 (derived from Google account)
- Password authentication: disabled (GCP default)

---

## What Must NOT Exist on This Server After Provisioning
- No password authentication for SSH — key-only access enforced
- No services listening on unexpected ports — only sshd on port 22
- No world-writable directories outside /tmp
- No root login via SSH
- No default GCP service account with broad permissions attached
- No swap space configured (matches baseline — e2-micro default)
- No ufw rules conflicting with GCP firewall rules
- No unattended package upgrades that could change pinned versions

---

## Open Questions
These are decisions that were uncertain during manual provisioning and
will need explicit answers before Terraform can encode them correctly:

1. **SSH source IP is dynamic** — the current rule allows only
   41.90.187.119/32. This IP changes when the engineer moves networks
   (different WiFi, mobile data). Should the Terraform config accept the
   source IP as a variable so it can be updated without changing the
   resource definition?

2. **Ephemeral vs static external IP** — the current external IP
   (34.34.183.186) is ephemeral and will change if the instance is
   stopped and restarted. Should Terraform reserve a static IP and attach
   it to the instance? This matters for DNS and monitoring configuration.

3. **SSH username** — GCP derives the username from the Google account
   name (rovenelabanga2001). On a team server, each engineer would get a
   different username. Should Terraform use a service account with a
   consistent username instead?

4. **Default VPC vs custom VPC** — we used the default VPC for speed.
   Production best practice is a custom VPC with explicitly defined CIDR
   ranges. Should Tuesday's Terraform create a custom VPC or continue
   using default?

5. **No metadata or startup script** — the instance was provisioned bare.
   Should Terraform include a startup script to install basic packages
   (curl, git, ufw) so the server is immediately usable after provisioning?

---

## Hardest Decision and Why

The hardest decision during manual provisioning was choosing between an
**ephemeral external IP and a static external IP**. GCP assigns an
ephemeral IP by default — it works immediately and costs nothing, but it
changes every time the instance is stopped and restarted. A static IP
costs a small amount from the free credit but stays constant across
restarts. For a staging server that will be stopped when not in use (to
preserve free credits), an ephemeral IP means the SSH config, any DNS
records, and any firewall rules on the connecting machine all break after
every restart. I chose ephemeral because the lab did not specify
persistence, but I was not confident this was correct. When Tuesday's
Terraform config forces me to declare `network_interface.access_config`
explicitly — with or without a `nat_ip` value — I will have to make this
decision deliberately rather than accepting a console default. That is the
moment the tradeoff becomes impossible to ignore.

---

## Cross-Reference Verification
All values in this spec were verified against the GCP console and the
running VM on 2026-04-01:

| Spec value | Console/VM confirms | Match |
|---|---|---|
| Region: europe-west1 | VM hostname suffix, ip addr show | ✅ |
| Zone: europe-west1-b | GCP console instance details | ✅ |
| Instance type: e2-micro | GCP console machine type | ✅ |
| Image: ubuntu-2204-jammy-v20260313 | metadata endpoint | ✅ |
| Internal IP: 10.132.0.2 | ip addr show ens4 | ✅ |
| External IP: 34.34.183.186 | GCP console, SSH confirmation | ✅ |
| Disk: 10GB | df -h /dev/root = 9.6G usable | ✅ |
| RAM: ~958MB | free -h | ✅ |
| OS: Ubuntu 22.04.5 LTS jammy | lsb_release -a | ✅ |
| SSH key: kijanikiosk-key ed25519 | successful SSH connection | ✅ |
| Firewall SSH rule: 22 from /32 | GCP VPC Firewall console | ✅ |
| Firewall HTTP rule: 80 from anywhere | GCP VPC Firewall console | ✅ |