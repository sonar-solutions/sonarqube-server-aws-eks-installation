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
#
# List the hostname of the LLM provider registered in SonarQube
# (Administration > Configuration > AI Capabilities > LLM Providers).
# Supported provider types and the hostname to allow
# (see https://docs.sonarsource.com/sonarqube-server/instance-administration/ai-features/llm-providers):
#
#   Anthropic           api.anthropic.com
#   OpenAI              api.openai.com
#   Azure AI Foundry    your Azure resource endpoint host, e.g. <resource>.openai.azure.com or
#                       <resource>.services.ai.azure.com; through API Management, <apim-name>.azure-api.net
#   AWS Bedrock         bedrock-runtime.<region>.amazonaws.com
#                       The agents authenticate with an AWS identity, not an API key, and the agent runtimes
#                       get no IAM role in this template. Grant them one with bedrock:InvokeModel and
#                       bedrock:InvokeModelWithResponseStream, and with IRSA also allow sts.<region>.amazonaws.com.
#   AWS Bedrock Mantle  bedrock-mantle.<region>.api.aws (OpenAI-compatible; works with a Bedrock API key)
#   Custom              your OpenAI-compatible endpoint or AI gateway host, e.g.
#                       api.portkey.ai (Portkey), openrouter.ai (OpenRouter), or a self-hosted gateway such as LiteLLM
#
# Prefer exact hostnames: an entry with a leading dot (.example.com) also allows every subdomain.
# The proxy only allows ports 80 and 443.
variable "agent_egress_allowed_domains" {
  description = "Domains the agent runtimes may reach through the Agent Egress Proxy (your LLM provider API). The S3 bucket hostname is added automatically, and with enable_bedrock the Bedrock Runtime and STS hostnames too."
  type        = list(string)
  default     = ["bedrock-runtime.eu-central-1.amazonaws.com"]
}

# Amazon Bedrock as the LLM provider ("AWS Bedrock" provider type in SonarQube)
variable "enable_bedrock" {
  description = "Grant SonarQube Server and the agent runtimes the IAM permissions to invoke Amazon Bedrock models (bedrock:InvokeModel, bedrock:InvokeModelWithResponseStream), and allow the Bedrock Runtime and STS hostnames through the egress proxy."
  type        = bool
  default     = true
}

# Regions that may be registered for AWS Bedrock providers in SonarQube (one region per provider)
variable "bedrock_regions" {
  description = "AWS regions of the AWS Bedrock LLM providers registered in SonarQube. The agents can reach each region's Bedrock Runtime endpoint, and invoke its models and inference profiles."
  type        = list(string)
  default     = ["eu-central-1", "us-east-1"]

  validation {
    condition     = length(var.bedrock_regions) > 0
    error_message = "bedrock_regions must list at least one region (set enable_bedrock to false to disable Bedrock)."
  }
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
