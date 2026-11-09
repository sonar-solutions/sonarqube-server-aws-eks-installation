# SonarQube Server Enterprise Edition - EKS Deployment

This directory contains Terraform templates for deploying SonarQube Server Enterprise Edition on Amazon Elastic Kubernetes Service (EKS).

## ✅ Status: Fully Implemented and Tested

This deployment method is production-ready and includes all necessary components for a complete SonarQube installation.

## 🏗️ Infrastructure Components

- **EKS Cluster**: Managed Kubernetes cluster with configurable node groups
- **VPC & Networking**: Custom VPC with public/private subnets across multiple AZs
- **RDS Database**: Managed PostgreSQL database for SonarQube data persistence
- **Network Load Balancer**: AWS NLB with SSL/TLS termination
- **Route53 DNS**: Domain name management and DNS routing
- **ACM Certificate**: Automated SSL certificate provisioning
- **Agentic features** (SonarQube Server 2026.5+): Vortex analysis, Agent Orchestrator, Hunter Agent and Remediation Agent, with an S3 bucket, IRSA role, gVisor-sandboxed agent node group and egress proxy

## 🚀 Key Features

- **Helm-based Deployment**: Uses official SonarQube Helm charts
- **Version Management**: Configurable chart versions for production stability
- **Security**: IAM roles, security groups, and enforced Kubernetes NetworkPolicies
- **Scalability**: Managed node groups with configurable size limits

## 📋 Prerequisites

- **Terraform**: Essential for deploying the template
- **AWS CLI**
- **kubectl**: For Kubernetes cluster management
- **Helm**: Needed to deploy/diagnose charts
- **Domain**: A public Route53 hosted zone for `domain_name` in the target AWS account. Terraform looks it up and adds the DNS and certificate validation records; it does not create the zone
- **License** (agentic features only): Hunter Agent and Remediation Agent subscriptions on your SonarQube Server license

## 🛠️ Quick Start

1. **Configure variables**
   ```bash
   cp terraform.tfvars.json.example terraform.tfvars.json
   # Edit terraform.tfvars.json with your specific values
   ```
   Alternatively, you can use the supplied update_variables.py script:
   ```bash
   python3 ./update_variables.py
   ```

2. **Check available Helm chart versions** (optional)
   ```bash
   ./check-versions.sh
   ```

3. **Deploy infrastructure**
   ```bash
   terraform init
   terraform plan
   terraform apply
   ```

4. **Access SonarQube**
   - URL: `https://sonarqube.your-domain.com`
   - Default credentials: `admin/admin` (change immediately)

5. **Access the EKS Cluster** (for kubectl management)
   
   The cluster uses an IAM role for administration access. To interact with the cluster using kubectl:
   
   ```bash
   # Get the role ARN from Terraform outputs
   export ROLE_ARN=$(terraform output -raw eks_admin_role_arn)
   
   # Assume the role (replace with your session name)
   aws sts assume-role \
     --role-arn $ROLE_ARN \
     --role-session-name eks-admin-session \
     --external-id "$(terraform output -raw cluster_name)-eks-admin"
   
   # Configure AWS credentials with the temporary credentials from assume-role output
   export AWS_ACCESS_KEY_ID=<AccessKeyId from output>
   export AWS_SECRET_ACCESS_KEY=<SecretAccessKey from output>
   export AWS_SESSION_TOKEN=<SessionToken from output>
   
   # Update kubeconfig
   aws eks update-kubeconfig --name $(terraform output -raw cluster_name) --region $(terraform output -raw aws_region)
   
   # Verify access
   kubectl get nodes
   ```
   
   **Note**: Your IAM user/role must have permission to assume the EKS admin role in your AWS account.

## ⚙️ Configuration

### Required Variables
```json
{
  "aws_region": "eu-central-1",
  "cluster_name": "my-eks-cluster", 
  "kubernetes_version": "1.33",
  "environment": "Production",
  "vpc_cidr": "10.0.0.0/16",
  "private_subnets": ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"],
  "public_subnets": ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"],
  "availability_zones": ["eu-central-1a", "eu-central-1b", "eu-central-1c"],
  "owner_tag": "Your Name",
  "node_instance_types": ["t3.xlarge"],
  "eks_admin_role_name": "eks-cluster-admin",
  "role_path": "/",
  "policy_path": "/",
  "iam_permissions_boundary": "",
  "domain_name": "your-domain.com",
  "host_name": "sonarqube",
  "db_name": "sonarqube",
  "db_username": "sonarqube"
}
```

> With Vortex enabled, the `sonarqube` node group hosts SonarQube (4 GiB memory request) and Vortex (6 GiB memory request), so use instances with at least 16 GiB, e.g. `t3.xlarge`. `t3.large` is enough only when the agentic features are disabled.

### Optional Variables
- `sonarqube_chart_version`: Specific SonarQube Helm chart version (default: latest)
- `alb_controller_chart_version`: Specific ALB Controller chart version (default: latest)
- `eks_admin_role_name`: Name of the IAM role for EKS cluster administration (default: "eks-cluster-admin")
- `role_path`: IAM path for IAM roles created by this configuration (default: "/")
  - Applied to: EKS cluster, node group, EKS admin, ALB controller and agentic storage (IRSA) roles
  - Must start and end with `/` (e.g., `/approles/`, `/service-roles/`, or `/`)
  - Required if your AWS organization has SCPs restricting IAM role creation paths
- `policy_path`: IAM path for IAM policies created by this configuration (default: "/")
  - Applied to: ALB controller and agentic storage policies
  - Must start and end with `/` (e.g., `/apppolicies/`, `/service-policies/`, or `/`)
  - Required if your AWS organization has SCPs mandating specific policy paths
- `iam_permissions_boundary`: ARN of the IAM permissions boundary policy to attach to all IAM roles (default: "")
  - Example: `"arn:aws:iam::123456789012:policy/AppPermissionsBoundary-V1"`
  - Required if your AWS organization has SCPs mandating permissions boundaries
  - Leave empty if not required by your organization
- `enable_vortex_analysis`, `enable_hunter_agent`, `enable_remediation_agent`: Deploy the agentic components (default: `true`). See [Agentic features](#-agentic-features-vortex-hunter-agent-remediation-agent)
- `agentic_bucket_name`: S3 bucket for agentic storage (default: `<cluster_name>-agentic-<account_id>`)
- `agent_egress_allowed_domains`: Hostnames the agent runtimes may reach, i.e. your LLM provider API (default: `["api.anthropic.com"]`). The S3 bucket hostname is added automatically
- `agent_node_instance_types`: Instance types for the agent runtime node group (default: `["m6i.xlarge"]`)
- `agent_node_desired_size`: Number of agent runtime nodes (default: `1`)
- `gvisor_installer_enabled`: Install gVisor with the chart's privileged DaemonSet (default: `true`). See [Sandbox runtime](#sandbox-runtime)

## 🤖 Agentic features (Vortex, Hunter Agent, Remediation Agent)

SonarQube Server 2026.5+ can run AI agents next to the server. This template deploys every component required by the [AI agents installation guide](https://docs.sonarsource.com/sonarqube-server/server-installation/ai-agents) through the [Helm chart's agentic values](https://github.com/SonarSource/helm-chart-sonarqube/tree/master/charts/sonarqube#agentic-features). Use chart version `2026.5.1000` or later (the default, latest, satisfies this).

### Components deployed by the Helm chart

| Component | Enabled by | Runs on |
| --- | --- | --- |
| Vortex analysis | `enable_vortex_analysis` or `enable_remediation_agent` | `sonarqube` node group |
| Agent Orchestrator | `enable_hunter_agent` or `enable_remediation_agent` | `sonarqube` node group |
| Hunter Agent runtime | `enable_hunter_agent` | `agent_runtime` node group, gVisor sandbox |
| Remediation Agent runtime | `enable_remediation_agent` | `agent_runtime` node group, gVisor sandbox |
| Agent Egress Proxy (Squid, 2 replicas) | any agent | `sonarqube` node group |
| gVisor installer DaemonSet | `gvisor_installer_enabled` | `agent_runtime` node group |
| Key derivation hook Job | any agentic component | any node |

### AWS and Kubernetes resources provisioned by Terraform (`agentic.tf`)

- **S3 bucket** shared by SonarQube (agent job logs), the Agent Orchestrator (job artifacts) and Vortex (analysis context). It is private, encrypted (SSE-S3), TLS-only, and has a lifecycle rule that aborts incomplete multipart uploads. Artifact retention is managed in SonarQube (**General Settings > Housekeeping > Agentic**, 30 days by default).
- **S3 gateway VPC endpoint**, so bucket traffic from the private subnets doesn't go through the NAT gateways.
- **IRSA role** (honours `role_path`, `policy_path` and `iam_permissions_boundary`) with read/write access to the bucket. It is trusted only by the `sonarqube-server`, `sonarqube-agent-orchestrator` and `sonarqube-vortex` ServiceAccounts. The agent runtimes and the egress proxy get their own ServiceAccounts without an IAM role: the agents use presigned URLs.
- **Agentic signing secret** (`agentic-instance-secret`). Every component's signing keys are derived from it.
- **Settings encryption key** (`sonarqube-settings-encryption-key`, mounted as `sonar.secretKeyPath`). It encrypts secrets such as the LLM provider API key, and the Agent Orchestrator receives a copy. Don't rotate it once secrets are stored.
- **Agent runtime node group**: dedicated nodes with a 100 GiB root volume, labeled and tainted `sonarqube.org/agent-runtime=true:NoSchedule`, so only the sandboxed agents run there.
- **NetworkPolicy enforcement** in the VPC CNI add-on (`enableNetworkPolicy`), so the chart's NetworkPolicies actually restrict the agent runtimes to the egress proxy.
- **Database**: SonarQube and the Agent Orchestrator share the RDS database through the chart's `jdbcOverwrite` values (`sslmode=require`). The former `sonarqube-opts` ConfigMap has been removed because the agentic features don't support `extraConfig` for JDBC settings.

### Sandbox runtime

By default, the chart's gVisor installer, a **privileged** DaemonSet, installs `runsc` into containerd on the agent nodes only, then labels them `gvisor.enabled=true`. That's convenient for evaluation. For production, bake `runsc` into a custom node AMI, then set `gvisor_installer_enabled` to `false`. Terraform then adds the `gvisor.enabled=true` label to the agent nodes itself.

The agent runtimes need x86-64 or ARM64 nodes running natively. If you choose Graviton instance types for `agent_node_instance_types`, also set a matching `ami_type` on the node group.

### Network egress

The agent runtimes reach the internet only through the Agent Egress Proxy, which allows only `agent_egress_allowed_domains` plus the S3 bucket hostname. Set this variable to your LLM provider's API hostname, for example:

```json
"agent_egress_allowed_domains": ["api.anthropic.com"]
```

or `["bedrock-runtime.eu-central-1.amazonaws.com"]` for Amazon Bedrock. The Agent Orchestrator clones repositories and opens pull requests itself, so the DevOps platform doesn't need to be listed.

### After `terraform apply`

1. **License**: add the Hunter Agent and Remediation Agent subscriptions to your license (contact Sonar Sales).
2. **LLM provider**: in **Administration > Configuration > AI Capabilities > LLM Providers**, register a provider and model. The agent toggles stay locked until you do.
3. **Projects**: bind each project to a DevOps repository (a GitHub App integration is required for the Remediation Agent to open pull requests), and analyze it at least once.
4. **Verify**: `kubectl get pods -n default` should show the Vortex, agent orchestrator, hunter, remediation and egress-proxy pods as `Running`. Vortex can take several minutes to become ready on first start. See [Verifying the deployment](https://docs.sonarsource.com/sonarqube-server/server-installation/ai-agents/verifying-the-deployment).

To deploy SonarQube without the agentic features, set `enable_vortex_analysis`, `enable_hunter_agent` and `enable_remediation_agent` to `false`. No agentic AWS resources, secrets or node group are created then.

## 🔧 Utilities

### Version Checker Script
The `check-versions.sh` script helps you:
- View available Helm chart versions
- Check current deployment status
- Get usage examples for version pinning

```bash
./check-versions.sh
```

### Variable Update Script
The `update_variables.py` script assists with configuration management and variable updates.

## 📁 Terraform Configuration Files

This project is organized into modular Terraform files, each handling specific infrastructure components:

### `main.tf`
The primary configuration file containing:
- Terraform and provider configurations (AWS, Kubernetes, Helm, HTTP, Time)
- VPC module setup with public/private subnets, NAT gateways, and DNS settings
- EKS cluster configuration with managed node groups and cluster addons (CoreDNS, kube-proxy, VPC-CNI)
- Kubernetes secrets for database credentials and the settings encryption key
- Random password generation for database and monitoring
- SonarQube Helm chart deployment with JDBC, load balancer and agentic configuration
- Optional agent runtime node group for the sandboxed Hunter and Remediation Agents
- Multiple outputs for cluster information, URLs, and connection details

### `variables.tf`
Defines all input variables used across the infrastructure:
- AWS region, cluster name, and Kubernetes version
- Network configuration (VPC CIDR, subnets, availability zones)
- Instance types and node group settings
- Domain and host names for DNS configuration
- Database credentials (name and username)
- Optional Helm chart version pinning
- IAM role/policy paths and permissions boundary
- Owner tags
- Agentic feature toggles, S3 bucket name, egress allowlist, agent node group sizing and gVisor installer toggle

### `agentic.tf`
Resources for the agentic features (Vortex, Hunter Agent, Remediation Agent):
- S3 bucket, bucket policy and S3 gateway VPC endpoint
- IRSA role and policy for SonarQube, the Agent Orchestrator and Vortex
- Agentic signing secret
- Outputs for the bucket name, IRSA role ARN and egress allowlist
- Helm values for the agentic components, gVisor sandbox and egress proxy

### `rds.tf`
PostgreSQL database infrastructure:
- RDS subnet group for database placement in private subnets
- Security group restricting database access to EKS nodes only
- RDS PostgreSQL instance with encryption, automated backups, and auto-scaling storage
- Configuration for maintenance windows and backup retention

### `alb-controller.tf`
AWS Load Balancer Controller deployment:
- IAM policy and role with OIDC federation for service account
- Kubernetes service account with IAM role annotation
- Helm deployment of AWS Load Balancer Controller
- Required permissions for managing AWS Network Load Balancers

### `acm.tf`
SSL/TLS certificate management:
- AWS Certificate Manager (ACM) certificate request for the SonarQube domain
- DNS validation method configuration
- Lifecycle management to prevent resource recreation issues

### `route53.tf`
DNS and certificate validation:
- Route53 hosted zone lookup for existing domain
- A record (alias) pointing to the NLB created by the AWS Load Balancer Controller
- ACM certificate validation records
- Certificate validation resource to wait for DNS propagation

## 🏢 AWS Resources Created

- EKS Cluster with managed node groups (plus the agent runtime node group when an agent is enabled)
- VPC with public/private subnets
- Internet Gateway and NAT Gateways
- Route tables and security groups
- RDS PostgreSQL instance
- Network Load Balancer (created by the AWS Load Balancer Controller)
- Route53 records in the existing hosted zone
- ACM SSL certificate
- S3 bucket and S3 gateway VPC endpoint (agentic features)
- IAM roles and policies
- CloudWatch log groups

## 🔒 Security Features

- HTTPS/TLS at the NLB, and TLS (`sslmode=require`) between SonarQube/the Agent Orchestrator and RDS
- Generated database, monitoring, signing and settings encryption secrets stored as Kubernetes Secrets (never in variables)
- IAM roles scoped per component (IRSA), with optional role/policy paths and permissions boundary
- Security groups restrict database access to the EKS nodes only
- Private subnets for worker nodes and database; encrypted node volumes, RDS storage and S3 bucket
- Agent runtimes sandboxed with gVisor on dedicated nodes, with egress limited to an allowlist by the egress proxy and enforced NetworkPolicies

## 🧹 Tearing down

Destroy the SonarQube Helm release first, while the AWS Load Balancer Controller is still running, so it deletes the NLB and security groups it created. Then destroy everything else:

```bash
terraform destroy -target=aws_route53_record.sonarqube -target=helm_release.sonarqube
terraform destroy
```

The agentic S3 bucket is created with `force_destroy`, so it is deleted along with any remaining job artifacts.

## ⚠️ Known Issue: `terraform destroy` VPC Deletion Failure

### What happens

A plain `terraform destroy` (without the targeted step above) may fail with errors like:

```
Error: deleting EC2 Subnet (...): DependencyViolation: The subnet '...' has dependencies and cannot be deleted.
Error: deleting EC2 Internet Gateway (...): Network ... has some mapped public address(es).
Error: deleting EC2 VPC (...): DependencyViolation: The vpc '...' has dependencies and cannot be deleted.
```

### Why it happens

The AWS Load Balancer Controller (running inside the cluster) creates an NLB, security groups, and cross-SG ingress rules when the SonarQube service is provisioned. These resources are **not tracked in Terraform state** because they are created by the controller at runtime, not by Terraform directly. When `terraform destroy` tears down the EKS cluster it does not know to clean these up first, leaving them attached to the VPC.

### How to fix

Run the following before retrying `terraform destroy`:

```bash
AWS_REGION=$(python3 -c "import json; print(json.load(open('terraform.tfvars.json'))['aws_region'])")

VPC_ID=$(terraform output -json | python3 -c "import json,sys; print([v for k,v in json.load(sys.stdin).items() if 'vpc' in k.lower()][0]['value'])" 2>/dev/null || \
  aws ec2 describe-vpcs --region "$AWS_REGION" --filters "Name=tag:Name,Values=*sonarqube*" --query 'Vpcs[0].VpcId' --output text)

# 1. Delete the NLB
ALB_ARNS=$(aws elbv2 describe-load-balancers --region "$AWS_REGION" \
  --query "LoadBalancers[?VpcId=='$VPC_ID'].LoadBalancerArn" --output text)
for arn in $ALB_ARNS; do
  aws elbv2 delete-load-balancer --region "$AWS_REGION" --load-balancer-arn "$arn"
done
sleep 30

# 2. Revoke cross-SG rules and delete leftover k8s security groups
K8S_SGS=$(aws ec2 describe-security-groups --region "$AWS_REGION" \
  --filters "Name=vpc-id,Values=$VPC_ID" "Name=group-name,Values=k8s-*" \
  --query 'SecurityGroups[*].GroupId' --output text)

# Revoke any ingress rules referencing these SGs from other SGs in the VPC
for sg in $K8S_SGS; do
  REFS=$(aws ec2 describe-security-groups --region "$AWS_REGION" \
    --filters "Name=vpc-id,Values=$VPC_ID" \
    --query "SecurityGroups[?IpPermissions[?UserIdGroupPairs[?GroupId=='$sg']]].GroupId" \
    --output text)
  for ref_sg in $REFS; do
    RULES=$(aws ec2 describe-security-groups --region "$AWS_REGION" --group-ids "$ref_sg" \
      --query "SecurityGroups[0].IpPermissions[?UserIdGroupPairs[?GroupId=='$sg']]" \
      --output json)
    aws ec2 revoke-security-group-ingress --region "$AWS_REGION" \
      --group-id "$ref_sg" --ip-permissions "$RULES"
  done
  aws ec2 delete-security-group --region "$AWS_REGION" --group-id "$sg"
done

# 3. Retry
terraform destroy -auto-approve
```

## 📄 License

This project is licensed under the [GNU Lesser General Public License v3.0](LICENSE).
