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
