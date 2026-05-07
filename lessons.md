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
