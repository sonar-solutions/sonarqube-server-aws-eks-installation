# SonarQube Server Enterprise Edition - AWS Deployment Templates

This repository contains Terraform templates that fully automate the deployment of SonarQube Server Enterprise Edition in AWS cloud. The templates provide three different deployment options to suit various infrastructure requirements and preferences.

## 🏗️ Deployment Options

### 📁 `ec2/` - Amazon EC2 Deployment
Deploy SonarQube on a dedicated Amazon EC2 instance for traditional VM-based infrastructure.

**Use Cases:**
- Simple, straightforward deployments
- Organizations preferring traditional server management
- Development and testing environments
- Small to medium-scale code analysis requirements

📖 **[See ec2/README.md for detailed deployment instructions](ec2/README.md)**

### 📁 `ecs/` - Amazon ECS Deployment  
Deploy SonarQube on Amazon ECS (Elastic Container Service) for containerized workloads with managed orchestration.

**Use Cases:**
- Container-based infrastructure without Kubernetes complexity
- Serverless container management
- Cost-effective scaling for variable workloads
- Integration with existing ECS ecosystems

📖 **[See ecs/README.md for detailed deployment instructions](ecs/README.md)**

### 📁 `eks/` - Amazon EKS Deployment
Deploy SonarQube on Amazon EKS (Elastic Kubernetes Service) for enterprise-grade container orchestration.

**Use Cases:**
- Enterprise-scale deployments
- Kubernetes-native environments
- Advanced scaling and high availability requirements
- Integration with existing Kubernetes workflows

📖 **[See eks/README.md for detailed deployment instructions](eks/README.md)**

## 📋 General Prerequisites

- **Terraform**: Version >= 1.5.7
- **AWS CLI**: Configured with appropriate permissions
- **Domain**: Registered domain for SSL certificate and routing (recommended)

## 🚀 Quick Start

1. **Clone the repository**
   ```bash
   git clone <repository-url>
   cd sonarqube-server-aws-installation
   ```

2. **Choose your deployment method**
   - Navigate to the appropriate directory (`ec2/`, `ecs/`, or `eks/`)
   - Follow the specific README instructions for your chosen deployment

3. **Deploy**
   Each deployment option has its own configuration and deployment process detailed in their respective README files.

## 📝 License

[Add your license information here]

## 📞 Support

For issues and questions:
- Check the specific deployment README for troubleshooting
- Review AWS and SonarQube documentation
- Open an issue in this repository

---

**Current Status**: 
- ✅ **EKS**: Fully implemented and tested
- 🚧 **EC2**: Planned for future release
- 🚧 **ECS**: Planned for future release
