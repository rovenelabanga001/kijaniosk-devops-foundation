# Post-Incident Review — Week 5 Monday Morning Incident

**Incident ID:** PIR-W5-001  
**Date of incident:** Week 5, Monday morning  
**Date of review:** 2026-04-26  
**Review author:** Amina (Platform Engineering)  
**Status:** Complete

---

## Section 1: Incident Summary

During a live investor demonstration led by Nia, the automated deployment pipeline was triggered against the wrong environment, causing 48 seconds of staging unavailability. The pipeline targeted the active blue environment instead of the idle green environment, briefly disrupting the service Nia was presenting to investors. The error was detected and resolved within the same session, but not before the disruption was visible to the audience.

---

## Section 2: Timeline

All times are reconstructed from course narrative and lab evidence. Timestamps marked **(estimated)** could not be confirmed from retained log files.

| Time | Event |
|------|-------|
| 09:00 (estimated) | Nia begins investor walkthrough of the KijaniKiosk staging environment. Blue is active and serving v1.3.0 through the nginx proxy. |
| 09:00–09:10 (estimated) | Nia demonstrates the payment flow to investors. Blue is serving correctly. |
| 09:11 (estimated) | Amina triggers the deployment pipeline from the Jenkins UI, intending to deploy v1.4.0 to green. |
| 09:11 (estimated) | Pipeline misconfiguration causes the deployment script to target blue instead of green. The `DEPLOY_ENV` variable was not explicitly set; the pipeline defaulted to the last-used environment, which was blue. |
| 09:11 (estimated) | Blue service is restarted as part of the deployment process. nginx continues routing traffic to blue. The proxy returns errors for approximately 48 seconds during the service restart window. |
| 09:12 (estimated) | Errors are visible on Nia's screen during the investor demonstration. |
| 09:12:48 (estimated) | Blue service restart completes. Health check passes. nginx resumes serving traffic correctly. |
| 09:13 (estimated) | Nia confirms to investors that the service has recovered. Demonstration continues. |
| 09:15 (estimated) | Amina identifies the root cause: `DEPLOY_ENV` was not set explicitly in the pipeline trigger. Post-incident review initiated. |

---

## Section 3: Root Cause

The pipeline was triggered without an explicit `DEPLOY_ENV` parameter. The deployment script (`deploy-app.sh`) requires `DEPLOY_ENV` to be set as an environment variable and has no default — however, the Jenkins pipeline configuration passed the value from a prior successful run through a retained workspace variable rather than requiring a fresh explicit input at trigger time. This allowed the pipeline to silently inherit `blue` as the target environment when the operator's intent was `green`.

The root cause is a specific configuration gap: **the Jenkins pipeline did not enforce explicit environment selection at trigger time**, and the deployment script did not validate that the selected environment was the idle (non-active) environment before proceeding.

---

## Section 4: Contributing Factors

**4.1 No pre-deploy active environment check**  
The deployment script did not check the current state of `/opt/kijanikiosk/.active-env` before deploying. A check of this file would have revealed that blue was the active environment and that deploying to blue would disrupt live traffic.

**4.2 No separation between deployment trigger and environment selection**  
The Jenkins pipeline combined environment selection and deployment execution in a single step with no confirmation prompt. An operator triggering the pipeline under time pressure (preparing for a demonstration) had no friction point at which to verify the target environment before execution began.

**4.3 Absence of a pre-deploy health check gate on the active environment**  
The pipeline had no step that confirmed which environment was currently serving live traffic and refused to proceed if the target matched the active environment. This gate, had it existed, would have caught the misconfiguration before any service disruption occurred.

**4.4 Timing pressure**  
The pipeline was triggered shortly before or during the investor demonstration, increasing the likelihood of a hurried trigger without full verification of the target environment.

---

## Section 5: What Went Well

**5.1 Recovery was fast and did not require external intervention**  
The blue service recovered automatically after the restart completed. No manual nginx reconfiguration was required and no data was lost. The 48-second window, while visible to investors, did not result in a prolonged outage or require escalation beyond the immediate team.

**5.2 The incident was contained to staging**  
The disruption affected the staging environment only. No production traffic was affected. The blast radius was limited to the investor demonstration session, which, while damaging to confidence, did not affect paying customers.

---

## Section 6: Action Items

**Action Item 1**  
**Owner:** Platform Engineering (Amina)  
**Description:** Add an active environment guard to `deploy-app.sh`. Before executing any deployment step, the script must read `/opt/kijanikiosk/.active-env` and exit with a non-zero status and a clear error message if `DEPLOY_ENV` matches the currently active environment. This prevents any deployment script execution from targeting the live environment without an explicit override flag.  
**Target completion:** End of Week 6

---

**Action Item 2**  
**Owner:** Platform Engineering (Amina) + Jenkins administrator  
**Description:** Refactor the Jenkins pipeline to require an explicit environment selection input parameter at every trigger. Remove all retained workspace variables that could carry over environment state between runs. The pipeline input form must present a dropdown with no pre-selected value, forcing the operator to make a deliberate choice before the pipeline will execute.  
**Target completion:** End of Week 6

---

**Action Item 3**  
**Owner:** Platform Engineering (Amina)  
**Description:** Add a pre-deploy confirmation step to the Jenkins pipeline that prints the current active environment, the selected deployment target, and a clear warning if the two match. This step must require a manual approval click before proceeding when the deployment is triggered within 30 minutes of a scheduled demonstration or production event. The list of scheduled events is read from a shared calendar integration.  
**Target completion:** End of Week 7

---

**Action Item 4**  
**Owner:** Tendo (Engineering Lead)  
**Description:** Establish a pre-demonstration checklist that includes verifying the active environment state file and confirming the idle environment is the deployment target before any pipeline is triggered during a customer-facing session. This checklist is a process control, not a technical one, and complements the script-level guards above. It must be completed and signed off by a second engineer before any demonstration begins.  
**Target completion:** Immediate — effective from next scheduled demonstration

---

*This review was conducted without blame. The root cause is a system design gap, not operator error. The action items above address the system, not the individual.*