## 1. Why does the kernel ignore SUID on interpreted scripts?

The kernel ignores the SUID bit on interpreted scripts (such as bash scripts starting with #!) because of race condition vulnerabilities. When a script is executed, the kernel would need to pass the script to an interpreter (like /bin/bash). Between the time the script is opened and executed, an attacker could replace or modify the script, causing the interpreter to execute malicious code with elevated privileges. To prevent this time-of-check to time-of-use (TOCTOU) vulnerability, modern Linux systems disable SUID on scripts entirely.

## 2. If SUID has no effect, why is SUID + world-write still critical?

Even though the SUID bit is ignored on scripts, the combination of SUID and world-writable permissions is still dangerous because it indicates a severe misconfiguration. More importantly, this script is executed by a root-owned cron job. Since it is world-writable, any user can modify its contents and inject malicious commands. When the cron job runs the script as root, the attacker's code will execute with root privileges, leading to full system compromise.

## 3. What would make this exploitable in practice?

This becomes exploitable when a privileged process such as a root cron job, systemd service, or administrator manually executes the script. Since the file is world-writable, an attacker can modify it to include malicious commands. When the privileged process runs the script, those commands execute with elevated privileges, effectively giving the attacker root access.
