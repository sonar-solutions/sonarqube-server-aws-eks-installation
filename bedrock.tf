# bedrock.tf
# IAM permissions and egress for Amazon Bedrock as the LLM provider of the agentic features
# ("AWS Bedrock" provider type in SonarQube). That provider type has no API key: SonarQube Server
# and the agent runtimes each use the AWS identity of their own pod, so both need these permissions.
# See https://docs.sonarsource.com/sonarqube-server/instance-administration/ai-features/llm-providers/aws-bedrock

locals {
  bedrock_enabled       = var.enable_bedrock && local.agentic_enabled
  agent_bedrock_enabled = local.bedrock_enabled && local.agents_enabled

  # The agent runtimes reach Bedrock through the egress proxy. They also need STS, to exchange
  # their ServiceAccount token for AWS credentials (IRSA uses the regional STS endpoint).
  bedrock_egress_domains = local.agent_bedrock_enabled ? [
    "bedrock-runtime.${var.bedrock_region}.amazonaws.com",
    "sts.${var.aws_region}.amazonaws.com",
  ] : []
}

# Invoke permissions only. Models in a region are often only offered through cross-region
# inference profiles (eu.* / global.*), which serve requests from foundation models in other
# regions, so the policy covers the profiles of bedrock_region and foundation models in any region.
resource "aws_iam_policy" "bedrock_invoke" {
  count       = local.bedrock_enabled ? 1 : 0
  name_prefix = "${var.cluster_name}-bedrock-"
  path        = var.policy_path != "" ? var.policy_path : "/"
  description = "Invoke Amazon Bedrock models for the SonarQube agentic features"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "bedrock:InvokeModel",
          "bedrock:InvokeModelWithResponseStream"
        ]
        Resource = [
          "arn:aws:bedrock:*::foundation-model/*",
          "arn:aws:bedrock:${var.bedrock_region}:${data.aws_caller_identity.current.account_id}:inference-profile/*",
          "arn:aws:bedrock:${var.bedrock_region}:${data.aws_caller_identity.current.account_id}:application-inference-profile/*"
        ]
      }
    ]
  })

  tags = {
    Name        = "${var.cluster_name}-bedrock-policy"
    Environment = var.environment
    Owner       = var.owner_tag
  }
}

# SonarQube Server checks the region and the model with its own identity when a model is selected
resource "aws_iam_role_policy_attachment" "sonarqube_server_bedrock" {
  count      = local.bedrock_enabled ? 1 : 0
  policy_arn = aws_iam_policy.bedrock_invoke[0].arn
  role       = aws_iam_role.sonarqube_server[0].name
}

# The Hunter and Remediation Agent runtimes call Bedrock directly during a job.
# A Bedrock-only role: the sandboxed runtimes get no access to the bucket or anything else.
resource "aws_iam_role" "agent_bedrock" {
  count                = local.agent_bedrock_enabled ? 1 : 0
  name_prefix          = "${var.cluster_name}-agent-bedrock-"
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
                local.hunter_agent_service_account,
                local.remediation_agent_service_account
              ] : "system:serviceaccount:${local.sonarqube_namespace}:${sa}"
            ]
            "${replace(module.eks.cluster_oidc_issuer_url, "https://", "")}:aud" = "sts.amazonaws.com"
          }
        }
      }
    ]
  })

  tags = {
    Name        = "${var.cluster_name}-agent-bedrock-role"
    Environment = var.environment
    Owner       = var.owner_tag
  }
}

resource "aws_iam_role_policy_attachment" "agent_bedrock" {
  count      = local.agent_bedrock_enabled ? 1 : 0
  policy_arn = aws_iam_policy.bedrock_invoke[0].arn
  role       = aws_iam_role.agent_bedrock[0].name
}

output "agent_bedrock_role_arn" {
  description = "ARN of the IRSA role the Hunter and Remediation Agent runtimes use to invoke Amazon Bedrock"
  value       = local.agent_bedrock_enabled ? aws_iam_role.agent_bedrock[0].arn : null
  sensitive   = false
}
