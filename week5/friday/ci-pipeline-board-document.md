# KijaniKiosk Payments Pipeline: How We Protect Every Release

**Prepared for:** Board Review
**Prepared by:** Rovenel Abanga, Engineering Team
**Date:** April 2026

---

## The Problem We Solved

Before this system existed, a developer could write code, save it to our shared codebase, and have that code reach our payments infrastructure without anyone — or anything — checking whether it actually worked. In a financial services platform, that is an unacceptable risk. A single broken change could mean failed transactions, incorrect refunds, or worse, a vulnerability that exposes customer payment data.

This pipeline is our answer to that problem. It is an automated quality checkpoint that sits between a developer saving their work and that work becoming a deployable version of our payments service.

---

## What Happens When a Developer Saves Their Work

Every time a developer saves a change to the shared codebase, the following sequence runs automatically — no human intervention required.

| Stage | What It Does | What It Confirms |
|---|---|---|
| **Lint** | Reads the code before anything else runs | The code is written correctly and follows our team standards |
| **Build** | Assembles the payments service from source files | The code can be compiled into a runnable service |
| **Test** | Runs our suite of automated checks against the built service | The payments service behaves correctly: payments process, refunds calculate, receipts generate |
| **Security Audit** | Scans every software component the service depends on | No known security vulnerabilities exist in our dependencies |
| **Archive** | Saves a verified copy of the built service | A retrievable, tamper-evident record of this exact version exists |
| **Publish** | Sends the verified version to our secure software registry | The approved version is available for deployment, labelled with its exact source commit |

The entire sequence takes under ten minutes from the moment a developer saves their work.

---

## What Happens When Something Goes Wrong

The pipeline is designed around a simple contract: a version of the payments service that has not passed every check will never reach our registry. This is enforced automatically, not by policy.

If the code has a formatting or syntax problem, the pipeline stops at the first stage. The build never runs. No time is wasted.

If the code builds but the automated payment tests fail, the pipeline stops before archiving or publishing. The broken version is never recorded as an approved release. The developer receives an immediate notification with a direct link to the failing check.

If a security vulnerability is found in one of our dependencies, the pipeline stops before the service is published, regardless of whether all other checks passed. A service with a known vulnerability does not leave our build system.

In every failure case, the developer knows within ten minutes exactly which check failed and why. The fix is made, the change is saved again, and the pipeline runs from the beginning. No broken version ever reaches the point where it could be deployed.

---

## How Versions Are Tracked

Every version published to our registry carries a label combining two pieces of information: the version number from our release plan, and the exact code change that produced it. A version labelled `1.0.0-2cb9368` can be traced back to a specific moment in our development history. If a problem is discovered in production, we can identify exactly what changed, when, and who made the change.

This traceability is not optional in financial services. It is the foundation of our audit capability.

---

## What This Pipeline Does Not Yet Do

This pipeline verifies that the payments service works correctly in isolation. It does not yet verify that it works correctly when connected to our other services — the inventory system, the customer database, or the notification layer. That level of testing, called integration testing, is the next addition to this system. The pipeline also does not yet automatically deploy a verified version to our staging environment; that step currently requires a manual trigger. Automating deployment is planned for the next phase of this work.