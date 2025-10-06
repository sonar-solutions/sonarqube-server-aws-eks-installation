# efs.tf
resource "aws_efs_file_system" "sonarqube" {
  creation_token = "${var.cluster_name}-efs"
  performance_mode = "generalPurpose"
  throughput_mode = "bursting"
  encrypted = true
  
  tags = {
    Name = "${var.cluster_name}-efs"
    Environment = var.environment
    Owner = var.owner_tag
  }
}

resource "aws_efs_mount_target" "sonarqube" {
  count = length(module.vpc.private_subnets)
  file_system_id = aws_efs_file_system.sonarqube.id
  subnet_id = module.vpc.private_subnets[count.index]
  security_groups = [aws_security_group.efs.id]
}

resource "aws_security_group" "efs" {
  name_prefix = "${var.cluster_name}-efs-"
  description = "Security group for the SonarQube EFS instance"
  vpc_id = module.vpc.vpc_id

  ingress {
    from_port = 2049
    to_port = 2049
    protocol = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.cluster_name}-efs-sg"
    Environment = var.environment
    Owner = var.owner_tag
  }
}