output "vpc_id" {
  description = "ID of the created platform VPC"
  value       = aws_vpc.platform_vpc.id
}

output "private_subnet_ids" {
  description = "IDs of the private subnets hosting worker nodes"
  value       = aws_subnet.private[*].id
}

output "public_subnet_ids" {
  description = "IDs of the public subnets hosting load balancers"
  value       = aws_subnet.public[*].id
}

output "cluster_name" {
  description = "Name of the provisioned EKS cluster"
  value       = aws_eks_cluster.eks.name
}

output "cluster_endpoint" {
  description = "Endpoint URL for Kubernetes control plane"
  value       = aws_eks_cluster.eks.endpoint
}

output "cluster_arn" {
  description = "ARN of the provisioned EKS cluster"
  value       = aws_eks_cluster.eks.arn
}

output "node_group_arn" {
  description = "ARN of the autoscaling managed node group"
  value       = aws_eks_node_group.platform_nodes.arn
}
