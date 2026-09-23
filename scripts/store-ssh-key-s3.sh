#!/usr/bin/env bash
set -euo pipefail

AWS_REGION="${AWS_REGION:-us-east-1}"
KEY_NAME="${KEY_NAME:?Set KEY_NAME before running this script}"
BUCKET_NAME="${BUCKET_NAME:?Set BUCKET_NAME before running this script}"
KEY_PATH="${KEY_PATH:-/tmp/${KEY_NAME}.pem}"

mkdir -p "$(dirname "$KEY_PATH")"

aws ec2 create-key-pair \
  --region "$AWS_REGION" \
  --key-name "$KEY_NAME" \
  --query 'KeyMaterial' \
  --output text > "$KEY_PATH"

chmod 400 "$KEY_PATH"
aws s3 cp "$KEY_PATH" "s3://$BUCKET_NAME/${KEY_NAME}.pem" --region "$AWS_REGION" --sse AES256 --only-show-errors
rm -f "$KEY_PATH"

echo "Private key stored securely in s3://$BUCKET_NAME/${KEY_NAME}.pem"
