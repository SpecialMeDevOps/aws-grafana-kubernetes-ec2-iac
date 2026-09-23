#!/usr/bin/env bash
set -euo pipefail

PROJECT_NAME="${PROJECT_NAME:-aws-grafana-kubernetes-ec2-iac}"
ENVIRONMENT="${ENVIRONMENT:-dev}"
AWS_REGION="${AWS_REGION:-us-east-1}"
STACK_NAME="${STACK_NAME:-${PROJECT_NAME}-${ENVIRONMENT}}"

if ! command -v aws >/dev/null 2>&1; then
  echo "AWS CLI is required to inspect existing EC2 resources."
  exit 1
fi

EXISTING_INSTANCE_IDS=$(aws ec2 describe-instances \
  --region "$AWS_REGION" \
  --filters "Name=tag:Project,Values=$PROJECT_NAME" "Name=tag:Environment,Values=$ENVIRONMENT" \
  --query 'Reservations[].Instances[?State.Name != `terminated`].[InstanceId]' \
  --output text)

MANAGED_INSTANCE_ID=""
if MANAGED_INSTANCE_ID=$(aws cloudformation describe-stack-resources \
  --region "$AWS_REGION" \
  --stack-name "$STACK_NAME" \
  --logical-resource-id EC2Instance \
  --query 'StackResources[0].PhysicalResourceId' \
  --output text 2>/dev/null); then
  if [ "$MANAGED_INSTANCE_ID" = "None" ]; then
    MANAGED_INSTANCE_ID=""
  fi
fi

if [ -z "$EXISTING_INSTANCE_IDS" ]; then
  echo "No existing EC2 instance was found for project $PROJECT_NAME in $ENVIRONMENT."
  exit 0
fi

UNMANAGED_INSTANCE_IDS=""
for instance_id in $EXISTING_INSTANCE_IDS; do
  if [ "$instance_id" = "$MANAGED_INSTANCE_ID" ]; then
    echo "Existing EC2 instance $instance_id is managed by CloudFormation stack $STACK_NAME."
  else
    UNMANAGED_INSTANCE_IDS="${UNMANAGED_INSTANCE_IDS}${instance_id}"$'\n'
  fi
done

if [ -n "$UNMANAGED_INSTANCE_IDS" ]; then
  echo "Unmanaged existing EC2 instance(s) detected for project $PROJECT_NAME in $ENVIRONMENT:"
  printf '%s' "$UNMANAGED_INSTANCE_IDS"
  echo "The CloudFormation-managed instance is allowed, but unrelated instances will not be destroyed automatically."
  echo "Review the AWS Console and Terraform state before replacing or deleting any resource."
  exit 1
fi

echo "All matching EC2 instances are managed by CloudFormation stack $STACK_NAME."
