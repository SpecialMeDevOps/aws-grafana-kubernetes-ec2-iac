#!/usr/bin/env bash
set -euo pipefail

PROJECT_NAME="${PROJECT_NAME:-aws-grafana-kubernetes-ec2-iac}"
ENVIRONMENT="${ENVIRONMENT:-dev}"
AWS_REGION="${AWS_REGION:-us-east-1}"

if ! command -v aws >/dev/null 2>&1; then
  echo "AWS CLI is required to inspect existing EC2 resources."
  exit 1
fi

EXISTING_INSTANCE_IDS=$(aws ec2 describe-instances \
  --region "$AWS_REGION" \
  --filters "Name=tag:Project,Values=$PROJECT_NAME" "Name=tag:Environment,Values=$ENVIRONMENT" \
  --query 'Reservations[].Instances[?State.Name != `terminated`].[InstanceId]' \
  --output text)

if [ -n "$EXISTING_INSTANCE_IDS" ]; then
  echo "Existing EC2 instance(s) detected for project $PROJECT_NAME in $ENVIRONMENT."
  echo "$EXISTING_INSTANCE_IDS"
  echo "Do not destroy these resources blindly."
  echo "Review your AWS Console or the Terraform state before replacing any instance."
  echo "If you intend to replace it, confirm the intended instance and rerun only after explicit approval."
  exit 1
fi

echo "No existing EC2 instance was found for project $PROJECT_NAME in environment $ENVIRONMENT."
