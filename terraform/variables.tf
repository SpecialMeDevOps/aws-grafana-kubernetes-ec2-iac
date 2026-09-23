variable "project_name" {
  description = "Project name used in tags and naming conventions."
  type        = string
  default     = "aws-grafana-kubernetes-ec2-iac"
}

variable "environment" {
  description = "Deployment environment."
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be one of: dev, staging, prod."
  }
}

variable "aws_region" {
  description = "AWS region where the stack is deployed."
  type        = string
  default     = "us-east-1"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC."
  type        = string
  default     = "10.10.0.0/16"
}

variable "public_subnet_cidr" {
  description = "CIDR block for the public subnet."
  type        = string
  default     = "10.10.1.0/24"
}

variable "instance_type" {
  description = "EC2 instance type for the Kubernetes node."
  type        = string
  default     = "t3.medium"
}

variable "ssh_location_cidr" {
  description = "CIDR allowed to reach SSH over port 22."
  type        = string
  default     = "0.0.0.0/0"
}

variable "app_port" {
  description = "Application HTTP port exposed to the load balancer or service."
  type        = number
  default     = 80
}

variable "grafana_port" {
  description = "Port for Grafana UI."
  type        = number
  default     = 3000
}

variable "node_port" {
  description = "NodePort exposed by the Kubernetes app service."
  type        = number
  default     = 30080
}

variable "bootstrap_script_url" {
  description = "URL to the wrapper bootstrap script hosted in the repository."
  type        = string
  default     = "https://raw.githubusercontent.com/SpecialMeDevOps/aws-grafana-kubernetes-ec2-iac/main/scripts/bootstrap.sh"
}

variable "github_repository" {
  description = "Repository used for bootstrap and documentation references."
  type        = string
  default     = "SpecialMeDevOps/aws-grafana-kubernetes-ec2-iac"
}
