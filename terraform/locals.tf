locals {
  stack_name       = "${var.project_name}-${var.environment}"
  key_pair_name    = "${var.project_name}-${var.environment}-key"
  ssh_bucket_name  = lower(replace("${var.project_name}-${var.environment}-${var.aws_region}-ssh-keys", "_", "-"))
  application_name = "aws-grafana-demo"
  namespace_name   = "aws-grafana"
}
