# Route53 DNS Configuration
# This file contains Route53 resources to automatically configure DNS records
# for the SonarQube domain and ACM certificate validation

# Find existing Route53 hosted zone (assumes it exists)
data "aws_route53_zone" "existing" {
  name         = var.domain_name
  private_zone = false
}

# Data source to get the NLB created by the AWS Load Balancer Controller
data "aws_lb" "sonarqube_nlb" {
  depends_on = [
    kubernetes_service.sonarqube_nlb
  ]

  tags = {
    "service.k8s.aws/resource" = "LoadBalancer"
    "service.k8s.aws/stack"    = "default/sonarqube-nlb"
  }
}

# Wait until the NLB is active and SonarQube is a healthy target before publishing DNS.
# While the NLB is still provisioning its DNS name does not resolve, so an alias created
# earlier answers with no address, and resolvers cache that empty answer for up to 15 minutes.
resource "terraform_data" "wait_for_sonarqube_nlb" {
  triggers_replace = [data.aws_lb.sonarqube_nlb.arn]

  provisioner "local-exec" {
    command = <<-EOT
      set -e
      aws elbv2 wait load-balancer-available --region "$REGION" --load-balancer-arns "$LB_ARN"
      for tg in $(aws elbv2 describe-target-groups --region "$REGION" --load-balancer-arn "$LB_ARN" --query 'TargetGroups[].TargetGroupArn' --output text); do
        aws elbv2 wait target-in-service --region "$REGION" --target-group-arn "$tg"
      done
    EOT
    environment = {
      REGION = var.aws_region
      LB_ARN = data.aws_lb.sonarqube_nlb.arn
    }
  }
}

# Create A record (alias) pointing to the AWS Load Balancer
resource "aws_route53_record" "sonarqube" {
  zone_id = data.aws_route53_zone.existing.zone_id
  name    = "${var.host_name}.${var.domain_name}"
  type    = "A"
  
  alias {
    name                   = data.aws_lb.sonarqube_nlb.dns_name
    zone_id               = data.aws_lb.sonarqube_nlb.zone_id
    evaluate_target_health = true
  }

  depends_on = [
    terraform_data.wait_for_sonarqube_nlb
  ]
}

# Create validation records for ACM certificate
resource "aws_route53_record" "acm_validation" {
  for_each = {
    for dvo in aws_acm_certificate.sonarqube.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = data.aws_route53_zone.existing.zone_id
}

# Certificate validation
resource "aws_acm_certificate_validation" "sonarqube" {
  certificate_arn         = aws_acm_certificate.sonarqube.arn
  validation_record_fqdns = [for record in aws_route53_record.acm_validation : record.fqdn]
  
  depends_on = [
    aws_route53_record.acm_validation
  ]
}

# Output for DNS record verification
output "dns_record_name" {
  description = "The DNS record name that was created"
  value       = aws_route53_record.sonarqube.name
  sensitive   = false
}

output "dns_record_target" {
  description = "The DNS record target (load balancer DNS)"
  value       = aws_route53_record.sonarqube.alias[0].name
  sensitive   = false
}

output "route53_name_servers" {
  description = "Name servers for the existing Route53 hosted zone"
  value       = data.aws_route53_zone.existing.name_servers
  sensitive   = false
}

output "hosted_zone_id" {
  description = "ID of the existing hosted zone"
  value       = data.aws_route53_zone.existing.zone_id
  sensitive   = false
}
