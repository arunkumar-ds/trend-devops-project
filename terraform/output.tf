output "jenkins_ip" {
  value = aws_instance.jenkins.public_ip
}

output "eks_cluster_name" {
  value = module.eks.cluster_name
}
