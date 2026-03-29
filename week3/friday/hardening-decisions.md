# KijaniKiosk Payments Server: Security Foundation
**Prepared for:** Nia Osei, Chief Executive Officer
**Prepared by:** Rovenel Abanga, Infrastructure Engineering
**Date:** 29 March 2026
**Classification:** Internal — Board Presentable

---

## What Was Built and Why

This document explains the security decisions made in building the dedicated
production server for KijaniKiosk's payments service. Every decision described
here was made deliberately, tested on a real server, and verified to work
correctly. The goal was not to build the most complex security posture possible,
but to build the most appropriate one: strong enough to protect payment data,
simple enough to operate reliably, and honest about what it does not yet cover.

The payments service handles financial transaction data. That single fact drove
every decision below. A service that processes money is a target. Our job is to
make it a difficult one.

---

## Security Decisions

| Control | What it does | Risk mitigated |
|---|---|---|
| Dedicated service accounts | Each service runs as its own isolated user identity, not as a shared or administrative account | Prevents one compromised service from accessing another service's data or files |
| Strict file access model | Each service can only read and write the specific directories it needs; all other paths are blocked | Prevents a compromised payments process from reading API configuration or log files it has no business accessing |
| Principle of least privilege | The payments service runs with zero elevated system privileges — it cannot load drivers, modify kernel settings, or escalate its own permissions | Severely limits what an attacker can do if they gain code execution inside the payments process |
| Process isolation | The payments service cannot see other running processes on the system | Prevents the service from reading memory contents or configuration of other services |
| Network restriction | The payments service can only communicate with the local database and local web server; all other network destinations are blocked at the operating system level | Contains any data exfiltration attempt to the local machine only |
| Firewall with documented intent | Every network rule is labelled with its purpose; the firewall was reset to a clean baseline rather than inheriting four days of manual edits | Prevents undocumented rules from silently allowing traffic that should be blocked |
| Health check endpoint protection | The payments service port is blocked from external access; only the internal monitoring system can reach it on a specific trusted network range | Prevents external parties from directly probing or attacking the payments endpoint |
| Log rotation with access controls | Logs rotate daily and are retained for 14 days; access to log files is controlled so only authorised services can read them | Prevents log accumulation from filling the disk (which caused Thursday's outage) and prevents unauthorised parties from reading transaction logs |
| Persistent audit trail | System logs are written to permanent storage and capped at 500 megabytes | Ensures logs survive a server restart and are available for incident investigation, while preventing unbounded disk consumption |
| Package version pinning | The versions of all software running on the server are locked and cannot be automatically updated | Prevents an unexpected software update from introducing a breaking change or security regression without a deliberate review |

---

## How the Controls Work Together

The controls above are not independent. They form layers. If an attacker
somehow bypasses the firewall, the network restriction at the operating system
level still contains them. If they gain code execution inside the payments
process, the process isolation and least-privilege controls limit what they can
do with it. If they manage to write a file, the file access model limits where
that file can go.

This layered approach means that exploiting the system requires overcoming
multiple independent controls, not just one. It does not make the system
invulnerable. It makes exploitation significantly more expensive and more
likely to be detected before it succeeds.

The health check monitoring system is a key part of this. When the server is
healthy, the monitoring system sees it as healthy. When something goes wrong —
a rogue process, a misconfigured firewall rule, a service crash — the
monitoring system detects it. Thursday's incident was resolved in under 47
minutes in part because the monitoring signals were readable and the evidence
trail was clear.

---

## What the Current Posture Does Not Protect Against

Honest gaps are more credible than overclaiming. The following risks are not
addressed by this foundation and should be considered in the next sprint:

**Application-layer vulnerabilities.** The controls described here protect the
operating system boundary around the payments service. They do not protect
against vulnerabilities in the payments application code itself — for example,
a flaw in how the application validates input or handles authentication. That
requires code review and application security testing, which are outside the
scope of server infrastructure.

**Secrets management.** Database credentials and API keys are currently stored
in configuration files on the server, protected by file permissions. This is
appropriate for a staging environment but is not the production standard.
A dedicated secrets management system should be introduced before live payment
data flows through this node.

**Insider threat.** The controls assume that administrative access to the
server is held by trusted team members. A malicious or compromised
administrator with SSH access can bypass most of these controls. This risk is
mitigated by access logging and should be further addressed by requiring
two-person authorisation for production changes as the team scales.

**Automated vulnerability scanning.** The server has not been subjected to
automated security scanning. Known vulnerabilities in installed software
versions may exist that are not captured by the package pinning controls above.
A scheduled scanning process should be added to the operational runbook.

---

*This document reflects the state of the server as of 29 March 2026. Security
posture should be reviewed at each sprint boundary and before any significant
change to the payments service architecture.*