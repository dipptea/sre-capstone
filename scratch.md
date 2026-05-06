# Scratch

Freeform notes — random thoughts, half-formed ideas, links to investigate, "huh, that's weird" moments, questions to come back to. **No format required. No enforcement.** Pollute freely.

When an entry here matures into something you'd struggle to explain to a peer (the test in `lessons.md`), promote it: rewrite it in the three-field format and move it to `lessons.md`. `/phase-close` will prompt you to walk through this file and consider promotions before closing the phase.

Keep entries dated so you can spot which thoughts are stale. A single line is fine. Five-line ramble is fine. Bullet list is fine.

---

Trace alone tells you: request hit gateway → called payment-service → payment-service span took 4.2s → returned 500.
Logs alone tell you: somewhere on a pod, around 14:03:22, a log line says payment_id=abc rejected: db connection timeout after 4000ms.
Correlation = the trace_id is stamped into that log line. You click the slow span in Datadog APM and it shows you that exact log line without you grepping by timestamp across N pods.
When/where - Trace
what/why - log


2026-05-06 — Phase 03 M5: opened this PR to verify PR trigger runs test job only (no build, no deploy).
