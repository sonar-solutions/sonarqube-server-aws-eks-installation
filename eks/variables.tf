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

# ARN of the user
variable "user_arn" {
  description = "ARN of the user"
  type = string
}

# Public domain name for the EKS cluster
variable "domain_name" {
  description = "Domain name for the cluster"
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