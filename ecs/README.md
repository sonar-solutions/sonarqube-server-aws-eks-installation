# SonarQube Server Enterprise Edition - ECS Deployment

This directory contains Terraform templates for deploying SonarQube Server Enterprise Edition on Amazon ECS (Elastic Container Service).

## 🚧 Status: In Development

This deployment method is currently being developed and is not yet available for use.

## 📋 What Will Be Included

When complete, this directory will contain:

- **ECS Cluster** configuration with Fargate or EC2 launch types
- **Task definitions** for SonarQube containers
- **Service definitions** with auto-scaling capabilities
- **RDS database** setup for data persistence
- **EFS storage** for shared file systems
- **Load balancer** integration
- **SSL/TLS certificate** management

## 🎯 Deployment Features (Planned)

- **ECS Cluster**: Managed container orchestration
- **Fargate Support**: Serverless container execution
- **Auto Scaling**: Dynamic scaling based on demand
- **Database**: Managed RDS PostgreSQL database
- **Storage**: EFS for persistent and shared storage
- **Security**: IAM roles, security groups, and task-level permissions
- **Networking**: VPC with public/private subnet configuration
- **Load Balancing**: Application Load Balancer with health checks
- **SSL/TLS**: Automated certificate provisioning via ACM

## 💡 Use Cases

This deployment method will be ideal for:

- Container-based infrastructure without Kubernetes complexity
- Serverless container management with Fargate
- Cost-effective scaling for variable workloads
- Integration with existing ECS ecosystems
- Organizations preferring managed container services
- Medium to large-scale deployments with dynamic scaling needs

## 📞 Status Updates

Check back for updates or watch this repository for notifications when the ECS deployment becomes available.

For immediate SonarQube deployment needs, consider using the [EKS deployment](../eks/README.md) which is fully implemented and tested.
