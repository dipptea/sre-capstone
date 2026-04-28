# Decisions log

Decisions get logged here as they're made. Open questions sit at the top until resolved.

## Open

### CI/CD: GitHub Actions vs Jenkins
Pick one, not both. Default to **GitHub Actions** unless the new employer is Jenkins-heavy (common in healthcare/finance/enterprise). Jenkins concepts transfer trivially from GHA.
- [ ] Resolved: _______

### Service language: Node.js vs Python
Pick whichever is faster to write in. Both work fine with Datadog APM. Services should be boring.
- [ ] Resolved: _______

### Terraform: official modules vs from-scratch
**Strong recommendation: official modules** (`terraform-aws-modules/vpc/aws`, `terraform-aws-modules/eks/aws`). Real P-SRE work is reading and modifying existing modules, not reinventing EKS. Reinventing eats a week.
- [ ] Resolved: _______

## Resolved

_(empty — log decisions here as they're made, with date and one-line reason)_

Format:
```
- YYYY-MM-DD: Picked X over Y. Reason: Z.
```
