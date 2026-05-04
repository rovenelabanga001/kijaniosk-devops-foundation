# KijaniKiosk Delivery Pipeline — Week 7 vs Week 8
**Prepared for:** Nia, for Monday board presentation  
**Prepared by:** Rovenel Abanga 
**Date:** 2026-05-03  
**Word count (prose sections):** 847

---

## What Changed and Why It Matters

For the past two weeks, the engineering team has been rebuilding how kk-payments gets from a developer's laptop to a running service. Week 7 proved the team could switch between two versions of the service automatically and roll back within 33 seconds when something went wrong. That was a significant step. But the approach had a ceiling: every deployment depended on a specific machine being configured correctly, with the right files in the right places, and a human verifying each step. If that machine had a problem, the deployment had a problem.

Week 8 removes that ceiling. The payments service is now packaged as a self-contained unit that carries everything it needs to run — its code, its dependencies, and its configuration. That unit is stored in a private registry and can be retrieved and started on any compatible machine without any additional setup. The team does not deploy files anymore. The team delivers a verified, versioned package and instructs the infrastructure to run it.

The second change is in how the infrastructure responds to failure. In Week 7, the automated rollback fired in 33 seconds — but it required a monitoring script to be running, a state file to be correct, and a previous version to be available on the same machine. In Week 8, the infrastructure detects a failed unit and replaces it automatically in 115 seconds, without any script running in the background, without state files, and without human involvement. The replacement pulls a fresh copy of the verified package from the registry. There is no dependency on local machine state.

These are not incremental improvements to the same approach. They are a different approach entirely.

---

## Comparison Table

| Concern | Week 7 Approach | Week 8 Approach |
|---------|----------------|-----------------|
| **Deployment mechanism** | Scripts copy files to a server and restart a process. The server must have Node.js installed and the correct directory structure in place before deployment can run. | A versioned, self-contained image is pulled from a private registry and started as a container. The only requirement on the host is a container runtime. |
| **Rollback mechanism** | A monitoring script detects failures and calls a rollback script, which switches nginx to the previous environment. Requires the previous version to still be running on the same machine. Demonstrated rollback time: 33 seconds. | Any previous image tag remains in the registry indefinitely. Rolling back means updating the Deployment manifest to reference the previous tag. Kubernetes replaces running containers with the previous version automatically. |
| **Failure recovery** | A crashed process stays crashed until a human restarts it or the monitoring script triggers a rollback. The rollback switches traffic but does not restart the failed process. | Kubernetes detects that the number of running units has dropped below the declared minimum and creates a replacement automatically. Demonstrated recovery time: 115 seconds from deletion to replacement running. No human involvement required. |
| **Scaling** | Adding capacity means provisioning a new server, installing Node.js, copying files, and updating nginx configuration manually. Each step is a potential point of failure. | Increasing the replica count in the Deployment manifest causes Kubernetes to schedule additional units immediately. No server provisioning, no manual configuration. |

---

## What This Week's Numbers Mean

Two measurements from this week's work are worth stating precisely because the board will ask about them.

The self-healing demonstration showed a replacement unit running 115 seconds after the original was removed. This is the time from failure to recovery with no human involvement and no monitoring script. At 50,000 transactions per hour, 115 seconds represents approximately 1,600 transactions that could be affected by the failure — routed to the remaining healthy unit rather than the failed one, because the infrastructure kept the second unit running throughout.

The application code that runs inside each unit — the payments logic, the health endpoint, the transaction processing — adds less than one megabyte to the packaged image. The remaining size is the runtime environment the application requires. This matters because it means the team can update the application without changing the runtime, and update the runtime without changing the application. Each concern is independently versioned and independently verifiable.

---

## What Week 8 Does Not Yet Solve

The current deployment is not production-complete. Three gaps remain that the board should be aware of before treating this as the final architecture.

First, configuration is hardcoded into the Deployment manifest. The port number, the version string, and the resource allocation are written directly into a file that is committed to version control. In a production environment, these values change between staging and production, and some of them — particularly any credentials the application needs at runtime — must never appear in a committed file. Week 9 introduces the mechanism for separating configuration from the manifest, so the same manifest can run correctly in any environment without modification.

Second, the infrastructure does not yet distinguish between a unit that has started and a unit that is ready to serve requests. A replacement unit is counted as available the moment its process starts, even if the application inside it needs additional time before it can handle transactions correctly. Week 9 introduces readiness checks that prevent traffic from reaching a unit until the application confirms it is ready.

Third, there is no persistent storage attached to any unit. If the payments service needs to write data that must survive a restart, the current architecture loses it. This is outside the scope of Weeks 8 and 9 but must be addressed before the service handles real transactions.

---

*This document was prepared from lab evidence collected on 2026-05-03. The self-healing time of 115 seconds and the application code size of less than one megabyte are from recorded measurements, not estimates.*