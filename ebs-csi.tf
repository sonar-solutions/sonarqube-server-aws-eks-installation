# ebs-csi.tf
# Amazon EBS CSI driver and a default gp3 StorageClass, so the chart can provision
# PersistentVolumeClaims (e.g. the SonarQube MCP server's /data volume).
# EKS clusters no longer ship a working default StorageClass.

# IAM role for the EBS CSI controller service account (IRSA)
resource "aws_iam_role" "ebs_csi_driver" {
  name_prefix          = "${var.cluster_name}-ebs-csi-"
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
            "${replace(module.eks.cluster_oidc_issuer_url, "https://", "")}:sub" = "system:serviceaccount:kube-system:ebs-csi-controller-sa"
            "${replace(module.eks.cluster_oidc_issuer_url, "https://", "")}:aud" = "sts.amazonaws.com"
          }
        }
      }
    ]
  })

  tags = {
    Name        = "${var.cluster_name}-ebs-csi-role"
    Environment = var.environment
    Owner       = var.owner_tag
  }
}

resource "aws_iam_role_policy_attachment" "ebs_csi_driver" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
  role       = aws_iam_role.ebs_csi_driver.name
}

# Default StorageClass backed by encrypted gp3 volumes. WaitForFirstConsumer creates each
# volume in the availability zone of the node its pod is scheduled on.
resource "kubernetes_storage_class" "gp3" {
  metadata {
    name = "gp3"
    annotations = {
      "storageclass.kubernetes.io/is-default-class" = "true"
    }
  }

  storage_provisioner    = "ebs.csi.aws.com"
  reclaim_policy         = "Delete"
  volume_binding_mode    = "WaitForFirstConsumer"
  allow_volume_expansion = true

  parameters = {
    type      = "gp3"
    encrypted = "true"
  }

  depends_on = [
    time_sleep.wait_for_cluster
  ]
}

output "ebs_csi_driver_role_arn" {
  description = "ARN of the IAM role used by the Amazon EBS CSI driver"
  value       = aws_iam_role.ebs_csi_driver.arn
  sensitive   = false
}
