# Phase 02 Milestone 2 — ACM certificate for payment.payservice.click
#
# Three resources:
#   1. aws_acm_certificate         — requests the cert (DNS-validation method)
#   2. aws_route53_record          — publishes the CNAME ACM asks for
#   3. aws_acm_certificate_validation — blocks until ACM marks the cert ISSUED
#
# The hosted zone for payservice.click was auto-created by Route 53 when the
# domain was registered (Phase 02 Milestone 1). We data-source it rather
# than manage its lifecycle here.

data "aws_route53_zone" "main" {
  name         = "payservice.click."
  private_zone = false
}

resource "aws_acm_certificate" "payment" {
  domain_name       = "payment.payservice.click"
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name = "payment-payservice-click"
  }
}

# Publish the CNAME ACM gives us, into the hosted zone.
# for_each handles the case where ACM returns multiple validation records
# (e.g., for a SAN cert). For a single-domain cert this is one record.
resource "aws_route53_record" "acm_validation" {
  for_each = {
    for dvo in aws_acm_certificate.payment.domain_validation_options :
    dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  zone_id         = data.aws_route53_zone.main.zone_id
  name            = each.value.name
  records         = [each.value.record]
  type            = each.value.type
  ttl             = 60
  allow_overwrite = true
}

# Wait until ACM successfully validates the cert. Without this resource,
# subsequent steps could attach a still-pending cert to the ALB and fail.
resource "aws_acm_certificate_validation" "payment" {
  certificate_arn         = aws_acm_certificate.payment.arn
  validation_record_fqdns = [for r in aws_route53_record.acm_validation : r.fqdn]
}

output "acm_certificate_arn" {
  value       = aws_acm_certificate_validation.payment.certificate_arn
  description = "ARN of the validated ACM cert for payment.payservice.click — used by the Ingress in Milestone 6."
}

output "route53_zone_id" {
  value       = data.aws_route53_zone.main.zone_id
  description = "Hosted zone ID for payservice.click — used by the alias record in Milestone 7."
}

# Phase 02 Milestone 7 — Route 53 alias record for payment.payservice.click → ALB.
#
# We look up the LBC-created ALB by the tags the LBC stamps on every ALB it
# manages (ingress.k8s.aws/stack and elbv2.k8s.aws/cluster). This avoids
# hardcoding the ALB's auto-generated name (which would change if the ALB
# were recreated).

data "aws_lb" "payment" {
  tags = {
    "ingress.k8s.aws/stack" = "payment/payment"
    "elbv2.k8s.aws/cluster" = module.eks.cluster_name
  }
}

# Alias record — Route 53 native record type that resolves to an AWS resource
# (ALB, CloudFront, S3 website) and tracks its IPs automatically. Cheaper and
# more robust than a CNAME for AWS targets: zero query cost, can sit at apex,
# and AWS updates the IPs when the ALB scales.
resource "aws_route53_record" "payment" {
  zone_id = data.aws_route53_zone.main.zone_id
  name    = "payment.payservice.click"
  type    = "A"

  alias {
    name                   = data.aws_lb.payment.dns_name
    zone_id                = data.aws_lb.payment.zone_id
    evaluate_target_health = true
  }
}
