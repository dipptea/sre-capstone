# Runbook

Operational reference. Grown as the system grows. Written in own words — copy-pasted commands without context don't help in an incident.

> **Looking for "what's currently running and what it costs"?** That lives in [`INVENTORY.md`](INVENTORY.md), not here. This file is *how to operate*; INVENTORY is *what is provisioned*.

Sections to fill in as we go:

## Deploy from zero

_(Phase 1 — to be written after the first cluster is up. Should describe how a fresh engineer would bring the system up from an empty AWS account, in your own words.)_
aws configure sso

aws sso login --profile capstone-admin, export AWS_PROFILE=capstone-admin

Create / Connect to EKS - connects your local machine to your EKS cluster so you can use kubectl.

Build Docker Image - Mac builds ARM, EKS needs AMD64. Builds a Docker image for Linux (amd64), and loads it locally with a tag.

Push to ECR - Upload the Docker image to AWS ECR so the Kubernetes cluster can pull and run it.

Install Datadog (Helm)
Deploy the Datadog Agent in the cluster to collect metrics, logs, and traces.

Enable Logs (important)
Turn on log collection in Datadog so application logs are sent to the platform.

Deploy App (Helm)
Install or update the application in Kubernetes using the Docker image from ECR.

Required Env Variables (CRITICAL)
Set Datadog variables so the app can send traces and link logs with traces.

Restart Pods
Recreate pods to apply new configurations and ensure changes take effect.

Test Application
Send requests to the app endpoints to verify it is working and generating data.

Verification Checklist
Check that the app runs, logs appear in Datadog, traces are visible, and both are linked correctly.


## Common operations

_(kubectl shortcuts, Datadog dashboard links, AWS console deep-links)_

## Incident playbooks

_(one section per failure mode, populated during failure-injection phases)_

- [ ] Pod crashloop
- [ ] Node drained / unschedulable
- [ ] Image pull failure
- [ ] DB latency spike
- [ ] Downstream service slow
- [ ] WAF blocking legitimate traffic
- [ ] Datadog agent not reporting

## Useful queries

_(PromQL, Datadog APM filters, log queries — populated as discovered)_
