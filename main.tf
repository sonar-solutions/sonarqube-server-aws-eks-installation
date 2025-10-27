# main.tf
terraform {
  required_version = ">= 1.5.7"
  required_providers {
    aws = {
      source = "hashicorp/aws"
      version = ">= 6.0.0, < 7.0.0"
    }
    kubernetes = {
      source = "hashicorp/kubernetes"
      version = "~> 2.20"
    }
    random = {
      source = "hashicorp/random"
      version = "~> 3.1"
    }
    helm = {
      source = "hashicorp/helm"
      version = "~> 2.12"
    }
    http = {
      source = "hashicorp/http"
      version = "~> 3.4"
    }
    time = {
      source = "hashicorp/time"
      version = "~> 0.12"
    }
  }
}
provider "aws" {
  region = var.aws_region
}

# Data source to generate authentication token for the kubernetes and helm providers
data "aws_eks_cluster_auth" "cluster_auth" {
  name = module.eks.cluster_name
}

# Kubernetes provider configuration
provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
  token = data.aws_eks_cluster_auth.cluster_auth.token
}

# Helm provider configuration
provider "helm" {
  kubernetes {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
    token = data.aws_eks_cluster_auth.cluster_auth.token
  }
}

# VPC Configuration
module "vpc" {
  source = "terraform-aws-modules/vpc/aws"
  version = "~> 6.0"

  name = "${var.cluster_name}-vpc"
  cidr = var.vpc_cidr
  azs = var.availability_zones
  private_subnets = var.private_subnets
  public_subnets = var.public_subnets
  enable_nat_gateway = true
  enable_vpn_gateway = false
  enable_dns_hostnames = true
  enable_dns_support = true

  tags = {
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
    Environment = var.environment
    Owner = var.owner_tag
  }
  public_subnet_tags = {
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
    "kubernetes.io/role/elb" = "1"
    Owner = var.owner_tag
  }
  private_subnet_tags = {
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
    "kubernetes.io/role/internal-elb" = "1"
    Owner = var.owner_tag
  }

}

# EKS Configuration
module "eks" {
  source = "terraform-aws-modules/eks/aws"
  version = "~> 21.1.5"

  name = var.cluster_name
  kubernetes_version = var.kubernetes_version
  
  timeouts = {
    create = "50m"
    delete = "15m"
    update = "50m"
  }

  vpc_id = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  endpoint_private_access = true
  endpoint_public_access = true
  
  # Addons needed for the cluster to work
  addons = {
    coredns = {
      most_recent = true
      before_compute = true
      resolve_conflicts_on_update = "OVERWRITE"
    }
    kube-proxy = {
      most_recent = true
      before_compute = true
      resolve_conflicts_on_update = "OVERWRITE"
    }
    vpc-cni = {
      most_recent = true
      before_compute = true
      resolve_conflicts_on_update = "OVERWRITE"
    }
  }
  
  # Add node groups
  eks_managed_node_groups = {
    sonarqube = {
      name = "sonarqube-nodes"
      instance_types = var.node_instance_types
      capacity_type = "ON_DEMAND"
      min_size = 1
      max_size = 5
      desired_size = 2
      disk_size = 50
      labels = {
        Environment = var.environment
        Application = "sonarqube"
      }
    }
  }

  # Access needed for kubectl to work
  access_entries = {
    admin = {
      principal_arn = var.user_arn
      type = "STANDARD"
      policy_associations = {
        admin = {
          policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
          access_scope = {
            type = "cluster"
          }
        }
      }
    }
  }

  tags = {
    Environment = var.environment
    Owner = var.owner_tag
  }
}

# Generate random password for SonarQube database
resource "random_password" "sonarqube_db_password" {
  length  = 16
  special = true
  upper   = true
  lower   = true
  numeric = true
  # Exclude characters that AWS RDS doesn't allow: /, @, ", and space
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

# Wait for EKS cluster to be fully ready before creating Kubernetes resources
resource "time_sleep" "wait_for_cluster" {
  depends_on = [module.eks]

  create_duration = "60s"
}

# Create Kubernetes secret for SonarQube database password
resource "kubernetes_secret" "sonarqube_db_password" {
  metadata {
    name      = "sonarqube-eks-db-password"
    namespace = "default"
  }
  data = {
    password = random_password.sonarqube_db_password.result
  }

  type = "Opaque"

  depends_on = [
    time_sleep.wait_for_cluster
  ]
}

# Create Kubernetes secret for SonarQube monitoring password
resource "random_password" "sonarqube_monitoring_password" {
  length  = 16
  special = true
  upper   = true
  lower   = true
  numeric = true
  # Exclude characters that AWS RDS doesn't allow: /, @, ", and space
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

resource "kubernetes_secret" "sonarqube_monitoring_password" {
  metadata {
    name      = "sonarqube-eks-monitoring-password"
    namespace = "default"
  }
  data = {
    password = random_password.sonarqube_monitoring_password.result
  }

  type = "Opaque"

  depends_on = [
    time_sleep.wait_for_cluster
  ]
}

# Create Kubernetes ConfigMap for SonarQube JDBC configuration
resource "kubernetes_config_map" "sonarqube_opts" {
  metadata {
    name      = "sonarqube-opts"
    namespace = "default"
  }
  
  data = {
    SONAR_JDBC_USERNAME = var.db_username
    SONAR_JDBC_URL      = "jdbc:postgresql://${aws_db_instance.sonarqube.endpoint}/${aws_db_instance.sonarqube.db_name}"
  }

  depends_on = [
    time_sleep.wait_for_cluster,
    aws_db_instance.sonarqube
  ]
}

# Terraform outputs for RDS connection information
output "jdbc_url" {
  description = "JDBC connection URL for the RDS instance"
  value       = "jdbc:postgresql://${aws_db_instance.sonarqube.endpoint}/${aws_db_instance.sonarqube.db_name}"
  sensitive   = false
}

# Terraform outputs
output "cluster_name" {
  description = "Name of the EKS cluster"
  value       = var.cluster_name
  sensitive   = false
}

output "aws_region" {
  description = "AWS region"
  value       = var.aws_region
  sensitive   = false
}

output "domain_name" {
  description = "Base domain name"
  value       = var.domain_name
  sensitive   = false
}

output "acm_arn" {
  description = "ARN of the ACM certificate for SonarQube"
  value       = aws_acm_certificate_validation.sonarqube.certificate_arn
  sensitive   = false
}

output "route53_zone_id" {
  description = "Route53 hosted zone ID"
  value       = data.aws_route53_zone.existing.zone_id
  sensitive   = false
}

# Deploy SonarQube via Helm in Terraform with dynamic values
resource "helm_release" "sonarqube" {
  name       = "sonarqube"
  repository = "https://SonarSource.github.io/helm-chart-sonarqube"
  chart      = "sonarqube"
  namespace  = "default"
  version    = var.sonarqube_chart_version != "" ? var.sonarqube_chart_version : null

  values = [
    # Base values from the static file (without ingress)
    file("${path.module}/sonarqube-values.yaml"),
    # Dynamic ingress configuration with Terraform variables
    yamlencode({
      ingress = {
        enabled = true
        hosts = [
          {
            name        = "${var.host_name}.${var.domain_name}"
            path        = "/*"
            serviceName = "sonarqube-sonarqube"
            servicePort = 9000
            pathType    = "ImplementationSpecific"
          }
        ]
        annotations = {
          "kubernetes.io/ingress.class"                    = "alb"
          "alb.ingress.kubernetes.io/scheme"               = "internet-facing"
          "alb.ingress.kubernetes.io/target-type"          = "ip"
          "alb.ingress.kubernetes.io/listen-ports"         = "[{\"HTTP\": 80}, {\"HTTPS\": 443}]"
          "alb.ingress.kubernetes.io/ssl-redirect"         = "443"
          "alb.ingress.kubernetes.io/backend-protocol"     = "HTTP"
          "alb.ingress.kubernetes.io/healthcheck-path"     = "/api/system/status"
          "alb.ingress.kubernetes.io/healthcheck-protocol" = "HTTP"
          "alb.ingress.kubernetes.io/success-codes"        = "200"
          "alb.ingress.kubernetes.io/certificate-arn"      = aws_acm_certificate.sonarqube.arn
        }
      }
    })
  ]

  depends_on = [
    time_sleep.wait_for_cluster,
    helm_release.aws_load_balancer_controller,
    aws_acm_certificate_validation.sonarqube,
    kubernetes_secret.sonarqube_db_password,
    kubernetes_secret.sonarqube_monitoring_password,
    kubernetes_config_map.sonarqube_opts
  ]

  # Wait for SonarQube to be ready
  wait          = true
  wait_for_jobs = true
  timeout       = 900
}

output "sonarqube_url" {
  description = "Complete HTTPS URL for SonarQube"
  value       = "https://${var.host_name}.${var.domain_name}"
  sensitive   = false
}

output "load_balancer_dns" {
  description = "DNS name of the AWS Load Balancer"
  value       = data.aws_lb.sonarqube_alb.dns_name
  sensitive   = false
}

output "load_balancer_zone_id" {
  description = "Zone ID of the AWS Load Balancer"
  value       = data.aws_lb.sonarqube_alb.zone_id
  sensitive   = false
}

output "sonarqube_chart_version" {
  description = "Version of SonarQube Helm chart deployed (or 'latest' if using latest)"
  value       = var.sonarqube_chart_version != "" ? var.sonarqube_chart_version : "latest"
  sensitive   = false
}

output "alb_controller_chart_version" {
  description = "Version of AWS Load Balancer Controller Helm chart deployed (or 'latest' if using latest)"
  value       = var.alb_controller_chart_version != "" ? var.alb_controller_chart_version : "latest"
  sensitive   = false
}

output "sonarqube_jdbc_url" {
  description = "JDBC URL used by SonarQube to connect to the database"
  value       = "jdbc:postgresql://${aws_db_instance.sonarqube.endpoint}/${aws_db_instance.sonarqube.db_name}"
  sensitive   = false
}

output "sonarqube_jdbc_username" {
  description = "JDBC username used by SonarQube"
  value       = var.db_username
  sensitive   = false
}

