# Lessons ####

What stuck, what surprised me, what I'd do differently. Written in own words — this is the document that makes the learning *retrievable* later.

Format per entry:

```
## YYYY-MM-DD — short title

**What I did:** one or two sentences

**What surprised me / what I got wrong:** the bit worth remembering

**How I'd explain it to a peer:** the 60-second version
```

---

_(entries start here)_

## 2026-05-01 — Phase 01: payment service + observability pipeline on EKS

**What I did:** I deployed an app on AWS and set up Datadog to monitor and troubleshoot it.

**What surprised me / what I got wrong:** The biggest issue was architecture mismatch — my Mac built an arm64 image, but EKS nodes required amd64, causing runtime failures. I also learned that Datadog traces can work even when logs don't, and log–trace correlation requires explicit log injection and agent log collection.

**How I'd explain it to a peer:** I built a FastAPI service, containerized it, and deployed it to EKS using Helm with images stored in ECR. Then I installed the Datadog agent to collect traces and logs, configured the app with the right environment variables, and enabled log injection. Finally, I verified everything by sending requests, checking logs, and confirming that logs and traces were linked via trace_id in Datadog.
