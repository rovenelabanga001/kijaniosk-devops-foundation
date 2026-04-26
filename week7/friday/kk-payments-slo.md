# KijaniKiosk Payments — SLI and SLO Definition Document

**Service:** kk-payments  
**Owner:** Platform Engineering  
**Measurement window:** 30 days (rolling)  
**Last updated:** 2026-04-26  
**Audience:** Engineering, Nia (executive sponsor), Board

---

## 1. Service Level Indicators (SLIs)

### SLI-1: Availability

**What it measures:** The proportion of HTTP requests to the kk-payments `/health` endpoint that return a `200 OK` response with `"status": "ok"` within the measurement window.

**Data source:** nginx access logs on the kk-nginx container, filtered to requests targeting the kk-payments upstream.

**Calculation:**
```
Availability = (successful_requests / total_requests) × 100

Where:
  successful_requests = requests returning HTTP 200 with "status":"ok"
  total_requests      = all requests received by kk-payments upstream
```

**Measurement window:** Every 5 seconds during active monitoring; aggregated over 30 days for SLO reporting.

---

### SLI-2: Latency

**What it measures:** The proportion of kk-payments HTTP requests that complete within 500 milliseconds, measured from request receipt at nginx to response delivery.

**Data source:** nginx `$request_time` variable in access logs, sampled continuously.

**Calculation:**
```
Latency SLI = (requests_under_500ms / total_requests) × 100

Where:
  requests_under_500ms = requests with $request_time < 0.5s
  total_requests        = all requests in the measurement window
```

**Measurement window:** 30-day rolling window, reported as a percentile distribution (p50, p95, p99).

---

### SLI-3: Payment Error Rate

**What it measures:** The proportion of payment processing requests that complete without a server-side error (HTTP 5xx response), indicating the payment logic itself is functioning correctly.

**Data source:** nginx access logs filtered to payment processing endpoints (`/api/payments/*`), counting non-5xx responses as successes.

**Calculation:**
```
Error Rate SLI = (non_5xx_requests / total_payment_requests) × 100

Where:
  non_5xx_requests       = payment requests returning HTTP 200–499
  total_payment_requests = all requests to /api/payments/* endpoints
```

**Measurement window:** 30-day rolling window.

---

## 2. Service Level Objectives (SLOs)

| SLI | Target | Measurement Window | Minimum Threshold |
|-----|--------|-------------------|-------------------|
| SLI-1: Availability | ≥ 99.9% of requests return healthy response | 30 days rolling | 99.5% before alert escalation |
| SLI-2: Latency | ≥ 95% of requests complete within 500ms | 30 days rolling | 90% before alert escalation |
| SLI-3: Payment Error Rate | ≥ 99.5% of payment requests return non-5xx | 30 days rolling | 99.0% before alert escalation |

**Rationale for 99.9% availability target:** At 50,000 requests per hour, 99.9% availability permits a maximum of 50 failed requests per hour, or approximately 3 minutes and 36 seconds of total downtime per month. This aligns with Tendo's stated requirement that automated rollback must fire within 90 seconds to limit blast radius.

---

## 3. Rollback Threshold Table

The following thresholds apply during the post-deploy monitoring window (default: 60 seconds after a traffic switch). These are short-window thresholds, not the 30-day SLO targets — they are intentionally more aggressive because a deployment fault compounds rapidly.

| SLI | 30-day SLO Target | Rollback Threshold | Window | Relationship to SLO |
|-----|------------------|--------------------|--------|---------------------|
| SLI-1: Availability | 99.9% | 3 consecutive health check failures | 5-second checks over 60s window | A single bad deployment minute equates to ~833 failed requests at peak load. Three consecutive failures (15 seconds) is the earliest reliable signal that distinguishes a real fault from transient noise. |
| SLI-2: Latency | 95% under 500ms | Not currently automated | Post-deploy window | Latency degradation requires baseline comparison data not yet instrumented. Planned for Week 8. |
| SLI-3: Payment Error Rate | 99.5% non-5xx | Not currently automated | Post-deploy window | Payment endpoint monitoring requires application-level instrumentation beyond nginx logs. Planned for Week 8. |

**Current automated rollback:** Triggered by SLI-1 only — 3 consecutive health check failures on the nginx proxy within the post-deploy monitoring window. In the Friday project demonstration, this fired in **33 seconds** from fault introduction to confirmed rollback.

---

## 4. What We Do Not Commit To

The following metrics are explicitly outside the scope of this SLO document. Each exclusion is intentional, not an oversight.

**4.1 Third-party payment processor availability**  
kk-payments depends on an external payment processor API. If that processor experiences downtime, kk-payments requests will fail regardless of the health of our infrastructure. We do not commit to end-to-end payment success rate because a portion of that rate is outside our control. We commit only to the availability of the kk-payments service itself.

**4.2 Client-side network latency**  
The latency SLI measures response time at the nginx boundary. Network transit time between nginx and the end user's device varies by geography, ISP, and device and is not within the platform engineering team's control. Latency reported in this document is server-side only.

**4.3 Data correctness of payment records**  
This SLO covers service availability and response time. It does not cover whether individual payment transactions are recorded correctly in the database. Data correctness is governed by a separate data integrity policy and is not measurable through HTTP response codes alone.

**4.4 Staging environment availability**  
The SLO targets above apply to the production environment only. The staging environment (kk-api-blue / kk-api-green on the dev13 host) is a deployment target for testing and demonstration. It has no availability commitment and may be intentionally disrupted during blue/green switch testing and fault injection exercises.

---

*This document is a living definition. Thresholds will be reviewed after each incident and revised when instrumentation improves. The Week 8 migration to containerised deployments will expand automated rollback coverage to SLI-2 and SLI-3.*