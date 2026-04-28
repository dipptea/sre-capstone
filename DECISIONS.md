# Decisions log

Decisions get logged here as they're made. Open questions sit at the top until resolved.

## Open

### CI/CD: GitHub Actions vs Jenkins
Pick one, not both. Default to **GitHub Actions** unless the new employer is Jenkins-heavy (common in healthcare/finance/enterprise). Jenkins concepts transfer trivially from GHA. Not blocking until Phase 3.
- [ ] Resolved: _______

## Resolved

- 2026-04-27: **Service language = Python 3.12 + FastAPI.** Reason: `ddtrace` (Datadog Python tracer) is mature; FastAPI is small and quick to instrument. Service code is not the learning bottleneck. (Resolved during Phase 1 spec walkthrough.)
- 2026-04-27: **Terraform = official modules** (`terraform-aws-modules/vpc/aws` v5.x, `terraform-aws-modules/eks/aws` v20.x). Reason: real P-SRE work is reading/modifying existing modules, not reinventing them. Reinventing EKS eats a week without learning value. (Resolved during Phase 1 spec walkthrough.)

Format:
```
- YYYY-MM-DD: Picked X over Y. Reason: Z.
```
