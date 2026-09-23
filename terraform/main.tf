data "aws_ami" "amazon_linux_2" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
}

resource "aws_cloudformation_stack" "infrastructure" {
  name          = local.stack_name
  template_body = file("${path.module}/../cloudformation/infrastructure.yaml")
  capabilities  = ["CAPABILITY_IAM"]

  parameters = {
    ProjectName        = var.project_name
    Environment        = var.environment
    VpcCidr            = var.vpc_cidr
    PublicSubnetCidr   = var.public_subnet_cidr
    InstanceType       = var.instance_type
    KeyPairName        = local.key_pair_name
    S3BucketName       = local.ssh_bucket_name
    SSHLocation        = var.ssh_location_cidr
    AppPort            = tostring(var.app_port)
    GrafanaPort        = tostring(var.grafana_port)
    NodePort           = tostring(var.node_port)
    LatestAmiId        = data.aws_ami.amazon_linux_2.id
    BootstrapScriptUrl = var.bootstrap_script_url
    GitHubRepository   = var.github_repository
  }

  on_failure         = "DELETE"
  timeout_in_minutes = 45
}
