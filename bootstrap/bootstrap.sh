#!/bin/bash
set -e

# ── Configuration ──────────────────────────────────────────
IAM_USER="terraform-deployer"
AWS_REGION="us-east-1"
PROFILE="distributed-llm-aws"

# ── Check if user already exists ────────────────────────────
if aws iam get-user --user-name "$IAM_USER" 2>/dev/null; then
  echo "User '$IAM_USER' already exists — skipping creation"
else
  echo "Creating IAM user: $IAM_USER"
  aws iam create-user --user-name "$IAM_USER"
fi

# ── Attach permissions ──────────────────────────────────────
# Managed policies for services Terraform will create
aws iam attach-user-policy \
  --user-name "$IAM_USER" \
  --policy-arn arn:aws:iam::aws:policy/AmazonEC2FullAccess

aws iam attach-user-policy \
  --user-name "$IAM_USER" \
  --policy-arn arn:aws:iam::aws:policy/AmazonRDSFullAccess

aws iam attach-user-policy \
  --user-name "$IAM_USER" \
  --policy-arn arn:aws:iam::aws:policy/AmazonVPCFullAccess

aws iam attach-user-policy \
  --user-name "$IAM_USER" \
  --policy-arn arn:aws:iam::aws:policy/ElasticLoadBalancingFullAccess

aws iam attach-user-policy \
  --user-name "$IAM_USER" \
  --policy-arn arn:aws:iam::aws:policy/AmazonS3FullAccess

aws iam attach-user-policy \
  --user-name "$IAM_USER" \
  --policy-arn arn:aws:iam::aws:policy/CloudWatchFullAccess

aws iam attach-user-policy \
  --user-name "$IAM_USER" \
  --policy-arn arn:aws:iam::aws:policy/IAMFullAccess

# ── Create Access Key (only if profile doesn't exist) ───────
if grep -q "\[$PROFILE\]" ~/.aws/credentials 2>/dev/null; then
  echo "Profile '$PROFILE' already exists in ~/.aws/credentials — skipping key creation"
else
  echo "Creating access key..."
  CREDS=$(aws iam create-access-key --user-name "$IAM_USER" --output json)

  ACCESS_KEY=$(echo "$CREDS" | python3 -c "import sys,json; print(json.load(sys.stdin)['AccessKey']['AccessKeyId'])")
  SECRET_KEY=$(echo "$CREDS" | python3 -c "import sys,json; print(json.load(sys.stdin)['AccessKey']['SecretAccessKey'])")

  # ── Save to ~/.aws/credentials ────────────────────────────
  mkdir -p ~/.aws
  chmod 700 ~/.aws

  cat >> ~/.aws/credentials << EOF

[$PROFILE]
aws_access_key_id=$ACCESS_KEY
aws_secret_access_key=$SECRET_KEY
EOF

  cat >> ~/.aws/config << EOF

[profile $PROFILE]
region=$AWS_REGION
output=json
EOF

  chmod 600 ~/.aws/credentials
  chmod 600 ~/.aws/config

  echo "Credentials saved to ~/.aws/credentials under profile '$PROFILE'"
fi

# ── Verify ──────────────────────────────────────────────────
echo "Verifying IAM user exists..."
aws iam get-user --user-name "$IAM_USER"

echo ""
echo "✓ Setup complete!"
echo "✓ IAM user: $IAM_USER"
echo "✓ Profile: $PROFILE"
echo ""
echo "Next step — test connection:"
echo "aws sts get-caller-identity --profile $PROFILE"
echo ""
echo "⚠ Never commit ~/.aws/ to Git!"