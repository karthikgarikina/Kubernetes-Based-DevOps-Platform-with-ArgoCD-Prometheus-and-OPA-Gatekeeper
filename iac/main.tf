# Root Infrastructure as Code (IaC) Entrypoint
# This module provides both cloud (AWS EKS) and local (Kind) orchestration.

module "cloud_infrastructure" {
  source = "./cloud"
  count  = 0 # Toggle to 1 when targeting AWS EKS production deployment
}

module "local_infrastructure" {
  source = "./local"
}
