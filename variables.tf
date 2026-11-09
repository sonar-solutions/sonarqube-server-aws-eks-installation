# AWS region to deploy the required infrastructure
variable "aws_region" {
  description = "AWS region"
  type = string
  default = "eu-central-1"
}

# Name of the EKS cluster
variable "cluster_name" {
  description = "Name of the EKS cluster"
  type = string
  
  validation {
    condition     = length(var.cluster_name) > 0 && length(var.cluster_name) <= 21
    error_message = "The cluster_name must be between 1 and 21 characters. This ensures the ALB controller name_prefix (cluster_name + '-alb-controller-') stays within the AWS limit of 38 characters."
  }
}

# Version of the Kubernetes cluster
variable "kubernetes_version" {
  description = "Version of the Kubernetes cluster"
  type = string
}

# Environment of the cluster
variable "environment" {
  description = "Environment of the cluster"
  type = string
}

# CIDR block for the VPC
variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type = string
}

# Private subnets for the cluster
variable "private_subnets" {
  description = "Private subnets for the cluster"
  type = list(string)
}

# Public subnets for the cluster
variable "public_subnets" {
  description = "Public subnets for the cluster"
  type = list(string)
}

# Availability zones for the EKS cluster
variable "availability_zones" {
  description = "Availability zones for the cluster"
  type = list(string)
}

# AWS tag identifying owner of the resurces created
variable "owner_tag" {
  description = "Owner of the resources"
  type = string
}

# Instance types for the EKS node group
variable "node_instance_types" {
  description = "Instance types for the node group"
  type = list(string)
}

# Name for the EKS admin IAM role
variable "eks_admin_role_name" {
  description = "Name of the IAM role for EKS cluster administration"
  type        = string
  default     = "eks-cluster-admin"
}

# IAM path for the EKS admin role
variable "role_path" {
  description = "IAM path for IAM roles (e.g., /approles/ or /). Must start and end with /"
  type        = string
  default     = "/"
  
  validation {
    condition     = var.role_path == "" || can(regex("^/(.*/)?$", var.role_path))
    error_message = "role_path must be empty or start and end with '/' (e.g., '/approles/' or '/')."
  }
}

# IAM path for IAM policies
variable "policy_path" {
  description = "IAM path for IAM policies (e.g., /apppolicies/ or /). Must start and end with /"
  type        = string
  default     = "/"
  
  validation {
    condition     = var.policy_path == "" || can(regex("^/(.*/)?$", var.policy_path))
    error_message = "policy_path must be empty or start and end with '/' (e.g., '/apppolicies/' or '/')."
  }
}

# IAM permissions boundary for all roles
variable "iam_permissions_boundary" {
  description = "ARN of the IAM permissions boundary policy to attach to all IAM roles. Required by some AWS organizations with SCPs."
  type        = string
  default     = ""
  
  validation {
    condition     = var.iam_permissions_boundary == "" || can(regex("^arn:aws:iam::[0-9]{12}:policy/.*", var.iam_permissions_boundary))
    error_message = "The iam_permissions_boundary must be empty or a valid IAM policy ARN (e.g., 'arn:aws:iam::123456789012:policy/PolicyName')."
  }
}

# Public domain name for the EKS cluster
variable "domain_name" {
  description = "Domain name for the cluster"
  type = string
}

# Host name for the SonarQube instance
variable "host_name" {
  description = "Host name for the SonarQube instance"
  type = string
}

# Version of the SonarQube Helm chart to deploy. Leave empty for latest version.
variable "sonarqube_chart_version" {
  description = "Version of the SonarQube Helm chart to deploy. Leave empty for latest version."
  type        = string
  default     = ""
}

# Version of the AWS Load Balancer Controller Helm chart to deploy. Leave empty for latest version.
variable "alb_controller_chart_version" {
  description = "Version of the AWS Load Balancer Controller Helm chart to deploy. Leave empty for latest version."
  type        = string
  default     = ""
}

# name of the database
variable "db_name" {
  description = "Name of the database"
  type = string
}

# username of the database
variable "db_username" {
  description = "Username of the database"
  type = string
}

# ---------------------------------------------------------------------------
# Agentic features (Vortex, Hunter Agent, Remediation Agent) - SonarQube Server 2026.5+
# ---------------------------------------------------------------------------

# Deploy the Vortex analysis service
variable "enable_vortex_analysis" {
  description = "Deploy Vortex analysis. Forced on when enable_remediation_agent is true."
  type        = bool
  default     = true
}

# Deploy the Hunter Agent runtime (requires a Hunter Agent subscription in the license)
variable "enable_hunter_agent" {
  description = "Deploy the Hunter Agent runtime (and the Agent Orchestrator it needs)"
  type        = bool
  default     = true
}

# Deploy the Remediation Agent runtime (requires a Remediation Agent subscription in the license)
variable "enable_remediation_agent" {
  description = "Deploy the Remediation Agent runtime (and the Agent Orchestrator and Vortex it needs)"
  type        = bool
  default     = true
}

# Name of the S3 bucket shared by SonarQube, the Agent Orchestrator and Vortex. Leave empty to derive one.
variable "agentic_bucket_name" {
  description = "S3 bucket for agentic job artifacts and Vortex analysis context. Leave empty for <cluster_name>-agentic-<account_id>."
  type        = string
  default     = ""
}

# Hostnames the sandboxed agent runtimes may reach through the egress proxy.
# The agentic S3 bucket hostname is always added automatically.
variable "agent_egress_allowed_domains" {
  description = "Domains the agent runtimes may reach through the Agent Egress Proxy (your LLM provider API, e.g. api.anthropic.com or bedrock-runtime.<region>.amazonaws.com). The S3 bucket hostname is added automatically."
  type        = list(string)
  default     = ["api.anthropic.com"]
}

# Instance types for the dedicated, gVisor-sandboxed agent node group
variable "agent_node_instance_types" {
  description = "Instance types for the agent runtime node group. Hunter requests 8Gi memory per replica, so use at least 16 GiB instances."
  type        = list(string)
  default     = ["m6i.xlarge"]
}

# Desired number of nodes in the agent runtime node group
variable "agent_node_desired_size" {
  description = "Desired number of nodes in the agent runtime node group"
  type        = number
  default     = 1
}

# Let the chart install gVisor (runsc) on the agent nodes with a privileged DaemonSet
variable "gvisor_installer_enabled" {
  description = "Install gVisor on the agent nodes with the chart's privileged DaemonSet. Set to false if runsc is baked into the node image (recommended for production)."
  type        = bool
  default     = true
}
