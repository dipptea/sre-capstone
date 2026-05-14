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


## Deploy Phase 02 — public HTTPS via ALB

Domain created
SSO → login to AWS (https://d-90660a04eb.awsapps.com/start/#/)
→ Route 53 → register domain
→ verify email
→ hosted zone created

Create Certificate
Domain already exists in Route 53 Terraform → finds the hosted zone (domain details)
Terraform → asks ACM "Create a certificate for payment.payservice.click"
ACM creates the certificate (NOT issued yet) → returns a DNS CNAME for validation
Terraform takes that CNAME → creates it in Route 53
ACM checks DNS: "Does this CNAME exist?" → Yes → proves you own domain
ACM marks certificate = ISSUED
Terraform waits until this happens → then outputs the certificate ARN
ALB/Ingress → uses cert ARN for HTTPS

Subnet tagging
Create 2 public and 2 private subnets in vpc.tf

Install the AWS Load Balancer Controller (with IRSA).
1. IAM policy for AWS Load Balancer Controller
2. IAM role trusted by EKS OIDC provider
3. Kubernetes ServiceAccount annotated with IAM role ARN
4. Helm release for aws-load-balancer-controller in kube-system

Note:
helm install aws-load-balancer-controller pod
IRSA = give AWS permissions to LBC pod
OIDC = identity bridge between Kubernetes and AWS IAM

LBC Pod + IRSA
→ uses ServiceAccount
→ ServiceAccount linked to IAM role (IRSA)
→ IAM role has permissions (ELB, EC2)
→ LBC can create ALB in AWS

If IRSA is not there and we are applying AWS access key + secret key in environmental variables in pod:
Old way: Static keys → shared → risky ❌, static keys live until you manually replace them
IRSA: Temporary creds → per pod → secure ✅, auto-rotation of keys

OIDC is used so AWS can trust the LBC pod's identity
→ allowing it to assume an IAM role
→ so it can call AWS APIs (ELB, EC2)
→ and create ALB + target groups

IRSA trust policy includes: namespace + service account name
Only that exact namespace + SA can assume the role

depends_on in datadog.tf — "Terraform, wait for these resources to finish BEFORE creating this one" (force Terraform to run things in correct order)

Payment Service Healthy
kubectl get svc,pods -n payment
Service/payment → ClusterIP on port 80 ✅
Pod/payment → 1/1 Running ✅

Ingress
Ingress YAML
→ LBC reads it
→ LBC calls AWS
→ AWS creates:
   ✔ ALB
   ✔ Target Group
   ✔ Listeners (80, 443)
   ✔ Routing rules

Route 53 alias record
ACM certificate created by Terraform used by ALB

Alias record
without alias user must use — https://k8s-payment-xxxx.elb.amazonaws.com ❌
with alias users can just use — https://payment.payservice.click ✅

Note

Why Alias is cheaper
User → DNS query → Route 53 → charged (Every request costs money, CNAME → paid)
User → Route 53 → internally resolves to ALB → FREE (AWS doesn't charge for this lookup, Alias → free (for AWS targets))

CNAME at Root Domain
payservice.click → CNAME → ALB ❌

CNAME rule:
"If a name has a CNAME, it cannot have ANY other records"
But root domain says:
"I MUST have NS + SOA" → conflict ❌

Why subdomains work
payment.payservice.click → ALB
No required NS/SOA at that level

Root domain cannot use CNAME because it must contain NS and SOA records, and DNS does not allow CNAME to coexist with other records.
Subdomains can use CNAME because they don't require NS and SOA records at that level.

End-to-end HTTPS verification
DNS works → HTTPS works → ALB routes correctly → pod responds → Datadog sees it

## Deploy Phase 03 — CI/CD pipeline (push to main → deployed)

Add GitHub Provider
We are adding a GitHub OIDC provider in AWS alongside the existing EKS OIDC provider.
EKS OIDC is for pods; GitHub OIDC is for pipelines.

EKS OIDC provider → lets EKS pods use IAM roles through IRSA
GitHub OIDC provider → lets GitHub Actions use IAM roles for CI/CD

Step 1: We are verifying that we are connected to the correct AWS account using the correct AWS profile before making infrastructure changes.

Step 2: Verify — Who am I currently authenticated as? Verify: correct AWS account, correct IAM role, valid login/session.

Example:
Account: 591316258137 ✓ (capstone-sre-v2)
Role: AWSReservedSSO_CapstoneAdmin_5211c2f501907eff ✓ (CapstoneAdmin)
Token: fresh ✓

Step 3: GitHub OIDC provider in AWS
Download and use the TLS provider plugin from HashiCorp.
Check which Helm provider version Terraform is actually using: Helm provider v2 and v3 use different syntax.

Added Terraform resource: `aws_iam_openid_connect_provider.github`

Step 4: Register GitHub as a trusted OIDC token issuer in AWS IAM
`terraform init` / `plan`
`terraform plan -out=tfplan`

Verify 2 providers: `aws iam list-open-id-connect-providers --profile capstone-admin`

Step 5: Give the GitHub Actions IAM role permission to access and manage the EKS Kubernetes cluster.

Created EKS access entry for `gh-actions-deployer`. Attached `AmazonEKSClusterAdminPolicy` to that role.
GitHub Actions IAM role
→ can now authenticate to the EKS cluster
→ can use Kubernetes API
→ can run Helm deployments
GitHub Actions can now build, push, and deploy the payment app to EKS.

Confirm that the GitHub Actions deployer role was successfully added to EKS access control.

Step 6: `deploy.yaml` creates an automated CI/CD pipeline that tests the app, builds and pushes a Docker image to ECR, then deploys it to EKS using Helm with automatic rollback on failure.

Step 7: In Browser — https://github.com/dipptea/sre-capstone/actions
GitHub detected your push to main → automatically started the Deploy payment-service workflow:
Workflow #1 → first pipeline run after adding deploy.yml
Workflow #2 → second push/commit triggered another pipeline run

Phase 03 M4: first push: GitHub Actions workflow + pytest smoke test (Creates the robot — GitHub Actions pipeline)
Phase 03 M1–M3: second push: GitHub OIDC provider + IAM Role + EKS access (Gives the robot an AWS identity + permissions)
First push created the CI/CD pipeline, and the second push gave the pipeline an AWS IAM identity and permissions to access and deploy to the EKS cluster.

Step 7 (verification commands):

```
aws ecr describe-images --repository-name payment-service --profile capstone-admin --region us-east-1 --query 'imageDetails[*]'
```
(Verify that the GitHub Actions pipeline successfully built and pushed new Docker images to ECR.)

```
helm history payment -n payment
```
(Verify that the GitHub Actions pipeline successfully performed Helm deployments to the EKS cluster.)

```
kubectl get pods -n payment -o jsonpath='{.items[*].spec.containers[*].image}{"\n"}'
```
(Verify which Docker image version is currently running in the Kubernetes payment pod.)

```
curl -i https://payment.payservice.click/pay -X POST
```
(Verify that the newly deployed application is reachable publicly and working after the automated CI/CD deployment.)

Step 8: PR (Pull Request) workflow check

```
git checkout -b phase-03-m5-pr-trigger-test
```
(Create a new feature branch for PR testing. We do NOT want to test PR workflows directly on main branch.)

```
printf "\n2026-05-06 — Phase 03 M5: opened this PR to verify PR trigger runs test job only (no build, no deploy).\n" >> scratch.md
```
(Create a tiny harmless file change so Git has something to commit for the PR test.)

```
git add scratch.md
```
(Stage the harmless PR test change for commit.)

```
git commit -m "Phase 03 M5: trigger PR test-only workflow run"
```
(Create a new Git commit specifically for PR workflow testing.)

```
git push -u origin phase-03-m5-pr-trigger-test
```
(Upload the branch to GitHub so a Pull Request can be created.)

```
gh pr create --title "Phase 03 M5: PR trigger test" --body "Validates that PRs trigger ONLY the test job (no build, no deploy)."
```
(Open a Pull Request so GitHub triggers the PR workflow event.)

ALL the work that has been done by above commands:
1. Created a separate feature branch → so we could safely test PR behavior without touching main
2. Added a harmless file change (scratch.md) → just to create a commit for testing
3. Staged and committed the change → created a new Git commit for the PR test
4. Pushed the branch to GitHub → uploaded the feature branch to the remote repository
5. Created a Pull Request → requested merge from feature branch into main
6. GitHub detected the PR event → automatically triggered the GitHub Actions workflow
7. Workflow should run ONLY the test job → build-and-push and deploy jobs should be skipped
8. This validates the CI/CD safety behavior → PRs validate code safely without deploying to EKS production

Step 9: Watch the workflow

```
gh pr checks 1 --watch
```
(Watch the checks for PR #1 and confirm PR workflow behavior.)
Test job ✅ ran and passed
Build & push to ECR ⏭ skipped
Deploy to EKS ⏭ skipped

Step 10:

```
gh pr merge 1 --squash --delete-branch
```
(Merge the PR into main so the normal main-branch deployment pipeline runs.)
(You successfully merged the Pull Request into main, which automatically triggered a new CI/CD deployment using the merge commit SHA as the new application image version.)

```
gh run watch
```
The merge-triggered workflow already finished quickly.

```
gh run list --limit 5
```
(Feature branch → PR → tests only ✅
Merge PR → main → build + push + deploy ✅)

Step 11: Negative test (broken commit + auto-rollback)
This step intentionally breaks the health check to confirm that Helm `--atomic` automatically rolls back failed deployments and keeps the app available.

Break /health
→ GitHub Actions builds bad image
→ Helm deploys bad image
→ Kubernetes readiness probe fails
→ Helm waits 5 minutes
→ Helm --atomic rolls back to old working version
→ workflow turns red
→ live app should still work

Why /health is the right thing to break: Kubernetes uses /health to decide if the pod is ready.
If /health returns 500, Kubernetes says: "Do not send traffic to this new pod."

A bad image can reach deploy stage, but it will not replace the healthy running app.

Editing `app/main.py` — single-line break.

```
git add services/payment/app/main.py
```
(Stage the intentionally broken application file for commit.)

```
git commit -m "Phase 03 M7: deliberately break /health to validate atomic rollback"
```
(Create a Git commit containing the intentionally broken health endpoint.)

```
git push origin main
```
Trigger the CI/CD pipeline with intentionally broken application code.

```
gh run watch
```
GitHub CLI (Command Line Interface) — Watch a live GitHub Actions workflow run from terminal.
Workflow failed ✅
Bad deploy rejected ✅
Live app stayed healthy ✅

```
helm history payment -n payment
```
(Verify Helm recorded the failed deploy and automatic rollback.)

```
kubectl get pods -n payment -o jsonpath='{.items[*].spec.containers[*].image}{"\n"}'
```
(Confirm Kubernetes is NOT running the broken image `0c3c84e`. Pod is running good image `96872dd`, `payment-service:96872dd`.)

```
curl -i -X POST https://payment.payservice.click/pay
```
(The broken deployment failed and rolled back, but the public payment endpoint is still healthy. Helm --atomic successfully protected the live service by rolling back the failed deployment while keeping the public API available.)

Step 12: rollback protected production, but your Git repo still contains the broken /health code.

```
git add services/payment/app/main.py
git commit -m "Phase 03 M7 recovery: restore /health endpoint after rollback validation"
git push origin main
```
(restores the working /health endpoint)

```
gh run watch
```
(Watch a GitHub Actions workflow run live from terminal.)
GitHub Actions built fixed image `09e251c`
→ pushed to ECR
→ deployed to EKS
→ /health passed
→ Helm --atomic succeeded

```
kubectl get pods -n payment -o jsonpath='{.items[*].spec.containers[*].image}{"\n"}'
```
Kubernetes pod is now running: `payment-service:09e251c`

## Deploy Phase 03b — Second downstream service + cross-service tracing

### Milestone 1: Create the new risk-check app

**Dockerfile**: This Dockerfile creates a container image for the risk-check-service by installing Python and all required FastAPI libraries, then copying the application code into the container. When the container starts, it runs the FastAPI app on port 8080 with Datadog tracing enabled through `ddtrace-run`.

**requirements.txt**: This file contains the Python libraries needed for the risk-check-service. During the Docker build, these packages are installed so the application, logging, Datadog tracing, and web server can run properly.

**conftest.py**: This file helps pytest find and import the application files correctly during testing. It adds the current project folder to Python's path so test files can import things like `app.main` without import errors.

**test_smoke.py**: This is a basic health check test to confirm the app can start properly. Can Python load `app.main` successfully? Can FastAPI create the app object successfully?

### Milestone 2: Create its ECR repo and give GitHub Actions permission to push to it

**ecr.tf**: This Terraform code creates a secure AWS ECR repository for storing risk-check-service Docker images, automatically scans them for vulnerable software packages, keeps only the latest 10 images, and outputs the repository URL for deployments. (This Terraform code creates a new AWS ECR repository for storing Docker images of the risk-check-service.)

**github_actions.tf**: This IAM policy allows GitHub Actions to upload Docker images only to the payment-service and risk-check-service ECR repositories. (This section gives GitHub Actions permission to push Docker images into your AWS ECR repositories.)

### Milestone 3: Create Helm chart so Kubernetes can run it

**Chart.yaml**: This file defines the Helm chart information for deploying the risk-check-service application into Kubernetes/EKS.

**values.yaml**: Helm reads this file to know which image to run, how many pods to create, ports, Datadog settings, and pod resource limits.

**_helpers.tpl**: This file creates reusable Helm naming functions (Deployment name, Service name, ConfigMap name) so Kubernetes resources get consistent, valid names automatically.

**configmap.yaml**: This ConfigMap passes variables from Kubernetes → into the risk-check-service container during pod start up.

**serviceaccount.yaml**: This file creates a Kubernetes ServiceAccount for the risk-check-service pod. (A ServiceAccount gives a pod an identity inside Kubernetes so Kubernetes can manage and recognize the application properly.)

**service.yaml**: This file creates an internal Kubernetes networking endpoint so payment-service can communicate with risk-check-service inside the EKS cluster.

**deployment.yaml**: Creates 1 risk-check pod, uses the Docker image from ECR, runs it on port 8080, adds Datadog tracing/log settings, checks `/health` to know if pod is healthy, applies CPU/memory limits.

### Milestone 4: Change payment-service so it calls risk-check-service

**requirements.txt**: payment-service can now send HTTP requests to risk-check-service.

**main.py**: payment-service calls risk-check-service inside EKS (sending the `payment_id`) and waits up to 2 seconds for a response. Datadog automatically traces both services together as one distributed request.

### Milestone 5: Add/adjust GitHub Actions workflows for both services

**deploy-payment.yml**

Phase 03b updated the payment-service workflow so payment deploys only when payment-related files change, allowing payment-service and risk-check-service to deploy independently.

When payment-service related files change and are pushed to the main branch, GitHub Actions automatically starts the CI/CD pipeline. If only risk-check-service files change, this payment pipeline does not run because path filters keep both service deployments independent.

If a Pull Request is created, GitHub Actions runs only the tests to safely verify the code before merging into main.

For deployments, GitHub Actions uses OIDC temporary tokens to securely access AWS without storing AWS access keys in GitHub.

The pipeline then tests the application, builds a Docker image, tags the image using the short Git commit SHA, and pushes the image to AWS ECR.

After the image is successfully pushed, Helm deploys the new image into EKS.

If the deployment fails or health checks fail, Helm automatically rolls back to the previous healthy version to avoid breaking the application.

**deploy-risk-check.yml**

When risk-check related files change and are pushed to the main branch, GitHub Actions automatically starts the CI/CD pipeline. If only risk-check-service files change, the payment-service pipeline does not run because path filters keep both service deployments independent.

If a Pull Request is created, GitHub Actions runs only the tests to safely verify the code before merging into main.

For deployments, GitHub Actions uses OIDC temporary tokens to securely access AWS without storing AWS access keys in GitHub.

The pipeline then tests the application, builds a Docker image, tags the image using the short Git commit SHA, and pushes the image to AWS ECR.

After the image is successfully pushed, Helm deploys the new image into EKS in the `risk-check` namespace.

If the deployment fails or health checks fail, Helm automatically rolls back to the previous healthy version to avoid breaking the application.

### Milestone 6: Deploy risk-check-service through CI/CD

Add + staged all Phase 03b changes for commit. Pushed to GitHub main successfully.

### Milestone 7: Verify Datadog shows one trace across both services

Send an HTTP request to the public payment endpoint.

```
curl -X POST https://payment.payservice.click/pay
```

Open Datadog → APM → Traces:

```
search: service:payment-service env:capstone
        service:payment-service env:capstone resource_name:"POST /pay"
```

## Deploy Phase 04 — HA and scaling (HPA, PDB, probes, drain test)

### Milestone 1 — metrics-server.tf

Install metrics-server: metrics-server is being installed into the EKS cluster.

Purpose of metrics-server: We are installing metrics-server into the EKS cluster so Kubernetes can collect CPU and memory metrics required for HPA autoscaling.

Terraform uses `helm_release` to manage the Helm installation declaratively.

- `repository` → tells Terraform where to download the metrics-server Helm chart from.
- `chart` → tells Terraform which Helm chart to install.
- `namespace` → tells Terraform where inside Kubernetes to install metrics-server (`kube-system`).
- `version` → tells Terraform which exact chart version to install for stable/reproducible deployments.
- `depends_on` → tells Terraform to wait until the EKS cluster and access permissions are fully ready before installing metrics-server.
- `output` → prints verification commands after `terraform apply` so we can confirm metrics-server works successfully.

Run command to check if chart exists:

```bash
cd infra
helm repo add metrics-server https://kubernetes-sigs.github.io/metrics-server/ 2>/dev/null || true
helm repo update metrics-server
helm search repo metrics-server/metrics-server --versions | head -10
```

What does the chart contain that's separate from the app itself? (Why would maintainers ship two chart versions for the same app?)

```
Chart 3.9.0  → App 0.6.3
Chart 3.10.0 → App 0.6.3
- same app version
- different chart version

Chart 3.12.2 → App 0.7.2
Chart 3.13.0 → App 0.8.0
BOTH changed:
- Helm chart version changed
- metrics-server software version changed
```

Chart changed only → deployment/probe/RBAC/template fixes. App changed → actual metrics-server software upgraded. CHART VERSION can change independently. APP VERSION can also change independently. Sometimes both change together. Sometimes only chart changes.

If metrics-server needs a NEW SOFTWARE FEATURE, which version changes? If a new metrics-server feature is needed, the APP VERSION must change. The CHART VERSION may also change to package that newer app. Terraform installs the Helm chart, not the application directly (because the Helm chart CONTAINS the application version reference inside it).

```
Terraform        = the tool managing the installation process.
Helm chart       = the deployment/install package/template for the application.
CHART VERSION    = version of the Helm deployment package/template.
Application      = the actual software running inside Kubernetes.
APP VERSION      = version of the actual application/software/container.

Flow:
Terraform → installs Helm chart version 3.12.2
Helm chart 3.12.2 → internally deploys metrics-server app version 0.7.2

Terraform directly controls: CHART VERSION
Helm chart internally controls: APP VERSION
```

What dangerous/unexpected infrastructure changes would you NOT want `terraform plan` to show? EKS cluster, VPC, CI/CD IAM/OIDC role, Datadog, AWS Load Balancer Controller, ALB, Route 53 records, ACM certificate, ECR repositories, node group, NAT Gateway, subnets / route tables, payment-service or risk-check-service infrastructure. **Infrastructure that we created.**

```
terraform plan
```

Only `helm_release.metrics_server` appears. Version 3.12.2 ✓, namespace `kube-system` ✓.

When Terraform runs `helm_release` apply, how does Terraform decide "metrics-server installation succeeded" / What exact condition does Terraform watch during `wait=true`?

- (a) Only checks whether Helm command exited successfully.
- **(b) Checks whether pods/resources created by the Helm chart become healthy/Ready. (Answer)**
- (c) Checks whether `kubectl top nodes` returns metrics data.
- (d) Checks only whether deployment replica count numbers match.

```
terraform apply
```

Terraform successfully installed the metrics-server Helm chart into the EKS cluster. (Only the new metrics-server resource was added. Nothing existing was modified or deleted.) metrics-server is now running in the cluster and Kubernetes should now be able to provide CPU/memory metrics for HPA.

```
kubectl get deploy -n kube-system metrics-server
```

Asked Kubernetes to show the Deployment status for metrics-server inside the `kube-system` namespace.

```
kubectl top nodes
```

Asked metrics-server / Kubernetes Metrics API to show live CPU and memory usage for all worker nodes in the cluster.

```
kubectl top pods -A
```

Asked metrics-server / Kubernetes Metrics API to show live CPU and memory usage for ALL pods in ALL namespaces.

Why did `kubectl top nodes` suddenly start working after M1, when before it showed: "Metrics API not available"?

Before M1, the cluster did not have metrics-server installed, so Kubernetes had no Metrics API provider. Because of that, `kubectl top nodes` could not get CPU or memory data and showed "Metrics API not available." After M1, we installed metrics-server into EKS. metrics-server collects CPU and memory usage from the kubelet running on each EKS worker node, then exposes that data through the Kubernetes Metrics API. Now `kubectl top nodes` can read from that Metrics API, so it shows live CPU and memory usage for the worker nodes. HPA will use the same metrics later to decide when to scale pods.

### Milestone 2 — tune probes on payment-service

1. Startup probe → checks whether the app finished starting.
2. Readiness probe → checks whether the app is ready to receive traffic.
3. Liveness probe → checks whether the running app is still healthy/alive.

`values.yaml`: We are adding Kubernetes health probe configuration to payment-service Helm `values.yaml`.

- startup probe → checks whether the application finished booting successfully.
- `path: /health` → Kubernetes will call the `/health` endpoint for checks.
- `periodSeconds: 5` → check every 5 seconds.
- `failureThreshold: 6` → allow 6 failed checks before considering startup failed.
- 30s startup budget → 6 failures × 5 seconds = about 30 seconds allowed for app startup.

`deployment.yaml`: We are adding Kubernetes health checks (probes) to the payment-service Deployment.

- `readinessProbe` → checks whether the application is ready to receive traffic.
- `path: /health` → Kubernetes calls the `/health` endpoint to test readiness.
- `port: http` → health check runs on the container's http port.
- `initialDelaySeconds: 5` → wait 5 seconds after container starts before first readiness check.
- `periodSeconds: 10` → check readiness every 10 seconds.
- `timeoutSeconds: 2` → health check must respond within 2 seconds.
- `failureThreshold: 3` → after 3 failed checks, Kubernetes removes the pod from traffic/endpoints.
- Goal → only send traffic to healthy and ready pods.

- `livenessProbe` → checks whether the running application is still alive or stuck.
- `path: /health` → Kubernetes calls the same `/health` endpoint for liveness checks.
- `initialDelaySeconds: 10` → wait 10 seconds before starting liveness checks.
- `periodSeconds: 10` → check liveness every 10 seconds.
- `failureThreshold: 3` → after 3 failed checks, Kubernetes restarts the pod.
- Goal → automatically restart unhealthy or stuck containers.

`/health`: check payment-service `/health` endpoint is safe for Kubernetes probes.

```python
@app.get("/health")
def health_check():
    return {"status": "ok"}
```

Is the payment-service process alive and able to respond? We checking the liveliness of payment-service here not the app.

```
git diff helm/payment/ | cat
```

This command showed all local code changes made inside the payment-service Helm chart before commit/push. (So it's showing whatever code changes happened in which file and what that code do.)

```
git add helm/payment/values.yaml helm/payment/templates/deployment.yaml
```

This command staged the modified Helm chart files for commit. Git now marks these probe-related changes as ready to be committed into repository history.

```
git commit -m "Phase 04 M2: parameterize probes on payment-service ..."
```

This command created a new Git commit containing the M2 probe changes. Git recorded 38 new lines added, 11 old lines removed across the two modified Helm chart files.

What we learned: "Your branch is ahead of 'origin/main' by 1 commit." Local Git has one extra commit that remote GitHub does not have yet. We can push to GitHub next. Local commit currently says M2 happened first, but M1/spec files are still not committed. Reorder locally before pushing so GitHub history reads:
1. Phase 04 spec + M1 metrics-server
2. Phase 04 M2 probes

(No damage yet because it is only local. That is why we can still fix the order before pushing to GitHub.)

How to resolve it:

```
git reset --soft HEAD~1
```

Removed the last local Git commit from history while keeping all M2 probe changes safely in the working directory/staging area. Purpose: rebuild commit history in cleaner order: M1/spec first → M2 second.

```
git status
```

Showed current Git state: staged files, unstaged files, untracked files, branch status compared to GitHub.

```
git restore --staged helm/payment/
```

Removed the Helm payment probe files from the staging area without deleting any actual file changes. Purpose: temporarily separate M2 changes so M1/spec could be committed first.

```
git add infra/metrics-server.tf specs/phase-04.md ROADMAP.md
```

Staged the M1/spec-related files for commit. Files included: metrics-server Terraform file, full Phase 04 spec, roadmap status update.

```
git commit -m "Phase 04 spec approved + M1: install metrics-server via helm_release"
```

Created the M1/spec commit locally. This permanently saved metrics-server Helm/Terraform installation, approved Phase 04 spec, roadmap update. Commit ID: `3ebefb2`.

```
git log --oneline -5
```

Displayed the latest 5 Git commits in short format. Purpose: verify commit order/history.

```
git add helm/payment/
```

Staged the payment-service probe changes again for M2.

```
git commit -m "Phase 04 M2: parameterize probes on payment-service ..."
```

Created the M2 probe commit locally. This saved startup probe, readiness tuning, liveness tuning, configurable Helm probe settings, `/health` audit documentation. Commit ID: `0f78a6a`.

```
git push origin main
```

Pushed both local commits to GitHub remote repository (`origin/main`). GitHub now contains: (1) Phase 04 spec + M1 metrics-server, (2) Phase 04 M2 probe changes.

```
gh run list --limit 3
```

Listed the latest 3 GitHub Actions workflow runs. Result showed: Deploy payment-service workflow triggered automatically from the new push.

```
gh run watch
```

Started watching the active GitHub Actions workflow live in the terminal. Purpose: monitor CI/CD deployment progress/status in real time. If succeeded: push from your LOCAL Git repository to the REMOTE GitHub repository.

**What I have learned: deployment failed for payment-service.**

```
gh run watch 25585771438
```

`Run Deploy payment-service (25585771438) has already completed with 'failure'`

```
gh run view 25585771438 --log-failed | tail -100
```

Check the log where failure happened. The Helm deployment failed because the workflow used `--reuse-values`.

What happened: The new deployment template expected new probe values like `.Values.probes.startup.path`. Problem: Helm reused OLD deployed values that did not contain the new probes section. Result: Helm could not find `probes.startup` and failed with `nil pointer evaluating interface {}.startup`.

Impact: The CI/CD deployment failed before Kubernetes deployment started. Protection: `--atomic` automatically rolled back the failed deployment, so old working pods continued running safely.

Fix: removed `--reuse-values` from the Helm deploy workflow.

Why fix worked: Now Helm always uses the latest deployment templates and `values.yaml` from GitHub during deployment.

Main learning: **Reusing old Helm values can break deployments when new templates require new configuration keys.**

```
kubectl describe pod -n payment -l app=payment-service | grep -A 2 'Liveness\|Readiness\|Startup'
```

Find pod(s): show full detailed Kubernetes pod information from namespace `payment` with label `app=payment-service`. Take the describe output and filter/search only lines containing `Liveness`, `Readiness`, `Startup`. `-A 2` = show 2 lines after match.

### Milestone 3 — HPA + replica bump on payment

`values.yaml`:

1. Deployment pods replicas = starting/base number of pods Kubernetes should run.

```yaml
replicas: 2
```

payment-service will now start with 2 pods instead of 1 (if one pod fails, the second pod can still serve traffic). Deployment replicas were increased to 2 to match the future HPA (Horizontal Pod Autoscaler) minimum replica count.

2. Added HPA configuration = automatic scaling controller for those same payment-service pods.

```yaml
minReplicas: 2
maxReplicas: 6
```

HPA will: never go below 2 pods, can automatically scale up to 6 pods during load.

`hpa.yaml`: This file creates a Kubernetes Horizontal Pod Autoscaler (HPA) for payment-service.

- if `hpa.enabled=true` in `values.yaml`, create the HPA resource
- uses `autoscaling/v2` modern Kubernetes HPA API
- creates a Kubernetes HPA resource using Helm templating for dynamic naming
- `scaleTargetRef` connects the HPA to the payment-service Deployment
- `minReplicas: 2` means never scale below 2 pods
- `maxReplicas: 6` means can scale up to maximum 6 pods
- `metrics` section defines what metric HPA monitors for scaling decisions
- `resource: cpu` means HPA uses CPU utilization for autoscaling
- `averageUtilization: 70` means HPA tries to keep average pod CPU around 70%
- if CPU usage goes above 70%, HPA adds more pods
- if CPU usage drops below 70%, HPA removes extra pods (but never below 2)

```
git diff helm/payment/ | cat
```

Was used to view all current code/configuration changes made inside the payment-service Helm chart before commit/push: what files changed, what exact lines changed, what was added/removed/modified.

```
git status
```

Local Git and GitHub main branch currently match. No unpushed commits exist right now.

```
git add helm/payment/values.yaml helm/payment/templates/hpa.yaml
```

Prepare these files for the next local staging commit.

```
git commit -m "Phase 04 M3: add HPA for payment-service (min 2 / max 6 / 70% CPU); bump replicas 1->2"
```

Commit was successfully created on the local main branch. `6e3c73b` = commit ID/hash for this M3 change. 2 files changed - `values.yaml`, `hpa.yaml`.

```
git push origin main
```

Uploads LOCAL Git commits to GitHub `origin/main` branch.

```
gh run list --limit 2
```

Confirms: GitHub Actions deployment pipeline ran, deployment job completed successfully.

```
kubectl get hpa -n payment
```

→ Verify that the HPA autoscaler resource exists and is actively managing payment-service scaling. Retrieve and display all HPA autoscaling resources running in the payment namespace. What it retrieves: HPA name, target Deployment, current CPU usage, target CPU threshold, minimum pod count, maximum pod count, current running replica count, resource age.

```
kubectl describe hpa payment -n payment | grep -A 4 'Conditions\|Metrics'
```

→ Verify detailed HPA health, CPU metrics, and scaling conditions/status for payment-service. It retrieves details like: current CPU metrics, target CPU threshold, current replica count, min/max replica settings, scaling events, scaling conditions/status, target Deployment information, whether HPA is healthy and actively scaling. And pass it to where label matches `Conditions\|Metrics` and show 4 rows after match.

```
kubectl get pods -n payment
```

→ Verify that the expected payment-service pods are running healthy after M3 scaling changes. Retrieved/listed all running pods inside the payment namespace.

### Milestone 4 — Deploy the PDB manifest via CI/CD

`values.yaml`:

- Adds PodDisruptionBudget (PDB) configuration into `values.yaml`.
- `pdb.enabled: true` means enable/create the PDB resource.
- `minAvailable: 1` means Kubernetes must keep at least 1 payment-service pod available during voluntary disruptions.
- This value is later used by `pdb.yaml` through Helm templating.
- Helps prevent full application downtime during node drains or maintenance operations.

`pdb.yaml` (PDB = PodDisruptionBudget):

- This file creates a Kubernetes PodDisruptionBudget (PDB) for payment-service.
- PDB is created only if `pdb.enabled=true` in `values.yaml`.
- Uses modern Kubernetes API version `policy/v1`.
- Creates a Kubernetes resource of type `PodDisruptionBudget`.
- Uses Helm templating to dynamically generate the PDB resource name.
- `minAvailable: 1` means at least 1 payment-service pod must always remain available during voluntary disruptions.
- `selector.matchLabels` tells Kubernetes which pods this PDB should protect.
- `app: payment-service` selector matches the labels used by payment-service pods.
- The selector label was verified earlier using `kubectl get pods --show-labels`.
- PDB protects against voluntary disruptions like node drains, upgrades, or cluster maintenance.
- PDB does not protect against application crashes or node failures.
- Overall this file helps maintain payment-service availability during Kubernetes maintenance operations.

**What I learned: Kubernetes label matching.** Kubernetes selects pods using labels like `app: payment-service`. Then another resource (HPA/PDB/Service etc.) uses `app: payment-service`.

Warning: If selector labels do NOT exactly match pod labels, Kubernetes may select zero pods or wrong pods.

Example: pods have `app=payment` but selector searches `app=payment-service`.

How to find:

```
kubectl get pods -n payment --show-labels
```

Display pod labels in the output.

```
git diff helm/payment/values.yaml | cat
```

Shows the current local changes made only in `helm/payment/values.yaml` before committing or pushing them.

```
git status
```

Shows the current local Git state — changed files, staged files, untracked files, and commit/push status.

```
git add helm/payment/values.yaml helm/payment/templates/pdb.yaml
```

Prepares/stages the `values.yaml` and `pdb.yaml` changes for the next local Git commit.

```
git commit -m "Phase 04 M4: add PDB for payment-service (minAvailable: 1)"
```

Created a new local Git commit saving the M4 PDB (PodDisruptionBudget) changes for payment-service.

```
git push origin main
```

Pushed your local M4 PDB commit from your laptop/local Git repository to the GitHub main branch and triggered the CI/CD deployment.

```
gh run list --limit 2
```

Shows the latest GitHub Actions CI/CD workflow runs and their current deployment status.

```
gh run watch 25592134249
```

Watched the latest GitHub Actions CI/CD deployment run (workflow ID 25592134249) and confirmed the newest pushed M4 commit deployed successfully.

Verify PDB:

```
kubectl get pdb -n payment
```

Verified that the payment-service PodDisruptionBudget (PDB) was successfully created and is protecting at least 1 pod during Kubernetes maintenance disruptions.

```
kubectl get pdb payment -n payment -o yaml | grep -A 5 'spec\|status'
```

Verified the detailed PDB configuration and confirmed Kubernetes currently allows only 1 payment-service pod disruption while keeping at least 1 healthy pod running.

```
kubectl get pods -n payment -o wide
```

Showed detailed payment-service pod information including which Kubernetes worker node each pod is running on, confirming the 2 pods are distributed across 2 different EKS nodes for High Availability.

```
kubectl get ingress -n payment
# No resources found in payment namespace.
```

**What I learned (the ALB regression):**

- Phase 02 originally deployed payment-service with `ingress.enabled=true` and `certificateArn` (it enables secure encrypted HTTPS traffic between user browser and ALB) set through Helm CLI flags.
- This created the Kubernetes Ingress resource and AWS ALB public HTTPS endpoint.
- Later CI/CD deployments used `--reuse-values`.
- `--reuse-values` preserved the old `ingress.enabled=true` setting during future deployments.
- In M2 we removed `--reuse-values` to fix the probes deployment issue.
- After removing it, Helm started using the default `values.yaml` again.
- In `values.yaml`, `ingress.enabled=false` by default.
- Helm compared the new desired state with the old deployed state.
- Helm saw that Ingress was no longer enabled/described in the desired configuration.
- Helm automatically deleted the Kubernetes Ingress resource.
- AWS Load Balancer Controller then removed the ALB because the Ingress disappeared.
- CI/CD still succeeded because deleting an Ingress resource is not considered a deployment failure.
- Result: application deployment worked, but the public HTTPS endpoint disappeared silently.
- Main learning: `--reuse-values` was unintentionally preserving old ingress settings across deployments.
- Correct long-term fix: explicitly define ingress configuration in Git/`values.yaml` or deployment workflow instead of relying on reused old Helm values.

How to fix it:

- This change turns the payment-service Ingress back ON.
- `ingress.enabled: true` tells Kubernetes to create the public ALB again.
- `host` sets the public website/domain name.
- `certificateArn` tells AWS which HTTPS certificate to attach to the ALB.
- Earlier the ALB worked because `--reuse-values` kept old ingress settings alive.
- When `--reuse-values` was removed in M2, Helm used default values again.
- Default `ingress.enabled=false` caused Kubernetes to delete the Ingress.
- Deleting Ingress removed the ALB / public HTTPS endpoint.
- Now `ingress.enabled=true` and `certificateArn` are permanently stored in `values.yaml`.
- Future deployments will automatically keep the ALB and HTTPS endpoint working.

```
git add helm/payment/values.yaml
git commit -m "Phase 04 M4b prep: restore ALB ingress as chart default (lost when --reuse-values was removed in M2 fix)"
git push origin main
gh run list --limit 2
```

Pushed the local ALB/Ingress restoration fix commit and triggered a new CI/CD deployment.

```
kubectl get ingress -n payment
```

Verified that the payment-service Kubernetes Ingress and public AWS ALB were successfully recreated, and the application is again reachable through the `payment.payservice.click` domain.

```
curl -v https://payment.payservice.click/health 2>&1 | head -25
```

The ALB/Ingress was recreated successfully, but DNS is not resolving yet.

```
curl -v http://k8s-payment-payment-490cbbb298-1129335665.us-east-1.elb.amazonaws.com/health 2>&1 | head -25
```

This curl proved the ALB DNS name works and the ALB is reachable. HTTP 301 Moved Permanently means the ALB received your HTTP request and redirected it to HTTPS.

```
curl -ksv https://k8s-payment-payment-490cbbb298-1129335665.us-east-1.elb.amazonaws.com/health 2>&1 | tail -20
```

This proved HTTPS is working on the ALB, but the request returned 404 because the ALB Ingress rules are expecting the configured host name (`payment.payservice.click`), not the raw ALB DNS name. So: ALB is healthy, HTTPS certificate is attached, traffic reached the ALB, but host-based routing did not match, so ALB returned 404.

```
curl -ksv -H "Host: payment.payservice.click" https://k8s-payment-payment-490cbbb298-1129335665.us-east-1.elb.amazonaws.com/health 2>&1 | tail -10
```

ALB routed the request correctly to payment-service, and payment-service `/health` responded successfully.

**Issue for DNS:**

1. Terraform originally created a Route 53 DNS record for `payment.payservice.click`.
2. That DNS record pointed to the AWS ALB created by the Kubernetes Ingress.
3. Terraform automatically found the ALB using AWS Load Balancer Controller tags.
4. Earlier Ingress deletion caused AWS to delete the old ALB.
5. Route 53 DNS was still pointing to that deleted old ALB.
6. In M4b prep, Ingress was recreated and AWS created a brand new ALB with a new DNS name.
7. Route 53 still points to the old deleted ALB because Terraform has not refreshed the DNS record yet.
8. Direct curl to the new ALB worked because you manually used the new ALB DNS name with the correct Host header.
9. `payment.payservice.click` still fails because Route 53 DNS is outdated.
10. Running `terraform apply` will make Terraform find the new ALB and update Route 53 to point to the new ALB.
11. After DNS propagation, `payment.payservice.click` will work again normally.
12. Option A fixes DNS properly now and restores the real production-style HTTPS endpoint.
13. Option B uses a temporary Host-header workaround but leaves DNS broken.
14. Best choice is Option A because it fully restores the public application path correctly.

```
terraform plan
```

→ preview proposed infrastructure changes. ("Terraform plans to update the Route53 alias record to the new ALB DNS name.")

```
terraform apply
```

→ actually perform the DNS update in AWS.

```
dig +short payment.payservice.click
```

Confirmed DNS is fixed: `payment.payservice.click` now resolves to the new ALB IP addresses.

```
curl -sI https://payment.payservice.click/health
```

Confirmed HTTPS routing works through `payment.payservice.click`, but `curl -I` sends a HEAD request and the `/health` endpoint only allows GET, so the app returned 405 Method Not Allowed.

```
curl -s https://payment.payservice.click/health
echo
```

Confirmed the real public HTTPS endpoint is fully working: DNS, ALB, Ingress routing, and payment-service `/health` all returned successfully.

### Milestone 4a — drain test for PDB

(One payment pod will be evicted from the drained node. A replacement payment pod on the remaining healthy node.)

Terminal 1:

```
kubectl get pods -n payment -w
```

Starts a live watch of payment-service pods in the payment namespace so you can observe pod changes, evictions, rescheduling, or restarts in real time during the M4b node drain test.

Terminal 2:

```
while true; do curl -s -o /dev/null -w "%{http_code}\n" https://payment.payservice.click/health; sleep 1; done
```

Continuously sends HTTPS health requests to `payment.payservice.click` every second and prints the HTTP status code to verify the application stays available (no 5xx/downtime) during the node drain test.

Terminal 3:

```
kubectl drain ip-10-0-2-167.ec2.internal --ignore-daemonsets --delete-emptydir-data
```

Safely drained one Kubernetes worker node by cordoning it (stopping new pod scheduling) and evicting movable pods, while the PDB allowed only one payment-service pod to be disrupted so the application stayed available during maintenance.

Note: One terminal is showing live pod/node changes during the drain, and the other terminal is continuously checking if the application health endpoint is still working without downtime.

```
kubectl get pods -n payment -o wide
```

Detailed payment-service pod information including: pod names, health status, pod IPs, which Kubernetes worker node each pod is running on.

```
kubectl get pdb -n payment
```

Verify PDB is still protecting application availability during/after the drain. The PodDisruptionBudget (PDB) status for payment-service including: minimum required healthy pods, allowed disruptions, current protection state.

**All the steps:**

- One payment-service pod survived the node drain successfully.
- Kubernetes automatically created a replacement pod after eviction.
- Both pods are currently running on the same healthy node because the drained node is still cordoned (unschedulable).
- PDB worked correctly by allowing only 1 pod disruption while keeping at least 1 healthy pod available.
- Application stayed mostly available during the drain.
- Around 5 temporary HTTP 502 errors happened during pod termination.
- Those 502 errors happened because the ALB was still sending traffic to the terminating pod for a few seconds before fully removing it from routing.
- This exposed a graceful shutdown gap in the application deployment configuration.
- PDB protects pod availability but does not solve ALB deregistration timing issues.
- First immediate task is to uncordon the drained node so Kubernetes can use it again.
- `kubectl uncordon` removes the `SchedulingDisabled` state from the drained node.
- Existing pods will remain on the current node until future scaling or deployments happen.
- `Ctrl+C` stops the live watch and continuous curl monitoring terminals.
- Option A means accept the small 502 issue for now, document it, and continue to the next milestone.
- Option B means fixing graceful shutdown now using `preStop` hooks and `terminationGracePeriodSeconds`, then retesting everything.
- Recommendation is Option A because Phase 04 goals were already achieved (HPA, probes, PDB), and graceful shutdown tuning can be handled later in Phase 05 chaos testing.

(Yes — Option B is mainly about fixing graceful shutdown timing so the ALB stops sending traffic to the terminating/draining pod before the pod fully shuts down.)

### Milestone 5 — mirror probes/HPA/PDB to risk-check-service

M5 added the same Phase 04 setup to risk-check-service:

- `values.yaml` → changed replicas from 1 to 2, added probe settings, added HPA settings, added PDB settings
- `deployment.yaml` → added startup, readiness, and liveness probes
- `hpa.yaml` → added autoscaling for risk-check-service, min 2 / max 6 / 70% CPU
- `pdb.yaml` → added disruption protection, `minAvailable: 1`

`values.yaml`, `deployment.yaml`, `hpa.yaml` & `pdb.yaml`:

- M5 means copy the same Phase 04 HA/scaling setup from payment-service to risk-check-service.
- Add three probes to risk-check: startup, readiness, and liveness.
- Add HPA to risk-check: min 2 pods, max 6 pods, target 70% CPU.
- Add PDB to risk-check: `minAvailable: 1`.
- No separate node drain test for risk-check because payment already proved the pattern.
- No graceful-shutdown fix now because that is being saved for later/Phase 05.
- Before changing risk-check, audit its `/health` endpoint to make sure it only checks risk-check itself and does not call downstream services.

```
git diff helm/risk-check/ | cat
```

This git diff shows the M5 changes made to risk-check-service: startup/readiness/liveness probes were added, replicas changed from 1 to 2, and HPA + PDB settings were added so risk-check now gets the same health checks, autoscaling, and disruption protection as payment-service.

```
git status
```

Is showing that the M5 risk-check changes are currently only local/uncommitted: 3 existing files were modified and 2 new Kubernetes template files (HPA and PDB) were created, but nothing has been staged or committed to Git yet.

- `values.yaml`: replicas bump + 3 new blocks (probes/hpa/pdb)
- `deployment.yaml`: probes replaced with templated versions
- 2 new files: `templates/hpa.yaml`, `templates/pdb.yaml`

```
git add helm/risk-check/
```

It means Git has now marked those risk-check files as "ready to be saved" in the next commit. Before `git add`: files were only changed locally on your laptop. After `git add`: Git moved those changes into the staging area, waiting for the next `git commit`.

```
git commit -m "Phase 04 M5: mirror probes/HPA/PDB to risk-check-service per Decision 5; bump replicas 1->2"
```

`1->2` (replicas changed from 1 pod to 2 pods.) The replicas were changed inside `values.yaml` / deployment configuration files, but the commit message is simply describing/summarizing that change in human-readable words so people reading Git history understand what this commit did.

```
git push origin main
```

Pushed the local M5 risk-check commit from your laptop/local Git repository to the GitHub main branch and triggered the GitHub Actions CI/CD deployment workflow.

```
gh run list --limit 2
```

Shows the latest GitHub Actions CI/CD runs, confirming the new M5 risk-check deployment workflow is currently running while the earlier payment-service deployment already succeeded.

```
gh run watch 25605750229
```

Watched the latest GitHub Actions CI/CD deployment run for risk-check-service and confirmed the M5 deployment completed successfully.

```
kubectl get hpa,pdb -n risk-check
```

Verified that both the HPA autoscaler and PDB protection were successfully created for risk-check-service, and Kubernetes is currently running 2 pods with autoscaling and disruption protection active.

```
kubectl get pods -n risk-check
```

Verified that risk-check-service is now successfully running 2 healthy pods after the M5 High Availability and autoscaling deployment changes.

```
kubectl describe pod -n risk-check -l app=risk-check-service | grep -A 2 'Liveness\|Readiness\|Startup'
```

This command verified that both risk-check pods now have all 3 probes configured (Startup, Readiness, Liveness) per Decision 5.

## Phase 04 — How and where to find common problems

**metrics-server problems:**
- How to find: `kubectl top nodes`, `kubectl top pods`, `kubectl get hpa`
- Where: Kubernetes CLI / EKS cluster
- Problem: HPA cannot read CPU metrics and scaling stops.

**HPA problems:**
- How to find: `kubectl get hpa`, `kubectl describe hpa`
- Where: Kubernetes HPA resources
- Problem: Pods do not scale correctly or hit max replicas.

**PDB problems:**
- How to find: `kubectl get pdb`, `kubectl describe pdb`, `kubectl drain`
- Where: During node drain or maintenance
- Problem: Node drain gets blocked or all pods get evicted together.

**Startup probe problems:**
- How to find: `kubectl describe pod`, `kubectl get events`, `kubectl logs`
- Where: Pod startup / CrashLoopBackOff state
- Problem: Kubernetes kills app before startup completes.

**Readiness probe problems:**
- How to find: `kubectl get endpoints`, `kubectl get events`, curl requests / load testing
- Where: Service traffic routing
- Problem: Healthy pods temporarily removed from traffic causing intermittent 503s.

**Liveness probe problems:**
- How to find: `kubectl get pods`, `kubectl describe pod`, `kubectl get events`, restart counts increasing
- Where: Pod restart loops and outages
- Problem: Aggressive liveness checks create restart storms and outages.

**Pending pod problems:**
- How to find: `kubectl get pods`, `kubectl describe pod`, `kubectl describe node`
- Where: During HPA scaling
- Problem: Cluster lacks CPU/memory capacity for new pods.

**Load-test related problems:**
- How to find: `hey`, `kubectl get hpa -w`, `kubectl get pods -w`, Datadog dashboards
- Where: During scaling/load tests
- Problem: Scaling delays, CPU saturation, or temporary 5xx during load.

**Datadog observability problems:**
- How to find: Datadog APM, Datadog logs, Datadog flame graphs
- Where: Datadog SaaS UI
- Problem: Missing traces, latency spikes, or unhealthy service behavior.

**Drain-related problems:**
- How to find: `kubectl drain`, `kubectl get pdb`, `kubectl get endpoints`
- Where: During node maintenance/drain testing
- Problem: Pods evict incorrectly or service availability drops during drain.

## Phase 04 — Rollback / undo

**Full Phase 04 rollback:** Return the cluster back to the Phase 03b architecture. Remove HPA, PDB, metrics-server, and revert Helm chart changes through CI/CD redeploys.

**metrics-server rollback:** Remove metrics-server from the cluster. Use Terraform apply/revert approach instead of relying heavily on `terraform destroy -target`.

**HPA rollback:** Remove autoscaling from a service. Deleting the HPA stops automatic scaling, but replica count may need manual adjustment afterward.

**PDB rollback:** Remove disruption protection from a service. Deleting the PDB returns the service to pre-HA maintenance behavior.

**Probe rollback:** Remove startup/readiness/liveness tuning changes. Revert Helm values and redeploy through the normal CI/CD pipeline.

**Replica rollback:** Return service from 2 replicas back to 1. Revert replica count through Helm chart values and redeploy normally.

**Drain recovery:** Recover if node drain gets stuck during M4b. First investigate the real blocking condition before force deleting pods.

**Node recovery:** Recover a node after draining/testing. Use `kubectl uncordon` to make the node schedulable again.

**Load test recovery:** Recover if HPA scaled too high during testing. Stop load generation first and allow HPA stabilization timers to scale down naturally.

**Manual replica recovery:** Recover if replicas remain high after testing. Manually scale deployments back to 2 replicas if needed.

**Rollback limitations:** Operational learning, rescheduled pods, and already-incurred costs remain even after rollback.

**Terraform rollback note:** Prefer reverting Terraform code and re-applying because it is closer to safer production Terraform practices, rather than `terraform destroy -target`.

## Common operations

_(kubectl shortcuts, Datadog dashboard links, AWS console deep-links)_

## Incident playbooks

Built from Phase 05 chaos drills (M2/M3/M4). Each entry follows: first signal → how to confirm → automated vs manual recovery → observed time-to-recovery → escalation criteria.

### Playbook: Pod crashloop / pod kill (from M2)

**First signal**
- Datadog APM: brief blip in pod count widget; latency stays flat; no error spike at the dashboard level
- `kubectl get pods -n <ns>` shows one or more pods in `Terminating` state, replacement appearing as `Pending` → `ContainerCreating` → `Running`
- hey / curl loop: mostly 200s; occasionally a single 502 if a cross-service `/check` call was in-flight when the pod started shutting down (residual application-layer race, Phase 06 work)

**How to confirm cause**
- `kubectl describe pod -n <ns> <name>` — look at the Events section for "Killing", restart counts, OOMKilled
- `kubectl get events --sort-by=.lastTimestamp -n <ns>` — recent eviction or termination reasons

**Automated vs manual recovery**
- Deployment notices replica count dropped (desired = 2, current = 1) and immediately creates a replacement pod.
- Scheduler assigns the new pod; new pod lifecycle: Pending → ContainerCreating → Running → Ready.
- Pod shutdown sequence (with M1's preStop fix in place): SIGTERM signal → preStop sleep 15s runs (gives ALB time to de-register the pod from its target group) → SIGTERM hits the app → uvicorn graceful shutdown (in-flight requests complete) → SIGKILL fallback at terminationGracePeriodSeconds (30s).
- Only after readiness probe passes does ALB start routing traffic to the new pod.
- **No human action needed for single pod kills.**

**Time-to-recovery (observed)**
~6 seconds for replacement pod to reach Ready and rejoin Service endpoints.

**Escalation criteria**
- Replacement pod stays `Pending` > 2 minutes → page (likely node capacity or scheduling issue)
- Multiple consecutive pod kills (CrashLoopBackOff pattern on >50% of pods) → page (likely application bug or config issue)
- Restart count climbing across all pods of a service → page (likely liveness probe too aggressive, downstream cascade)

**Cross-reference:** `lessons.md` Phase 05 entry — 0.01% residual 5xx during pod kill comes from the cross-service `/check` call being in-flight when SIGTERM hits the payment pod. Application-layer graceful shutdown (uvicorn closes connections during in-flight requests) is the root cause. Fix is application-level (Phase 06).

---

### Playbook: Node drained / unschedulable / lost (from M3)

**First signal**
- Datadog APM: error rate spike, pod count drop, host count drop — multiple signals move at once
- `kubectl get nodes` shows a node in `NotReady` state
- hey / curl loop: brief 502/500/504 window (30-90 seconds typical)

**How to confirm cause**

Distinguish between three different "node gone" scenarios — they recover differently:

| Scenario | Detection | Auto-replace? |
|---|---|---|
| `kubectl drain` (voluntary, PDB applies) | Node is `Ready,SchedulingDisabled`; pods migrate one-by-one | No — node still exists, just unschedulable |
| `aws ec2 terminate-instances` (involuntary, PDB ignored) | Node disappears from `kubectl get nodes` after ~5 min, then EKS provisions replacement | Yes — managed node group auto-provisions |
| `kubectl delete node` (rare; manual cleanup) | Node removed from K8s, EC2 may still be running | No — manual EC2 management required |

Diagnostic commands:
- `kubectl get nodes` — which node, what status
- `kubectl get pods -A -o wide` — which pods were on the affected node
- `aws ec2 describe-instances --profile capstone-admin --instance-ids <i-xxx>` — instance state (terminated, stopped, running)
- `aws eks describe-nodegroup --cluster-name capstone-sre-cluster --nodegroup-name <name> --profile capstone-admin` — scaling activity errors

**Automated vs manual recovery**
- EKS managed node group provisions replacement EC2 instance (in our drill: ~13 seconds from terminate → new node Ready).
- Deployment controller reschedules pods on surviving + new node.
- HPA may also create additional pods on surviving nodes if CPU pressure is high under continuing load.
- **PDB does NOT help here.** PDB only governs voluntary disruption (Eviction API used by `kubectl drain`). Force-terminating a node bypasses the eviction path entirely.

**Time-to-recovery (observed)**
- Replacement node Ready: ~13 seconds
- ALB target health-check propagation (502 window stops): 30-90 seconds
- Full recovery (pods rescheduled, all endpoints healthy): 1-2 minutes

**Expected user-visible impact during the chaos window:**
- ~3.6% error rate over a 5-minute load test (873 / 23,960 requests)
- Error breakdown: 591 × 502 (ALB still routing to dead pods), 266 × 500 (cross-service propagation: payment → dead risk-check → exception → 500), 16 × 504 (gateway timeouts)
- Equivalent error-budget burn: ~11 seconds of pure downtime at 80 RPS

**Escalation criteria**
- Replacement node fails to provision within 5 min → page (check AWS capacity, IAM, AMI deprecation)
- Same scenario repeats on >1 node → page (likely capacity / cost issue or hardware pattern)
- Error rate stays above 1% for >5 minutes after node Ready → page (something else is wrong, not just node failure)

**Cross-reference:** `lessons.md` Phase 05 entry — drain vs terminate vs delete distinction; PDB scope (voluntary only); HPA scaling asymmetry between payment and risk-check (different CPU per request → different replica counts under same RPS).

---

### Playbook: Image pull failure / bad deploy (from M4)

**First signal**
- Datadog APM: **zero impact at the user level** — old pods keep serving traffic
- `kubectl get pods -n <ns>` shows a new pod in `ImagePullBackOff` (or transiently `ErrImagePull`)
- CI/CD pipeline: `helm upgrade --atomic --timeout 5m` fails with `context deadline exceeded`
- Helm release history: latest revision shows `failed` status

**How to confirm cause**
- `kubectl describe pod -n <ns> <bad-pod-name>` — Events section shows "Failed to pull image" with specific error (typically "manifest not found" or "no such image")
- `kubectl get pods -n <ns>` — confirm new pod status `ImagePullBackOff`, old pods still `Running`
- `helm history <release> -n <ns>` — see whether automatic rollback fired
- Common causes:
  - Image tag doesn't exist in ECR (typo, deleted by lifecycle policy, wrong commit hash)
  - ECR auth failure (IAM permission drift, expired credentials)
  - Network issue between worker nodes and ECR (rare, NAT GW problem)

**Automated vs manual recovery**
- `helm upgrade --atomic --timeout 5m` waits 5 minutes for new pod to become Ready (it won't, because image pull is failing).
- After timeout, Helm automatically rolls back to the previous good Deployment revision.
- Old pods keep serving throughout the entire failure window — **zero user-visible impact**.
- New (broken) pods get deleted as part of rollback; broken ReplicaSet scaled to zero.

**Time-to-recovery (observed)**
- 5 minutes total (Helm's `--timeout` value).
- Service availability: ~100% throughout (8,450 / 8,450 = 100% 200s in M4's load test during the failed deploy).
- If you want faster recovery, reduce `--timeout` to 2-3 minutes (faster failure detection at the cost of less time for slow legitimate deploys).

**Escalation criteria**
- Helm rollback also fails (e.g., SSA conflict, RBAC issue) → page (Helm + cluster state is now inconsistent; needs manual investigation)
- ImagePullBackOff persists after rollback (still happens on old image too) → page (might be an ECR-wide auth or network problem)
- Repeated bad-image deploys from the same commit → check CI/CD pipeline (something is pushing a tag that doesn't exist)

**Cross-reference:** `lessons.md` Phase 05 entry — Helm + HPA SSA field-ownership bug found during M4 (Helm tries to manage `.spec.replicas` while HPA already owns it via the scale subresource). Fix: conditionally omit `replicas:` from Deployment template when HPA is enabled — `{{- if not .Values.hpa.enabled }} replicas: {{ .Values.replicas }} {{- end }}`. Real production bug surfaced by chaos drill.

---

### Future playbooks (Phase 06+ work)

- [ ] DB latency spike — Phase 06 (downstream/dependency failures)
- [ ] Downstream service slow — Phase 06
- [ ] WAF blocking legitimate traffic — Phase 07
- [ ] Datadog agent not reporting — observability failure mode

## Useful queries

_(PromQL, Datadog APM filters, log queries — populated as discovered)_
