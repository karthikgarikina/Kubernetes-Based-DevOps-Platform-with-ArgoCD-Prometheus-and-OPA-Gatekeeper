variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "us-east-1"
}

variable "cluster_name" {
  description = "Name of the Kubernetes EKS cluster"
  type        = string
  default     = "devops-platform-eks"
}

variable "kubernetes_version" {
  description = "Kubernetes control plane version"
  type        = string
  default     = "1.31"
}

variable "vpc_cidr" {
  description = "CIDR block for the Virtual Private Cloud"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnets" {
  description = "Public subnet CIDRs for ingress and NAT Gateways"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
}

variable "private_subnets" {
  description = "Private subnet CIDRs for Kubernetes worker nodes and workloads"
  type        = list(string)
  default     = ["10.0.10.0/24", "10.0.11.0/24", "10.0.12.0/24"]
}

variable "node_min_size" {
  description = "Minimum number of worker nodes for autoscaling"
  type        = number
  default     = 2
}

variable "node_max_size" {
  description = "Maximum number of worker nodes for autoscaling"
  type        = number
  default     = 6
}

variable "node_desired_size" {
  description = "Desired number of worker nodes at startup"
  type        = number
  default     = 3
}

variable "instance_types" {
  description = "EC2 instance types for the worker node group"
  type        = list(string)
  default     = ["t3.medium", "t3.large"]
}
