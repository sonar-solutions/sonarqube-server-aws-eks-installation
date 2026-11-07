# agentic.tf
# AWS and Kubernetes resources required by the SonarQube Server agentic features:
# Vortex analysis, the Agent Orchestrator, the Hunter Agent and the Remediation Agent.
# See https://docs.sonarsource.com/sonarqube-server/server-installation/ai-agents and
# https://github.com/SonarSource/helm-chart-sonarqube/tree/master/charts/sonarqube#agentic-features

locals {
  # The Remediation Agent verifies its fixes with Vortex, so it always brings Vortex along
  vortex_enabled  = var.enable_vortex_analysis || var.enable_remediation_agent
  agents_enabled  = var.enable_hunter_agent || var.enable_remediation_agent
  agentic_enabled = local.vortex_enabled || local.agents_enabled

  sonarqube_namespace = "default"

  agentic_bucket_name = var.agentic_bucket_name != "" ? var.agentic_bucket_name : lower("${var.cluster_name}-agentic-${data.aws_caller_identity.current.account_id}")
  # Virtual-hosted-style hostname used by the presigned URLs the agent runtimes download through the egress proxy
  agentic_bucket_host = "${local.agentic_bucket_name}.s3.${var.aws_region}.amazonaws.com"

  # ServiceAccounts that access the bucket with their IAM identity (IRSA).
  # The agent runtimes only use presigned URLs and keep their own, role-less ServiceAccounts.
  sonarqube_service_account          = "sonarqube-server"
  agent_orchestrator_service_account = "sonarqube-agent-orchestrator"
  vortex_service_account             = "sonarqube-vortex"

  # Label and taint of the dedicated node group running the sandboxed agent runtimes
  agent_node_label_key = "sonarqube.org/agent-runtime"
  agent_node_labels = {
    (local.agent_node_label_key) = "true"
  }
  agent_tolerations = [
    {
      key      = local.agent_node_label_key
      operator = "Equal"
      value    = "true"
      effect   = "NoSchedule"
    }
  ]

  agentic_signing_secret_name = "agentic-instance-secret"
  agentic_signing_secret_key  = "instance-secret"

  agentic_irsa_annotations = local.agentic_enabled ? {
    "eks.amazonaws.com/role-arn" = aws_iam_role.agentic_storage[0].arn
  } : {}

  # Extra Helm values for the SonarQube release, empty when no agentic component is enabled
  agentic_helm_values = local.agentic_enabled ? [
    yamlencode({
      # SonarQube reads the agent job logs from the shared bucket
      sonarProperties = {
        "sonar.agentic.storage.type"   = "S3"
        "sonar.agentic.storage.bucket" = local.agentic_bucket_name
        "sonar.agentic.storage.region" = var.aws_region
      }
      serviceAccount = {
        create         = true
        name           = local.sonarqube_service_account
        automountToken = true
        annotations    = local.agentic_irsa_annotations
      }
      agenticSigningSecret = {
        existingSecret = local.agentic_signing_secret_name
        key            = local.agentic_signing_secret_key
      }
      vortexAnalysis = {
        serviceAccount = {
          create         = true
          name           = local.vortex_service_account
          automountToken = true
          annotations    = local.agentic_irsa_annotations
        }
        storage = {
          type            = "S3"
          bucket          = local.agentic_bucket_name
          region          = var.aws_region
          pathStyleAccess = false
        }
      }
      agentOrchestrator = {
        serviceAccount = {
          create         = true
          name           = local.agent_orchestrator_service_account
          automountToken = true
          annotations    = local.agentic_irsa_annotations
        }
        storage = {
          type      = "S3"
          bucket    = local.agentic_bucket_name
          region    = var.aws_region
          pathStyle = false
        }
      }
      hunterAgent = {
        nodeSelector   = local.agent_node_labels
        tolerations    = local.agent_tolerations
        serviceAccount = { create = true }
      }
      remediationAgent = {
        nodeSelector   = local.agent_node_labels
        tolerations    = local.agent_tolerations
        serviceAccount = { create = true }
      }
      # gVisor sandbox for the agent runtimes, installed only on the agent node group
      gvisor = {
        enabled = true
        installer = {
          enabled      = var.gvisor_installer_enabled
          nodeSelector = local.agent_node_labels
        }
      }
      # The only way out of the cluster for the agent runtimes
      agentEgressProxy = {
        allowedDomains = distinct(concat(var.agent_egress_allowed_domains, [local.agentic_bucket_host]))
        # Own ServiceAccount so the proxy does not inherit SonarQube's IAM role
        serviceAccount = { create = true }
      }
    })
  ] : []
}

# ---------------------------------------------------------------------------
# Shared storage: S3 bucket for agent job artifacts, agent logs and Vortex analysis context
# ---------------------------------------------------------------------------

resource "aws_s3_bucket" "agentic" {
  count  = local.agentic_enabled ? 1 : 0
  bucket = local.agentic_bucket_name

  # Artifacts are short-lived (SonarQube purges them after 30 days by default),
  # so allow terraform destroy to remove a non-empty bucket
  force_destroy = true

  tags = {
    Name        = local.agentic_bucket_name
    Environment = var.environment
    Owner       = var.owner_tag
  }
}

resource "aws_s3_bucket_public_access_block" "agentic" {
  count  = local.agentic_enabled ? 1 : 0
  bucket = aws_s3_bucket.agentic[0].id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_ownership_controls" "agentic" {
  count  = local.agentic_enabled ? 1 : 0
  bucket = aws_s3_bucket.agentic[0].id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "agentic" {
  count  = local.agentic_enabled ? 1 : 0
  bucket = aws_s3_bucket.agentic[0].id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "agentic" {
  count  = local.agentic_enabled ? 1 : 0
  bucket = aws_s3_bucket.agentic[0].id

  # Retention of job artifacts is managed by SonarQube (General Settings > Housekeeping > Agentic);
  # only clean up uploads interrupted by a failed job here
  rule {
    id     = "abort-incomplete-multipart-uploads"
    status = "Enabled"

    filter {}

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}

# Reject any request that is not sent over TLS
resource "aws_s3_bucket_policy" "agentic" {
  count  = local.agentic_enabled ? 1 : 0
  bucket = aws_s3_bucket.agentic[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "DenyInsecureTransport"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"
        Resource = [
          aws_s3_bucket.agentic[0].arn,
          "${aws_s3_bucket.agentic[0].arn}/*"
        ]
        Condition = {
          Bool = {
            "aws:SecureTransport" = "false"
          }
        }
      }
    ]
  })

  depends_on = [aws_s3_bucket_public_access_block.agentic]
}

# Keep S3 traffic from the private subnets inside the AWS network instead of going through the NAT gateways
resource "aws_vpc_endpoint" "s3" {
  count             = local.agentic_enabled ? 1 : 0
  vpc_id            = module.vpc.vpc_id
  service_name      = "com.amazonaws.${var.aws_region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = module.vpc.private_route_table_ids

  tags = {
    Name        = "${var.cluster_name}-s3-endpoint"
    Environment = var.environment
    Owner       = var.owner_tag
  }
}

# ---------------------------------------------------------------------------
# IRSA: IAM role giving SonarQube, the Agent Orchestrator and Vortex access to the bucket
# ---------------------------------------------------------------------------

resource "aws_iam_policy" "agentic_storage" {
  count       = local.agentic_enabled ? 1 : 0
  name_prefix = "${var.cluster_name}-agentic-s3-"
  path        = var.policy_path != "" ? var.policy_path : "/"
  description = "Access to the SonarQube agentic storage bucket"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:ListBucket",
          "s3:GetBucketLocation",
          "s3:ListBucketMultipartUploads"
        ]
        Resource = aws_s3_bucket.agentic[0].arn
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:AbortMultipartUpload",
          "s3:ListMultipartUploadParts"
        ]
        Resource = "${aws_s3_bucket.agentic[0].arn}/*"
      }
    ]
  })

  tags = {
    Name        = "${var.cluster_name}-agentic-s3-policy"
    Environment = var.environment
    Owner       = var.owner_tag
  }
}

resource "aws_iam_role" "agentic_storage" {
  count                = local.agentic_enabled ? 1 : 0
  name_prefix          = "${var.cluster_name}-agentic-s3-"
  path                 = var.role_path != "" ? var.role_path : "/"
  permissions_boundary = var.iam_permissions_boundary != "" ? var.iam_permissions_boundary : null

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRoleWithWebIdentity"
        Effect = "Allow"
        Principal = {
          Federated = module.eks.oidc_provider_arn
        }
        Condition = {
          StringEquals = {
            "${replace(module.eks.cluster_oidc_issuer_url, "https://", "")}:sub" = [
              for sa in [
                local.sonarqube_service_account,
                local.agent_orchestrator_service_account,
                local.vortex_service_account
              ] : "system:serviceaccount:${local.sonarqube_namespace}:${sa}"
            ]
            "${replace(module.eks.cluster_oidc_issuer_url, "https://", "")}:aud" = "sts.amazonaws.com"
          }
        }
      }
    ]
  })

  tags = {
    Name        = "${var.cluster_name}-agentic-s3-role"
    Environment = var.environment
    Owner       = var.owner_tag
  }
}

resource "aws_iam_role_policy_attachment" "agentic_storage" {
  count      = local.agentic_enabled ? 1 : 0
  policy_arn = aws_iam_policy.agentic_storage[0].arn
  role       = aws_iam_role.agentic_storage[0].name
}

# ---------------------------------------------------------------------------
# Signing secret: every key the agentic components sign their messages with is derived from it
# ---------------------------------------------------------------------------

resource "random_password" "agentic_instance_secret" {
  count   = local.agentic_enabled ? 1 : 0
  length  = 64
  special = false
}

resource "kubernetes_secret" "agentic_instance_secret" {
  count = local.agentic_enabled ? 1 : 0

  metadata {
    name      = local.agentic_signing_secret_name
    namespace = local.sonarqube_namespace
  }
  data = {
    (local.agentic_signing_secret_key) = random_password.agentic_instance_secret[0].result
  }

  type = "Opaque"

  depends_on = [
    time_sleep.wait_for_cluster
  ]
}

# ---------------------------------------------------------------------------
# Outputs
# ---------------------------------------------------------------------------

output "agentic_bucket_name" {
  description = "S3 bucket shared by SonarQube, the Agent Orchestrator and Vortex"
  value       = local.agentic_enabled ? aws_s3_bucket.agentic[0].id : null
  sensitive   = false
}

output "agentic_storage_role_arn" {
  description = "ARN of the IRSA role used by SonarQube, the Agent Orchestrator and Vortex to access the bucket"
  value       = local.agentic_enabled ? aws_iam_role.agentic_storage[0].arn : null
  sensitive   = false
}

output "agent_egress_allowed_domains" {
  description = "Domains the agent runtimes may reach through the Agent Egress Proxy"
  value       = local.agentic_enabled ? distinct(concat(var.agent_egress_allowed_domains, [local.agentic_bucket_host])) : []
  sensitive   = false
}
