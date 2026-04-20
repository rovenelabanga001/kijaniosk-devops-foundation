# Fault Injection Log — KijaniKiosk Payments Pipeline

## Summary
Each stage was faulted independently. After confirming the observed behaviour, the fault was removed and the pipeline restored to green before the next fault was introduced.

---

## Fault Injection Table

| Stage Faulted | Fault Introduced | Stages That Ran | Stages Skipped | Post Conditions | Observed? |
|---|---|---|---|---|---|
| Lint | Syntax error added to `src/index.js` (`this is not valid javascript???`) — ESLint parsing error on line 1 | Lint (failed) | Build, Verify (Test + Security Audit), Archive, Publish | `changed` and `failure` blocks ran, `cleanWs()` executed | Y |
| Build | Invalid flag in build script (`cp --invalid-flag`) in `package.json` | Lint (passed), Build (failed) | Verify (Test + Security Audit), Archive, Publish | `changed` and `failure` blocks ran, `cleanWs()` executed | Y |
| Test (in Verify) | | | | | |
| Publish | | | | | |

---

## Design Rationale

### Lint
Placing Lint before Build ensures that code quality failures are caught at the cheapest possible point in the pipeline — before dependencies are installed or compiled output is produced. A syntax error that ESLint catches in seconds should never consume the time and resources of a full build.

### Build
The build output verification step confirms the pipeline fails at the correct stage when the build produces no output, rather than propagating a confusing failure into the test stage. Failing at Build with a clear error message is faster to diagnose than a missing module error in Test.

### Test (in Verify)
_To be completed after fault 3._

### Publish
_To be completed after fault 4._
