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
