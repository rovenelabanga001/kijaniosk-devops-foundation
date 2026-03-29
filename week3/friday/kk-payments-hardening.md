# kk-payments Service Hardening Log
**Engineer:** Rovenel Abanga
**Date:** 2026-03-29
**Target:** systemd-analyze security score below 2.5
**Final score:** 1.1 OK 🙂

---

## Starting Score

Before any hardening directives were added, kk-payments inherited the same
baseline as kk-api — a minimal unit file with only User=, Group=, and
EnvironmentFile= set.

**Starting exposure: ~7.0 HIGH**

---

## Hardening Iterations

### Iteration 1 — Basic isolation
Directives added:
```ini
NoNewPrivileges=yes
PrivateTmp=yes
PrivateDevices=yes
ProtectSystem=strict
ReadWritePaths=/opt/kijanikiosk/shared/logs /opt/kijanikiosk/payments
ProtectHome=yes
```
**Score after: ~5.2 MEDIUM**

Rationale:
- `NoNewPrivileges` prevents the process from gaining elevated privileges via
  setuid binaries or capability-raising exec calls
- `PrivateTmp` gives the service its own /tmp — prevents other processes from
  reading or poisoning temp files used during payment processing
- `PrivateDevices` removes access to hardware devices — a payments service has
  no legitimate reason to access /dev/sda or similar
- `ProtectSystem=strict` makes the entire OS filesystem read-only except for
  explicitly declared ReadWritePaths
- `ProtectHome` prevents the service from reading any user's home directory

---

### Iteration 2 — Kernel protection
Directives added:
```ini
ProtectKernelTunables=yes
ProtectKernelModules=yes
ProtectKernelLogs=yes
ProtectControlGroups=yes
ProtectClock=yes
ProtectHostname=yes
```
**Score after: ~4.1 MEDIUM**

Rationale:
- `ProtectKernelTunables` prevents writing to /proc/sys and /sys — a payments
  service should never modify kernel parameters
- `ProtectKernelModules` prevents loading kernel modules — no legitimate use
  case for a Node.js payments service
- `ProtectKernelLogs` prevents reading the kernel ring buffer — sensitive
  system information should not be accessible to application code
- `ProtectControlGroups` prevents modifying cgroup filesystem — prevents
  resource limit tampering
- `ProtectClock` prevents writing to the hardware clock — financial
  transactions depend on accurate timestamps; clock tampering is a fraud vector
- `ProtectHostname` prevents changing system hostname — prevents misleading
  log entries in a multi-service environment

---

### Iteration 3 — Process and namespace isolation
Directives added:
```ini
LockPersonality=yes
RestrictNamespaces=yes
RestrictSUIDSGID=yes
RestrictRealtime=yes
RemoveIPC=yes
ProtectProc=invisible
ProcSubset=pid
PrivateUsers=yes
```
**Score after: ~2.8 OK**

Rationale:
- `LockPersonality` prevents changing the process ABI personality — closes
  a rarely-used but real privilege escalation vector
- `RestrictNamespaces` prevents the service from creating any Linux namespaces
  — a payments service has no need to create containers or network namespaces
- `RestrictSUIDSGID` prevents creating SUID/SGID files — financial data
  directories should never contain privilege-escalating executables
- `RestrictRealtime` prevents acquiring realtime scheduling priority — prevents
  the service from starving other critical system processes
- `RemoveIPC` cleans up SysV IPC objects when the service exits — prevents
  resource leaks between restarts
- `ProtectProc=invisible` hides other processes' /proc entries from the service
  — prevents the payments service from reading memory maps of other processes
- `ProcSubset=pid` further restricts /proc access to process information only
- `PrivateUsers` gives the service its own user namespace — UIDs inside the
  service do not map to real system UIDs

---

### Iteration 4 — Network and syscall restrictions
Directives added:
```ini
RestrictAddressFamilies=AF_INET AF_INET6 AF_UNIX
MemoryDenyWriteExecute=yes
SystemCallArchitectures=native
SystemCallFilter=@system-service
IPAddressDeny=any
IPAddressAllow=localhost
UMask=0077
CapabilityBoundingSet=
```
**Score after: 1.1 OK**

Rationale:
- `RestrictAddressFamilies` limits socket types to only what a payments service
  needs: IPv4, IPv6, and Unix sockets. Exotic socket families (AF_PACKET,
  AF_NETLINK) are blocked
- `MemoryDenyWriteExecute` prevents the service from creating memory regions
  that are both writable and executable — closes a common exploit technique
- `SystemCallArchitectures=native` prevents the service from making syscalls
  using non-native ABIs (e.g. 32-bit syscalls on a 64-bit system)
- `SystemCallFilter=@system-service` allows only the syscalls a normal service
  needs, blocking dangerous calls like ptrace, mount, and reboot
- `IPAddressDeny=any` + `IPAddressAllow=localhost` restricts network
  connections to loopback only — the payments service communicates only with
  local nginx and local database
- `UMask=0077` ensures any files created by the service are only accessible
  by the service's own user — no world-readable payment data
- `CapabilityBoundingSet=` (empty) drops ALL Linux capabilities — the service
  runs with zero elevated privileges, the most restrictive possible setting

---

## Final Score

```
→ Overall exposure level for kk-payments.service: 1.1 OK 🙂
```

**Target was below 2.5. Achieved 1.1.**

---

## Directives Investigated But Not Applied

### 1. PrivateNetwork=yes
**What it does:** Gives the service a completely isolated network namespace
with no access to any network interfaces including loopback.

**Why not applied:** kk-payments needs to accept connections from nginx on
localhost:3001 and connect to the PostgreSQL database on localhost:5432.
`PrivateNetwork=yes` would sever both connections entirely, making the service
non-functional. The combination of `IPAddressDeny=any` +
`IPAddressAllow=localhost` achieves the same intent (restrict to loopback only)
without breaking connectivity.

**Score impact if applied:** Would have reduced score by ~0.5 but the service
would fail to start and handle any requests.

### 2. RootDirectory=/RootImage=
**What it does:** Runs the service in a chroot or disk image, completely
isolating its filesystem view from the host.

**Why not applied:** Implementing a proper chroot for a Node.js service requires
packaging all Node.js dependencies, shared libraries, and the application code
into a separate directory tree. This is significant operational complexity that
is better addressed through containerisation (Docker/Podman) in a later
infrastructure iteration. Adding a half-configured chroot would create a brittle
setup that breaks on Node.js upgrades. The existing `ProtectSystem=strict` +
`ReadWritePaths` combination achieves strong filesystem isolation without
the maintenance burden.

**Score impact if applied:** Would reduce score by ~0.1 but adds significant
operational complexity disproportionate to the marginal security gain.

---

## Final Unit File

```ini
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

Restart=on-failure
RestartSec=5s
StartLimitBurst=3
StartLimitIntervalSec=60s

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
```