output "instance_id" {
  description = "EC2 instance ID from the CloudFormation stack."
  value       = aws_cloudformation_stack.infrastructure.outputs["InstanceId"]
}

output "public_ip" {
  description = "Public IP of the EC2 instance."
  value       = aws_cloudformation_stack.infrastructure.outputs["PublicIp"]
}

output "public_dns" {
  description = "Public DNS of the EC2 instance."
  value       = aws_cloudformation_stack.infrastructure.outputs["PublicDnsName"]
}

output "vpc_id" {
  description = "VPC ID created by CloudFormation."
  value       = aws_cloudformation_stack.infrastructure.outputs["VpcId"]
}

output "subnet_id" {
  description = "Public subnet ID created by CloudFormation."
  value       = aws_cloudformation_stack.infrastructure.outputs["SubnetId"]
}

output "security_group_id" {
  description = "Security group ID created by CloudFormation."
  value       = aws_cloudformation_stack.infrastructure.outputs["SecurityGroupId"]
}

output "s3_bucket_name" {
  description = "S3 bucket name used to store the SSH private key."
  value       = aws_cloudformation_stack.infrastructure.outputs["S3BucketName"]
}

output "key_pair_name" {
  description = "Name of the generated EC2 key pair."
  value       = aws_cloudformation_stack.infrastructure.outputs["KeyPairName"]
}

output "application_url" {
  description = "Application URL served through the Kubernetes NodePort."
  value       = "http://${aws_cloudformation_stack.infrastructure.outputs["PublicIp"]}:30080"
}

output "grafana_url" {
  description = "Grafana URL exposed through the EC2 public IP."
  value       = "http://${aws_cloudformation_stack.infrastructure.outputs["PublicIp"]}:3000"
}
