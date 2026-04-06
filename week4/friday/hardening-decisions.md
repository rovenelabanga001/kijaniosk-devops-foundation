# KijaniKiosk Payments Server: Security Foundation
**Prepared for:** Nia Osei, Chief Executive Officer
**Prepared by:** Rovenel Abanga, Infrastructure Engineering
**Date:** 06 April 2026
**Classification:** Internal — Board Presentable

---

## What Was Built and Why

This document explains the security decisions made in building the
dedicated production infrastructure for KijaniKiosk's payments service.
Every decision described here was made deliberately, tested on real
servers, and verified to work correctly on repeated runs. The goal was
not the most complex security posture possible, but the most appropriate
one: strong enough to protect payment data, simple enough to operate
reliably, and honest about what it does not yet cover.

The payments service handles financial transaction data. That single fact
drove every decision below. A service that processes money is a target.
Our job is to make it a difficult one — and to prove that the difficulty
is consistent and reproducible, not dependent on any one engineer's
memory.

---

## Security Decisions

| Control | What it does | Risk mitigated |
|---|---|---|
| Infrastructure as code | Every server is defined in version-controlled files. No manual console clicks. | Prevents undocumented changes from accumulating over time; any engineer can audit exactly what exists |
| Remote state with locking | The infrastructure definition is stored in a shared cloud location, not on one laptop. Only one person can make changes at a time. | Prevents two engineers from making conflicting changes simultaneously, which would corrupt the infrastructure record |
| No hardcoded secrets in code | Server locations, key names, and access rules are stored as variables, not written directly into configuration files | Prevents sensitive values from being accidentally committed to version control and exposed publicly |
| Dedicated service accounts | Each service runs as its own isolated identity with no login access | Prevents one compromised service from accessing another service's files or data |
| Strict file access model | Each service can only read and write the specific directories it needs | Prevents a compromised payments process from reading API keys or log files it has no business accessing |
| Principle of least privilege | The payments service runs with zero elevated system permissions — it cannot load drivers, modify system settings, or raise its own permissions | Severely limits what an attacker can do if they gain control of the payments process |
| Process isolation | The payments service cannot see other running processes on the system | Prevents the service from reading memory or configuration of other services |
| Network restriction | The payments service can only communicate with the local database and local web server | Contains any data theft attempt to the local machine only |
| Firewall with documented intent | Every network rule is labelled with its purpose; the firewall was rebuilt from a clean baseline rather than inheriting manual edits | Prevents undocumented rules from silently allowing traffic that should be blocked |
| Log rotation with access controls | Logs rotate daily and are retained for 14 days; only authorised services can read them | Prevents log accumulation from filling the disk and prevents unauthorised parties from reading transaction logs |
| Persistent audit trail | System logs are written to permanent storage and capped at 500 megabytes | Ensures logs survive a server restart and are available for incident investigation |

---

## How the Controls Work Together

The controls above are not independent. They form layers. If an attacker
bypasses the firewall, the network restriction at the system level still
contains them. If they gain control of the payments process, the process
isolation and least-privilege controls limit what they can do. If they
manage to write a file, the file access model limits where that file can
go.

This layered approach means exploiting the system requires overcoming
multiple independent controls, not just one. It does not make the system
invulnerable. It makes exploitation significantly more expensive and more
likely to be detected before it succeeds.

The infrastructure code that produces this environment runs identically
every time. Nia can show the board not just what controls exist, but
proof — in the form of two consecutive identical runs — that those
controls are applied consistently and cannot be bypassed by skipping a
manual step.

---

## What the Current Posture Does Not Protect Against

Honest gaps are more credible than overclaiming.

**Application-layer vulnerabilities.** The controls described here
protect the boundary around the payments service. They do not protect
against vulnerabilities in the payments application code itself — for
example, a flaw in how the application validates input or handles
authentication. That requires code review and application security
testing, which are outside the scope of server infrastructure.

**Secrets management.** Database credentials and configuration values
are currently protected by file permissions. This is appropriate for a
staging environment but is not the production standard. A dedicated
secrets management system should be introduced before live payment data
flows through this infrastructure.

**Insider threat.** The controls assume that administrative access is
held by trusted team members. A malicious or compromised administrator
can bypass most of these controls. This risk is mitigated by access
logging and should be further addressed by requiring two-person
authorisation for production changes as the team scales.

**Automated vulnerability scanning.** The servers have not been
subjected to automated security scanning. Known vulnerabilities in
installed software versions may exist that are not captured by the
controls above. A scheduled scanning process should be added to the
operational runbook before production launch.

---

*This document reflects the state of the infrastructure as of 06 April
2026. Security posture should be reviewed at each