# Decisions log

Decisions get logged here as they're made. Open questions sit at the top until resolved.

## Open

_(none currently)_

## Resolved

- **2026-04-28: Service language → Python.** Reason: faster to write than Node.js for FastAPI; the service is a trace target, not the lesson. Both work with Datadog APM.
- **2026-04-28: Terraform module strategy → official modules** (`terraform-aws-modules/vpc/aws`, `terraform-aws-modules/eks/aws`). Reason: real P-SRE work is reading and modifying existing modules, not reinventing EKS. Reinventing would eat a week with no learning payoff.
- **2026-04-28: NAT Gateway topology — staged.** Phase 1 uses **1 shared NAT GW** (~$33/mo, single egress failure point). **Phase 5 adds a 2nd NAT GW per AZ** as part of the failure-injection drill — run the NAT-down scenario with the shared NAT first (observe full egress collapse), then upgrade and rerun (observe AZ-isolated failure). Reason: cheaper through Phase 4, AND turns Phase 5's drill into an A/B resilience comparison instead of a one-shot. The Terraform refactor to add the second NAT is itself part of the learning.

- **2026-04-28: AWS authentication strategy — identity-based + short-lived across all three layers.**
  - **Humans (Phase 1+):** AWS IAM Identity Center (account-level instance), `aws sso login` for ~12-hour STS sessions. **No long-lived IAM access keys** on laptops.
  - **CI/CD (Phase 3+):** GitHub Actions OIDC federation to an IAM Role. **No GitHub Secrets holding AWS keys.** GHA's OIDC token is exchanged at job start for short-lived AWS creds.
  - **In-cluster workloads (whenever first needed, likely Phase 2 with AWS Load Balancer Controller, or earlier if Datadog AWS integration is added):** IRSA — Kubernetes ServiceAccount mapped to IAM Role via OIDC. No node-wide IAM credentials shared across pods.

  Reason: long-lived IAM access keys are the #1 source of AWS breach incidents per AWS's own incident reports; identity-based + STS is the modern best practice across mature shops; setting it up *now* (rather than retrofitting after the first phase ships) builds the muscle and prevents accidental key creation from becoming a habit.

- **2026-05-06: CI/CD tool → GitHub Actions** (over Jenkins). Reason: code already lives in [github.com/dipptea/sre-capstone](https://github.com/dipptea/sre-capstone), zero new infrastructure to provision (no Jenkins server to maintain), native OIDC federation to AWS (per the auth-strategy decision above), and free for public repos at this scale. Jenkins would have added a long-running EC2 instance + ongoing maintenance overhead with no learning benefit for the capstone's specific goals. Concepts transfer cleanly between GHA and Jenkins for future work — pipeline-as-code patterns are nearly identical. Implemented and validated end-to-end in Phase 03 (M1–M7), including a deliberate broken-deploy that auto-rolled-back via `helm --atomic`.

Format for new entries:
```
- YYYY-MM-DD: Picked X over Y. Reason: Z.
```
