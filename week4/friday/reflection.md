# Reflection
**Engineer:** Rovenel Abanga
**Date:** 06 April 2026
**Project:** KijaniKiosk Full IaC Pipeline

---

## Question 1: When did you discover two requirements conflicted?

The conflict surfaced during the Ansible phase when implementing
the firewall requirement alongside the Ansible connectivity
requirement.

The firewall playbook task sets the default incoming policy to
deny and restricts SSH to port 22. But Ansible itself connects
over SSH to run every subsequent task. The conflict was this:
if the firewall task ran and denied incoming traffic before
Ansible finished its work, Ansible would lock itself out of
the servers mid-playbook.

The resolution was ordering — the firewall tasks were placed
after all package installation, account creation, and directory
tasks. This meant Ansible completed all configuration before
the firewall hardened the server. The ordering itself became
part of the specification: the playbook is not just a list of
tasks, it is a sequence where order carries meaning.

What I learned: in infrastructure automation, task ordering is
a security decision, not just an implementation detail. A
playbook that applies the firewall first and configures
packages second is functionally different from one that does
it in the reverse order — even if the end state is identical.
The discipline of reasoning about ordering explicitly is the
same discipline that prevents production outages caused by
"the script ran fine in testing but locked us out in
production."

---

## Question 2: Rewriting one sentence for Tendo

**Original sentence written for Nia:**
"The payments service can only communicate with the local
database and local web server; all other network destinations
are blocked at the system level."

**Rewritten for Tendo:**
"`IPAddressDeny=any` and `IPAddressAllow=localhost` in the
kk-payments systemd unit restrict outbound connections to the
loopback address via the kernel's cgroup-based network
filtering, independent of ufw, so the service cannot establish
connections to external hosts even if the firewall ruleset is
reset or misconfigured."

**What is lost:** The Nia version communicates intent and
consequence in plain language. A board member understands
immediately what the control does and why it matters. The
Tendo version requires knowledge of systemd security
directives, cgroup networking, and the distinction between
application-layer and kernel-layer controls. A non-engineer
reading it would disengage.

**What is gained:** Precision that matters operationally.
Tendo's version tells you exactly which directives implement
the control, where in the stack enforcement happens, and
crucially — why it is more robust than a firewall rule alone.
For an engineer reviewing the unit file or debugging a
connectivity failure, that precision is the difference between
understanding the system and guessing at it.

The broader point: both sentences are correct. They are
correct for different readers with different questions. Writing
for the wrong reader wastes their time and erodes trust.

---

## Question 3: The most fragile handoff in the pipeline

The most fragile handoff is the **SSH source IP in
`terraform.tfvars`**.

The firewall rule `allow-ssh-kijanikiosk-friday` restricts SSH
access to a single IP address — the engineer's current IP at
the time `terraform.tfvars` was written. This value:

- Changes every time the engineer moves to a different network
- Is different for every team member
- Is excluded from version control by `.gitignore`
- Is not validated by Terraform — a wrong IP applies silently
  and locks everyone out

The failure mode is dangerous rather than obvious. Terraform
applies successfully. The firewall rule exists. The plan shows
zero changes. But Ansible cannot connect because SSH is blocked
from the new IP. The pipeline exits with an unreachable error
and the engineer spends time debugging Ansible when the real
problem is in Terraform.

**What I would need to know about the target environment to
make this robust:**

1. Whether the pipeline runs from a fixed IP — a CI runner
   with a static IP would make this problem disappear entirely
2. Whether the team uses a VPN with a consistent exit IP —
   if so, the VPN IP becomes the stable source rather than
   each engineer's home IP
3. Whether there is a dedicated bastion host — SSH through
   a bastion with a known IP is the production standard that
   eliminates this problem at the architecture level

The correct fix for a real production environment is to run
the pipeline from a CI system with a known static IP, pass
that IP as a pipeline variable, and remove the
engineer-specific IP from the configuration entirely. That
transforms a fragile per-engineer value into a stable
infrastructure property.