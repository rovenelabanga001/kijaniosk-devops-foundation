# Reflection
**Engineer:** Rovenel Abanga
**Date:** 2026-03-29
**Project:** KijaniKiosk Production Server Foundation

---

## Question 1: When did you discover two requirements were in conflict?

The conflict surfaced during Phase 7, when I tried to run logrotate after
configuring the journal and log rotation requirements together.

The logrotate requirement said: rotate daily, retain 14 days, create new files
with mode 640 owned by kk-logs:kijanikiosk. The access model requirement said:
kk-api must be able to write to shared/logs, enforced via ACLs set on the
directory.

The conflict was this: logrotate's `create` directive sets standard POSIX
ownership and permissions on new files, but it does not apply ACLs. I had
assumed that because the directory had default ACLs set with `setfacl -d`,
those would propagate automatically to any new file created inside it —
including files created by logrotate.

That assumption was half right. Files created by normal processes inside the
directory do inherit the default ACLs. But logrotate creates files as a
specific user (kk-logs, via the `su` directive) and the `create` directive
overrides the mode explicitly. The question was whether the default ACLs on
the directory would still propagate to those files.

Testing proved they did — the `+` in `ls -la` output confirmed ACL entries on
newly rotated files, and the `sudo -u kk-api touch` test passed. But I did not
know this in advance. I assumed it and then verified it, which is the wrong
order. The right order is to know the mechanism, then configure it, then
verify it.

What I learned: requirements that each look clean in isolation can interact in
ways that are not obvious from reading either one. The ACL model and the
logrotate config are both correct individually. Their interaction required a
specific test to validate. In a real production environment, that test should
be in the provisioning script's verification phase — not discovered manually
after deployment. We added it: the `sudo -u kk-api touch` test now runs as
part of post-remediation verification. That is the direct outcome of finding
the conflict.

---

## Question 2: Rewriting one sentence from the Nia document for Tendo

**Original sentence (written for Nia):**
> "The payments service can only communicate with the local database and local
> web server; all other network destinations are blocked at the operating
> system level."

**Rewritten for Tendo:**
> "`IPAddressDeny=any` and `IPAddressAllow=localhost` in the kk-payments
> systemd unit restrict outbound connections to the loopback address at the
> kernel netfilter level, independent of ufw, so that even if the firewall
> ruleset is reset or bypassed, the service cannot establish connections to
> external hosts or other LAN addresses."

**What is lost in the translation to Tendo's version:**
The sentence becomes longer and assumes prior knowledge of systemd security
directives, netfilter, and the distinction between application-layer and
kernel-layer controls. A board member reading it would disengage immediately.
The original communicates the *intent* and *consequence* without requiring
any of that background.

**What is gained:**
Precision that matters operationally. Tendo's version communicates three things
the Nia version does not: which specific directives implement the control,
where in the stack enforcement happens (kernel, not application), and why it is
more robust than a firewall rule alone (it survives a ufw reset). For an
engineer reviewing the unit file or debugging a connectivity failure, that
precision is the difference between understanding the system and guessing.

The broader lesson: both sentences are correct. They are correct for different
readers with different questions. Nia's question is "are we protected?" 
Tendo's question is "how exactly does this work and what breaks if I change it?"
Writing for the wrong reader wastes their time and erodes trust. Writing for
the right reader builds it.

---

## Question 3: The most fragile part of the provisioning script

The most fragile part is **Phase 5: the firewall configuration**, specifically
this line:

```bash
ufw deny in on wlp0s20f3 to any port 3001 proto tcp \
    comment 'kk-payments: block external access, internal service only'
```

The interface name `wlp0s20f3` is hardcoded. It is the correct interface name
on this specific machine — an HP EliteBook with a wireless adapter. On any
other machine it will almost certainly be different. Common alternatives
include `eth0`, `ens3`, `enp0s3`, `ens18`, or cloud provider-specific names
like `ens5` on AWS or `eth0` on GCP. On a machine with multiple interfaces —
a VM with a management interface and a data interface, for example — the
wrong interface name means the deny rule applies to the wrong interface or
fails silently.

The failure mode is dangerous rather than obvious. If the interface name is
wrong, the deny rule is simply ignored by ufw. The script does not error.
The PASS messages still print. The verification phase checks that a DENY rule
exists in `ufw status` output — and it does exist, it just applies to a
non-existent interface. The service port would be exposed on the real external
interface with no deny rule, and the script would report all checks passed.
That is a silent security failure.

**What I would need to know about the target environment to make it robust:**

1. The name of the primary external interface — this should be passed as a
   script parameter or detected automatically
2. Whether the server has multiple network interfaces and which one faces
   external traffic
3. Whether the server is a VM behind a NAT (in which case the "external"
   interface is actually a private interface and port exposure rules differ)

**How to fix it:**

```bash
# Detect the default route interface at runtime instead of hardcoding
EXTERNAL_IFACE=$(ip route show default | awk '/default/ {print $5}' | head -1)

if [[ -z "$EXTERNAL_IFACE" ]]; then
    error "Cannot detect external interface — set EXTERNAL_IFACE manually"
    exit 1
fi

log "External interface detected: $EXTERNAL_IFACE"
ufw deny in on "$EXTERNAL_IFACE" to any port 3001 proto tcp \
    comment "kk-payments: block external access on $EXTERNAL_IFACE"
```

This detects the interface used for the default route, which is the correct
external interface on any single-homed server. It fails loudly if detection
returns nothing rather than silently applying a useless rule. And it logs
which interface was detected, so the provisioning log contains evidence of
what the script decided.

The hardcoded interface name worked on this VM. It would silently break on
the next one. That gap between "works on my machine" and "works on any
machine" is exactly what makes infrastructure code fragile — and exactly what
the detection pattern above closes.