# Integration Challenge Notes
**Engineer:** Rovenel Abanga
**Date:** 2026-03-29

These notes document the four integration challenges where requirements
conflicted with each other. Each entry states the conflict, the options
considered, the decision made, and the reasoning behind it.

---

## Challenge A: ProtectSystem=strict and the EnvironmentFile

### The Conflict
`ProtectSystem=strict` remounts the entire filesystem as read-only inside the
service's private namespace, including `/etc` and `/opt`. The EnvironmentFile
for kk-payments is at `/opt/kijanikiosk/config/payments-api.env`. At first
glance this appeared to conflict — if `/opt` is read-only, can the service
read its own config file?

### Investigation
Testing revealed that `ProtectSystem=strict` makes paths read-only for
**writes**, not reads. The service can still read files under `/opt` — it just
cannot write to them. The `ReadWritePaths=` directive is needed only for paths
the service needs to **write** to (log directories, data directories).

The real conflict would have arisen if config files had been stored under
`/etc/kijanikiosk/` — a path some team members used during early lab work.
Under `ProtectSystem=strict`, `/etc` is read-only, so a service trying to
write to `/etc/kijanikiosk/` would fail with EACCES. Since our config files
live under `/opt/kijanikiosk/config/` and the service only reads them, no
conflict exists.

### Options Considered
1. Move config files to `/etc/kijanikiosk/` — rejected because `/etc` is
   read-only under `ProtectSystem=strict` for writes, and we want config files
   in a path owned by our service accounts
2. Use `ReadWritePaths=/opt/kijanikiosk/config` — rejected because this would
   make config files writable by the service, which is unnecessary and reduces
   security
3. Keep config files in `/opt/kijanikiosk/config/` and use `ProtectSystem=strict`
   with `ReadWritePaths` only for log and data directories — **chosen**

### Decision
Config files remain at `/opt/kijanikiosk/config/`. `ReadWritePaths` is set
only for `/opt/kijanikiosk/shared/logs` and the service-specific data
directory. Config files are read-only from the service's perspective, which
is correct — a service should not be able to modify its own configuration.

### Verification
```bash
sudo -u kk-payments cat /opt/kijanikiosk/config/payments-api.env
# Returns file contents — readable ✓
runuser -u kk-payments -- test -w /opt/kijanikiosk/config/payments-api.env
# Returns non-zero — not writable ✓
```

---

## Challenge B: The Monitoring User and ACL Defaults

### The Conflict
Phase 8 requires a health check JSON file written to `/opt/kijanikiosk/health/`
by the provisioning script (running as root). The monitoring system and
engineering team members need to read this file without sudo. The existing
access model from Tuesday did not cover the health directory — it was a new
addition.

### Options Considered
1. Make the file world-readable (mode 644) — rejected because world-readable
   files in a payments server directory are inconsistent with the principle of
   least privilege applied everywhere else
2. Own the file as root:root — rejected because non-root users cannot read it
   without sudo
3. Own the file as kk-logs:kijanikiosk with mode 640, and set ACLs on the
   health directory so kijanikiosk group members can read files inside —
   **chosen**

### Decision
The health directory is owned by `root:kijanikiosk` with mode `750`. The health
JSON file is owned by `kk-logs:kijanikiosk` with mode `640`. All members of
the kijanikiosk group (kk-api, kk-payments, kk-logs, rovenel-abanga, amina)
can read the file without sudo. The provisioning script sets default ACLs on
the health directory so this ownership propagates to any future files created
there.

This extends the Tuesday access model with one new entry:

| Directory | Owner | Mode | ACL |
|---|---|---|---|
| /opt/kijanikiosk/health/ | root:kijanikiosk | 750 | default:g:kijanikiosk:r-- |

The health check file is written by root during provisioning and chowned to
kk-logs:kijanikiosk immediately after creation.

---

## Challenge C: logrotate postrotate and PrivateTmp

### The Conflict
The logrotate config uses `postrotate: systemctl reload kk-logs.service` to
signal kk-logs to reopen its log file handles after rotation. Two problems:

1. `kk-logs.service` has `PrivateTmp=yes` — does this affect the reload signal?
2. If kk-logs has no `ExecReload=` directive, `systemctl reload` sends SIGHUP
   by default. If the Node.js process does not handle SIGHUP, it may terminate
   rather than reopen file handles.

### Investigation
`PrivateTmp=yes` gives the service its own private `/tmp` mount namespace. This
does not affect signal delivery — `systemctl reload` sends a signal to the
process, which is a kernel-level operation independent of mount namespaces.
The PrivateTmp concern was a false alarm.

The real issue is `ExecReload=`. Without it, `systemctl reload` sends SIGHUP.
A Node.js process that does not explicitly handle SIGHUP will terminate on
receipt. This would cause kk-logs to crash after every log rotation — a silent,
scheduled outage.

### Options Considered
1. Use `systemctl restart kk-logs.service` in postrotate instead of reload —
   this works but causes a brief service interruption after every nightly
   rotation, and any in-flight log writes during restart are lost
2. Add `ExecReload=/bin/kill -HUP $MAINPID` to the unit file and handle SIGHUP
   in the application code to reopen file handles — **chosen**
3. Use `copytruncate` in logrotate instead of postrotate — this copies the log
   file then truncates the original, so the service keeps writing to the same
   file descriptor. Rejected because it creates a race condition where log
   entries written between the copy and the truncate are lost

### Decision
`ExecReload=/bin/kill -HUP $MAINPID` was added to kk-logs.service. This sends
SIGHUP to the main process when `systemctl reload` is called. The application
code must handle SIGHUP by closing and reopening log file handles. The
logrotate postrotate directive calls `systemctl reload kk-logs.service || true`
— the `|| true` ensures logrotate does not fail if the service is not running
(for example, during initial provisioning before application code is deployed).

This is documented in the provisioning script with a comment explaining why
`ExecReload=` is required and what breaks without it.

---

## Challenge D: The Dirty VM and Package Holds

### The Conflict
The provisioning script runs on a VM with packages already installed from four
days of lab work. `apt-get install nginx=1.24.0*` succeeds if the correct
version is installed, but behaves unpredictably if a different version is
present — it may attempt a downgrade, fail silently, or be blocked by an
existing hold.

Additionally, nodejs was found at v20 during the audit, while the initial
pinned version in the script was v18. The holds were already set but for the
wrong version.

### Options Considered
1. Blindly run `apt-get install` and let it fail — rejected because failures
   mid-script with `set -euo pipefail` would abort provisioning with a cryptic
   error
2. Remove holds, force install pinned versions, re-apply holds — rejected
   because downgrading nodejs from v20 to v18 on a running server risks
   breaking any application code already tested against v20
3. Check installed versions before attempting install; warn and skip if version
   differs from pinned; update the pinned version in the script to match
   reality — **chosen**

### Decision
The script checks the installed version of each package before attempting
installation. If the installed version matches the pinned version, the install
is skipped with a PASS message. If it differs, the script prints a WARN message
with the exact command needed to resolve the discrepancy and continues — it does
not abort, because a version mismatch is an operational decision that requires
human judgement, not an automatic fix.

The pinned nodejs version was updated from v18 to v20 to match the installed
version found in the audit. This was documented in the audit comments at the
top of the provisioning script.

The reasoning for not automatically downgrading: a provisioning script that
silently downgrades runtime versions on a server that may have running
applications is more dangerous than one that warns and asks for manual
intervention. The engineer running the script sees the warning and can make an
informed decision. This is the correct trade-off between automation and safety
for a payments server.