# KijaniKiosk Access Model — Final
**Engineer:** Rovenel Abanga
**Date:** 2026-03-29
**Status:** Updated from Tuesday baseline — includes health directory and logrotate interaction notes

---

## Service Accounts

| Account | UID | Shell | Purpose |
|---|---|---|---|
| kk-api | 997 | /usr/sbin/nologin | API service process identity |
| kk-payments | 995 | /usr/sbin/nologin | Payments service process identity |
| kk-logs | 994 | /usr/sbin/nologin | Log aggregation service process identity |

All service accounts use `/usr/sbin/nologin` — they cannot be used for
interactive login. Note: kk-api was found during the Friday audit using
`/usr/bin/nologin` (a Tuesday inconsistency). The provisioning script
normalizes this automatically.

## Groups

| Group | GID | Members |
|---|---|---|
| kijanikiosk | 1004 | kk-api, kk-payments, kk-logs, rovenel-abanga, amina |

The shared group allows controlled cross-service file access. rovenel-abanga
and amina are present from lab work — documented and intentionally retained.

---

## Directory Access Model

### /opt/kijanikiosk/
```
Owner:      root:root
Mode:       755
Purpose:    Root of all KijaniKiosk application files
```
World-readable but not writable. No service account writes here directly.

---

### /opt/kijanikiosk/config/
```
Owner:      root:kijanikiosk
Mode:       750
ACLs:       user:rovenel-abanga:r-x
Default:    user::rwx, g:kijanikiosk:r--, o::---
Purpose:    Environment files and service configuration
```
All kijanikiosk group members can read config files. Only root can write.
Default ACLs ensure new files created here inherit group read permissions.

**Files:**
| File | Owner | Mode | Readable by |
|---|---|---|---|
| db.env | root:kijanikiosk | 640 | kijanikiosk group |
| payments-api.env | root:kijanikiosk | 640 | kijanikiosk group |

**Logrotate interaction:** Config files are not rotated. No interaction.

---

### /opt/kijanikiosk/shared/logs/
```
Owner:      kk-logs:kijanikiosk
Mode:       2750 (SGID set)
ACLs:       user:kk-api:rwx, user:kk-payments:r-x, user:kk-logs:rwx
            user:rovenel-abanga:r-x
Default:    user:kk-api:rw-, user:kk-payments:r--, user:kk-logs:rw-
            group:kijanikiosk:r--
Purpose:    Shared log files written by kk-api and kk-logs, readable by kk-payments
```

**Access matrix:**
| Account | Directory | Files (new) |
|---|---|---|
| kk-api | rwx | rw- (via default ACL) |
| kk-payments | r-x | r-- (via default ACL) |
| kk-logs | rwx | rw- (via default ACL) |
| kijanikiosk group | r-x | r-- (via default group ACL) |

**SGID effect:** New files created inside this directory inherit the
`kijanikiosk` group regardless of the creating user's primary group.

**Logrotate interaction (critical):**
When logrotate rotates files here, it creates new empty files using the
`create 640 kk-logs kijanikiosk` directive. These new files are owned by
`kk-logs:kijanikiosk` with mode `640`. The `+` in `ls -la` output confirms
ACL entries are present on new files — they inherit from the directory's
default ACLs set with `setfacl -d`.

Verified with:
```bash
sudo -u kk-api touch /opt/kijanikiosk/shared/logs/test-write.tmp
# Result: PASS — kk-api can write after logrotate
```

The `su kk-logs kk-logs` directive in `/etc/logrotate.d/kijanikiosk` is
required because the parent directory `/opt/kijanikiosk/shared/` must not be
world-writable (logrotate refuses to rotate files in world-writable directories
as a security measure).

---

### /opt/kijanikiosk/api/
```
Owner:      kk-api:kk-api
Mode:       750
Purpose:    kk-api service private data directory
```
Only kk-api can read or write here. No cross-service access.

---

### /opt/kijanikiosk/payments/
```
Owner:      kk-payments:kk-payments
Mode:       750
Purpose:    kk-payments service private data directory
```
Only kk-payments can read or write here. No cross-service access.
Financial transaction data stored here is not readable by other services.

---

### /opt/kijanikiosk/logs/
```
Owner:      kk-logs:kk-logs
Mode:       750
Purpose:    kk-logs service private working directory
```
Only kk-logs can read or write here.

---

### /opt/kijanikiosk/health/ ← NEW (added Friday)
```
Owner:      root:kijanikiosk
Mode:       750
ACLs:       g:kijanikiosk:r-x
Default:    user::rwx, g:kijanikiosk:r--, o::---
Purpose:    Health check output — written by provisioning script, read by monitoring
```
**Access matrix:**
| Account | Access |
|---|---|
| root | rwx (writes health JSON during provisioning) |
| kijanikiosk group | r-x (read health JSON without sudo) |
| other | none |

**File:** `last-provision.json`
```
Owner:  kk-logs:kijanikiosk
Mode:   640
Format: {"timestamp":"...","kk-api":"down|ok","kk-payments":"down|ok","kk-logs":"down|ok"}
```
Written by root during provisioning, immediately chowned to kk-logs:kijanikiosk.
All kijanikiosk group members can read it. World has no access.

**Logrotate interaction:** Health check files are not log files and are not
rotated. The provisioning script overwrites `last-provision.json` on each run.
No rotation config needed.

---

### /opt/kijanikiosk/app/ and /opt/kijanikiosk/scripts/
```
Owner:      root:root
Mode:       755
Purpose:    Application code and operational scripts
```
World-readable but not writable. Were found as 777 in Friday's audit —
tightened to 755 by the provisioning script.

---

## Verification Commands

```bash
# Verify all directory ownership and permissions
ls -la /opt/kijanikiosk/
ls -la /opt/kijanikiosk/shared/
ls -la /opt/kijanikiosk/config/
ls -la /opt/kijanikiosk/health/

# Verify ACLs
getfacl /opt/kijanikiosk/shared/logs/
getfacl /opt/kijanikiosk/config/
getfacl /opt/kijanikiosk/health/

# Verify access model survives logrotate
sudo logrotate --force /etc/logrotate.d/kijanikiosk
sudo -u kk-api touch /opt/kijanikiosk/shared/logs/test-write.tmp \
  && echo "PASS: kk-api can write after logrotate" \
  || echo "FAIL: access model broken"

# Verify service accounts
getent passwd kk-api kk-payments kk-logs
getent group kijanikiosk
```