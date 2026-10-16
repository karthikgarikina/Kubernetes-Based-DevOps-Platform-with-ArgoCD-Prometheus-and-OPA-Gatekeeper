# iac/local/main.tf: Declarative Terraform orchestration for local cluster
terraform {
  required_version = ">= 1.5.0"
}

variable "cluster_name" {
  description = "Local Kind cluster name"
  type        = string
  default     = "devops-platform"
}

variable "config_path" {
  description = "Path to Kind configuration YAML"
  type        = string
  default     = "kind-config.yaml"
}

resource "null_resource" "kind_cluster" {
  triggers = {
    config_hash = filemd5("/")
  }

  provisioner "local-exec" {
    command = "kind create cluster --name  --config /"
  }
}

output "cluster_name" {
  value = var.cluster_name
}
