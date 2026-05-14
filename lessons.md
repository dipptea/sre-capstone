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

## 2026-05-05 — Phase 02: subshell captured a Terraform warning and silently broke Helm

**What I did:** I was passing the ACM certificate ARN to Helm using command substitution from `terraform output`, but Terraform was also printing a warning.

**What surprised me / what I got wrong:** The shell captured both the ARN and the warning text together, so Helm ended up receiving a corrupted value instead of a clean ARN. That caused the Ingress annotation for the certificate to be invalid, so the ALB couldn't properly attach the HTTPS certificate.

**How I'd explain it to a peer:** I fixed it by resetting the Helm values and passing a clean ARN manually. In the future, I'd suppress stderr or validate the output before passing it to Helm.

## 2026-05-06 — Phase 03: CI/CD pipeline with OIDC auth, --atomic rollback, and PR vs main triggers

**What I did:** I automated the deployment pipeline using GitHub Actions, AWS OIDC authentication, ECR, Helm, and EKS. I also validated both the successful deployment path and the failure rollback path.

**What surprised me / what I got wrong:** Learned that Helm `--atomic` can automatically roll back failed deployments while the old healthy pod continues serving users without downtime. Another thing I learned was the difference between `git` and `gh`: `git` manages code history locally (commit, branch, merge), while `gh` interacts with GitHub platform features like Pull Requests, GitHub Actions workflows, and workflow runs directly from the terminal. Also learned that pushing to a PR only runs the test job, while pushing to main runs the full deployment. OIDC providers create identity tokens, and AWS IAM roles only allow tokens from trusted providers like GitHub or EKS.

**How I'd explain it to a peer:** I built a GitHub Actions pipeline that automatically tests, builds, pushes Docker images to ECR, and deploys to EKS using Helm whenever code is pushed to the main branch. PRs only run validation tests for safety. I also intentionally broke the /health endpoint to simulate a bad deployment and verified that Kubernetes readiness probes failed, Helm automatically rolled back to the previous healthy version, and the public API continued working throughout the failure.

## 2026-05-07 — Phase 03b: Cross-service distributed tracing + warehouse-and-access-card sequencing

**What I did:** Added another microservice called `risk-check-service`. Both services have separate traces and deployments, but both Docker images used the same Git SHA because they were deployed from the same commit.

**What surprised me / what I got wrong:** Terraform infrastructure changes should be applied before triggering the application deployment pipeline, because the risk-check ECR repository and IAM permissions must already exist before GitHub Actions can successfully push the Docker image and deploy the service.

**How I'd explain it to a peer:** In this phase we expanded the application by adding another microservice called `risk-check-service`. This service can later be used for checking fraud risk, transaction risk, amount risk, location risk, or user risk, making the architecture more realistic for future failure-testing phases.

We created a separate service, Docker image, Helm chart, ECR repository, and GitHub Actions CI/CD pipeline for risk-check-service. Now, when payment-service files change, only the payment CI/CD pipeline runs, and when risk-check-service files change, only the risk-check pipeline runs. Both services can still share the same Git SHA when deployed from the same commit.

When a user sends a payment request, payment-service receives the request and internally calls risk-check-service inside EKS while sending the `payment_id`. If risk-check-service responds successfully, the response returns back to payment-service and then to the user. Datadog traces both services together, where payment-service appears as the parent span and risk-check-service appears as the child span in the distributed trace.

## 2026-05-09 — Phase 04: HA and scaling (HPA, PDB, probes)

**What I did:** Added HPA, PDB, and tuned startup/readiness/liveness probes on both payment-service and risk-check-service. Installed metrics-server. Verified PDB by draining a node. Verified HPA by load testing with `hey`. Verified end-to-end cross-service tracing in Datadog. Operational walk-through (commands, milestone-by-milestone) lives in `runbook.md`. This entry is the *concepts I learned*, the *failure modes*, and the *thinking* behind why Phase 04 looks the way it does.

---

### What I learned

**Scope both services why:** If only payment-service scales but risk-check-service stays single-pod, risk-check becomes the bottleneck. Example: payment-service scales to 10 pods but risk-check-service stays only 1 pod. Then all 10 payment pods still send traffic to the SAME single risk-check pod.

**HPA (Horizontal Pod Autoscaler):** automatically add/remove pods during load — that's what Deployment do? Example: `replicas: 2` always keep 2 pods running; Deployment creates a replacement pod. So normal traffic → 2 pods, high CPU/load → HPA changes Deployment to 5 pods, traffic drops → HPA reduces back to 2. **Deployment manages pods, but HPA changes how many pods Deployment should run.**

**PDB (PodDisruptionBudget):** keep enough pods alive during disruptions — disruption means something intentionally removes/stops pods. Without PDB: Kubernetes may stop too many pods together → application outage. With PDB: Kubernetes must keep minimum healthy pods running. `minAvailable: 1` → at least 1 pod must stay alive.

**How many pods minimum and maximum should exist?**
- min replicas = always keep at least this many pods
- max replicas = never scale above this number

**How many pods must stay alive during maintenance/disruptions?** `minAvailable: 1`.

**How Kubernetes checks pod health:**
- **Readiness probe:** Can this pod safely receive traffic? If health fails, remove pod.
- **Liveness probe:** Is the application frozen/dead? If liveness fails, Kubernetes restarts the container.
- **Startup probe:** Should Kubernetes wait longer before checking health? Yes — for slow-starting apps (like Java apps, large ML models, heavy startup apps).

**How quickly should scaling happen?** Traffic spike → add pods quickly. Scale down → wait before removing pods.

**How does Kubernetes know pod CPU usage?** metrics-server.

**At what CPU usage should Kubernetes create more pods?** Scaling is not instant. New pods take time to start.

**How do we generate traffic/load?** `hey` (increase CPU → trigger HPA → watch scaling happen).

**How high should max replicas be?** Based on CPU/memory allocated to node and pod resource requests. Since we have 2 t3.medium nodes with limited CPU/memory, max 6 per service is a safe starting point. If we set max too high, Kubernetes may try to create more pods than the nodes can fit, and extra pods will stay Pending.

**Should startup probes exist even though the app starts fast?** Yes. Startup probes are Kubernetes checks that give the application extra time to fully start before Kubernetes begins normal health checks. (Kubernetes immediately starts readiness/liveness checks.) If app starts slowly, health checks may fail too early → Kubernetes thinks app is broken → container gets restarted repeatedly. It also makes the chart more production-style for future slower apps.

```
Container starts
  startup runs FIRST and BLOCKS the other two from starting
  ↓ (once startup succeeds, it never runs again)
  readiness and liveness BOTH start, and run CONCURRENTLY for the rest of the pod's life
```

---

### Failure modes I learned

**metrics-server failure:** If metrics-server stops working, Kubernetes cannot see CPU usage. HPA scaling freezes because it has no metrics. Important because HPA fully depends on metrics-server.

**HPA target too low:** If CPU target is too small, HPA creates too many pods unnecessarily. Use balanced CPU target like 70%. Good practical lesson about over-scaling and wasted resources.

**HPA hits max replicas:** Traffic grows but HPA cannot scale beyond max replicas. Increase capacity or add more nodes later. Very realistic production failure mode.

**PDB too strict:** Kubernetes cannot drain nodes because PDB blocks eviction. Keep minAvailable reasonable. Good operational learning. Explains why maintenance can get stuck.

**PDB missing or too loose:** During maintenance all pods may disappear together. Use proper PDB to protect availability. Important because this is exactly what Phase 04 is trying to prevent.

**Startup probe too short:** Kubernetes kills the app before it fully starts. Give enough startup time budget. Good explanation of CrashLoopBackOff behavior.

Example:
- "Has the application finished starting yet?"
- 20 seconds to fully start
- But startup probe allows only 10 seconds
- Then Kubernetes thinks: app failed to start
- Result: container restarts again → fails again → endless restart loop
- **Startup probe protects app DURING BOOT.**

**Readiness probe too aggressive:** Healthy pods keep getting removed from traffic temporarily. Loosen timeout or thresholds. Very useful because intermittent 503s are difficult to debug in real systems.

Example:
- "Can this pod safely receive traffic?"
- Database response becomes slow for few seconds
- Readiness probe timeout is too strict: `timeoutSeconds: 1`
- Probe fails temporarily
- Kubernetes does NOT kill the pod
- Removes pod from Service traffic
- Then after recovery: adds pod back again
- **Readiness probe controls traffic AFTER app is running.**

**Liveness probe too aggressive:** Kubernetes keeps restarting pods even though the app is only temporarily slow. Liveness should only detect dead/frozen apps, not slow dependencies. **This is one of the most important Kubernetes lessons in the whole phase.**

**Pending pods:** HPA wants more pods but cluster nodes have no remaining CPU/memory. Add nodes or adjust resource sizing. Good real-world scaling limitation lesson.

---

### How to PROVE Phase 04 actually works

Use real command output and real observable evidence, not assumptions.

- **metrics-server validation:** Verify Kubernetes can see CPU/memory metrics. Run `kubectl top` commands and confirm metrics appear successfully.
- **Probe validation:** Verify startup, readiness, and liveness probes are deployed and working correctly. Use `kubectl describe pod` and `kubectl get events` to confirm probes exist and are healthy.
- **HPA validation:** Verify autoscaling is configured correctly and actively reading CPU metrics. Check `kubectl get hpa` and confirm CPU values appear instead of `<unknown>`.
- **PDB validation:** Verify PodDisruptionBudget exists and matches the correct Deployment labels. Check selectors carefully so PDB actually protects the intended pods.
- **PDB drain validation (M4b):** Verify node draining does not take the entire service down. Drain a node and confirm endpoints, curl responses, and disruption counts remain healthy.
- **HPA load validation (payment only):** Verify payment-service scales up and down correctly during load. Generate traffic and watch HPA replicas increase and later scale back down.
- **End-to-end validation (both services):** Verify payment-service and risk-check-service scale together under load. Use Datadog traces and latency metrics to confirm scaling works across both services.
- **Documentation and learning validation:** Verify architecture docs, lessons learned, and operational understanding are updated. Do not close the phase until documentation and verbal/visual recall are completed.
- **5xx during scale-up validation:** Allow brief scale-up 5xx if documented in lessons.md as a learning observation.
- **Datadog UI validation:** Keep Datadog UI checks because distributed tracing is a major learning outcome of the phase.

---

### Comprehension checkpoints I should be able to answer at /phase-close

User should explain the behavior, failure modes, and reasoning **without notes** during `/phase-close`.

- **Predict:** Explain how long HPA scaling takes and why scaling is not instant. Walk through metrics-server scrape, HPA reconcile, scheduler, startup probe, and readiness timing step-by-step.
- **Failure-mode:** Explain how a bad liveness probe design can create a restart cascade outage. Focus on the architectural fix (do not make liveness depend on downstream services).
- **Explain-back:** Explain why min replicas must be at least 2 for true HA. HPA reacts AFTER load/problems happen, but HA requires another healthy pod already running immediately.
- **Counterfactual:** Explain what changes if HPA target CPU is 50% instead of 70%. Compare idle cost, scaling aggressiveness, and sustained-load behavior to understand trade-offs.
- **Connection:** Explain the common HA idea shared between PDB and ALB healthy targets. Both try to ensure at least one healthy backend stays available, but they protect against different failure types.
- **Real-world:** Connect the liveness/restart-cascade lesson to real production experience. Explain an actual incident where dependency slowness caused cascading failures and what permanently fixed it.

Keep the framing strict because long-term design fixes matter more than temporary threshold tuning. Phase 04 is teaching operational thinking, not only Kubernetes commands.

---

### Open questions I tracked during the phase

Real uncertainties that can only be answered during implementation/testing.

- **Helm chart packaging:** Should HPA and PDB live inside each service chart or in one shared HA chart? → Kept them inside each service chart for simplicity and easier ownership.
- **metrics-server TLS:** Does metrics-server need insecure TLS flags on EKS? → Tested `kubectl top nodes` after M1; flag NOT needed.
- **Idle CPU usage:** What is real idle CPU usage before finalizing HPA behavior? → 3m on payment, 3m on risk-check. Way below the 100m request — flagged for M6 load test tuning.
- **`hey` load-test tuning:** How aggressive should the load test be? → Started with `-c 50 -z 5m`. Triggered scaling almost instantly because CPU went to 488% of request.

---

### Surprises that became real lessons

- **`--reuse-values` had two effects, not one.** I removed it in M2 to fix a `nil pointer evaluating interface {}.startup` error. What I didn't realize: it was ALSO preserving `ingress.enabled=true` from Phase 02's original install. When I removed it, Helm reverted to chart defaults (`ingress.enabled: false`) and silently deleted the Ingress and the public ALB. CI/CD didn't fail because deletion isn't a deployment failure. Future me will never trust `--reuse-values` again — commit configuration to `values.yaml` instead of relying on prior-release state.

- **Terraform data sources don't auto-refresh after cluster-side changes.** When the new ALB was created, the Route 53 record (managed by Terraform via `data "aws_lb" "payment"`) still pointed at the OLD deleted ALB's DNS name. NXDOMAIN. Running `terraform apply` updated the alias and DNS started working. Any Terraform-managed resource that depends on cluster-created infra (LBC ALBs, IRSA roles) needs a `terraform apply` after the cluster-side change.

- **PDB protects against eviction, not against in-flight request loss.** During M4b drain, PDB worked perfectly. But the curl loop captured ~5 brief 502 errors during the eviction window. PDB doesn't address the asymmetry between Service endpoint removal (instant) and ALB target de-registration (seconds). The fix is `preStop` lifecycle hook + `terminationGracePeriodSeconds`, deferred to Phase 05.

- **Liveness should test the process, not the dependencies.** If `/health` calls a downstream service, a slow downstream causes liveness to fail → kubelet restarts the pod → replacement pod also can't reach downstream → restart cascade across the entire Deployment. The cure makes the disease worse. Always make liveness in-process only.

- **Always uncordon after drain.** I forgot to run `kubectl uncordon` after M4b. The cluster ran with halved scheduling capacity for ~2 hours before I noticed. Treat `drain → uncordon` as a coupled pair.

- **HPA scale-up was instantaneous, not slow.** Expected 30-90s. Actually scaled 2 → 6 (MAX) in ~12 seconds because the CPU request was so undersized that any real load instantly crossed the threshold. HPA target % is measured against the request, not absolute CPU.

- **Helm chart version vs app version are independent.** Pinning chart version 3.12.2 transitively pins app version 0.7.2. Charts can change without the app changing (chart 3.10.0 and 3.9.0 both ship app 0.6.3). Terraform only knobs the chart — app version is downstream.

- **Datadog Live Search vs Indexed retention.** Trial accounts only retain ~15 minutes of trace data in Live Search. Past that → empty. Generated fresh traces with a small `hey -z 30s` burst when needed.

---

**How I'd explain it to a peer:** Phase 04 was about making both services *survive disruption and grow with load*, while keeping the cross-service request chain intact. Three primitives — probes (startup/readiness/liveness), HPA, PDB — each answers a different question. Probes tell Kubernetes when a pod is booting, ready for traffic, or wedged. HPA scales the Deployment up under load and back down when load drops. PDB prevents Kubernetes from evicting too many pods at once during voluntary disruption. The biggest single lesson wasn't any one primitive — it was the chain of unintended consequences from `--reuse-values` silently breaking the public endpoint, and the architectural rule that liveness must test the process not the dependencies. Both are the kind of failure mode that takes a 2am incident to learn the first time, and I learned both without one.

---

### Known gaps accepted at phase close (deferred to Phase 05)

**Gap 1 — brief 502 errors during drain test**

During the node drain test, Kubernetes removed pods correctly and PDB protected availability.

But for a few seconds: ALB was still sending traffic to a pod that was shutting down.
Result: 5 temporary 502 errors occurred. This is called a graceful shutdown gap.

System mostly worked correctly, but shutdown handling needs improvement later using:

- `preStop` hooks
- `terminationGracePeriodSeconds`

**Gap 2 — p99 latency too high during heavy load**

During autoscaling tests:

- payment-service scaled correctly
- risk-check-service scaled correctly
- traces worked correctly

But p99 latency became: 5.41 seconds
instead of the desired: under 2 seconds

Reason:

CPU requests were too low: Requested: 100m
Actual usage: ~488m
So HPA thought traffic was much heavier than expected and aggressively scaled to max pods.

## 2026-05-12 — Phase 05: Chaos drills + graceful-shutdown closure + a real Helm/HPA bug fix

**What I did:**

M1: We added graceful shutdown config — preStop sleep and terminationGracePeriodSeconds — to both payment-service and risk-check-service Deployments. Initially set preStopSleep: 10, retried as preStopSleep: 15 after the first drain test left 1 × 502. With sleep 15, retested with zero 502s.

M2: We killed payment pods and risk-check pods using `kubectl delete pod` while live `/pay` traffic was flowing. After the first /pay test showed 1 × 502, we ran a control test (no kill, same load — zero failures) and a /health test (with kill, no cross-service path — zero failures across 39,833 requests). That isolated the remaining residual 502 as a cross-service in-flight race, not a Kubernetes shutdown issue. Deferred to Phase 06.

M3: We redistributed pods across both worker nodes, then terminated one EC2 worker node using `aws ec2 terminate-instances`. We watched nodes, pods, traffic, HPA recovery, and replacement node creation, and confirmed EKS recovered automatically.

M4: We attempted a bad image deploy via `helm upgrade --set image.tag=nonexistent-deadbeef`. Instead of the expected ImagePullBackOff, we discovered a Helm + HPA Server-Side Apply conflict on `.spec.replicas`. We fixed the chart (conditionally omit `replicas:` when HPA is enabled), committed, pushed, verified CI/CD, then re-ran M4. Final result: ErrImagePull → ImagePullBackOff → Helm `--atomic` rollback → healthy pods restored → 0 user errors.

**What surprised me / what I got wrong:**

M1 surprise: preStopSleep: 10 improved the drain issue but still gave 1 × 502. Expected: 0 errors. Actual: 1 × 502.

M2 surprise (pod kill): Even with graceful shutdown working, /pay still showed 1 × 502 during pod kill. Then /health showed 0 errors out of 39,833 requests. So the surprise was: the remaining 502 was not Kubernetes/ALB shutdown — it was likely the /pay → /check cross-service path.

M3 surprise (EC2 terminate): EKS replaced the failed node very fast. Expected: maybe 3–5 minutes. Actual: replacement node Ready very quickly (~13 seconds). Also, node failure produced mixed errors: 500, 502, 504.

M4 surprise: The broken image test did NOT fail first with ImagePullBackOff. Instead, it first failed because of Helm + HPA conflict on `.spec.replicas`. This exposed a real production bug.

**How I'd explain it to a peer:**

First, we implemented graceful shutdown improvements for both services by increasing preStopSleep from 10 seconds to 15 seconds and configuring terminationGracePeriodSeconds. The goal was to prevent the ALB from routing traffic to pods that were already shutting down or being drained during rolling updates and pod termination.

Next, we performed a pod-kill drill. During live /pay traffic, we intentionally deleted a payment-service pod. We observed a single 502 error during the test. To determine whether the issue was caused by Kubernetes/ALB shutdown behavior or by the application dependency flow, we ran additional validation tests. We generated traffic against /health while deleting pods again, and this produced zero failures. That confirmed the graceful shutdown logic was working correctly and the earlier 502 was most likely related to the /pay → risk-check-service cross-service request path during in-flight shutdown.

After that, we performed a node failure drill by forcefully terminating an EC2 worker node participating in the EKS cluster. During the test, we continuously monitored nodes, pods, autoscaling behavior, replacement node creation, and live /pay traffic using hey. EKS successfully replaced the failed node automatically, and Kubernetes rescheduled workloads onto healthy nodes. During the disruption window, we observed mixed application and infrastructure errors including 500, 502, and 504 responses, which is expected during hard node failures because pods disappear abruptly without graceful draining.
