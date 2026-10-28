#!/bin/bash
set -e

# === Configuration ===
REGION="eu-central-1"
BUCKET_NAME="distributed-llm-aws-tf-state-v2-new"
DYNAMODB_TABLE="distributed-llm-aws-state-lock"
IAM_USER="terraform-sa"
POLICY_NAME="TerraformDistributedLLMPolicy"

# === Step 1: Verify AWS credentials ===
echo "Verifying AWS credentials..."
aws sts get-caller-identity
echo "Credentials valid."

# === Step 2: Create S3 bucket for Terraform state ===
echo "Creating state bucket: $BUCKET_NAME..."
if aws s3api head-bucket --bucket "$BUCKET_NAME" 2>/dev/null; then
  echo "Bucket already exists, skipping."
else
  aws s3api create-bucket \
    --bucket "$BUCKET_NAME" \
    --region "$REGION" \
    --create-bucket-configuration LocationConstraint="$REGION"
  echo "Bucket created."
fi

# === Step 3: Enable versioning ===
echo "Enabling versioning..."
aws s3api put-bucket-versioning \
  --bucket "$BUCKET_NAME" \
  --versioning-configuration Status=Enabled
echo "Versioning enabled."

# === Step 4: Block public access ===
echo "Blocking public access..."
aws s3api put-public-access-block \
  --bucket "$BUCKET_NAME" \
  --public-access-block-configuration \
    BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true
echo "Public access blocked."

# === Step 5: Create DynamoDB table for state locking ===
echo "Creating DynamoDB table for state locking..."
if aws dynamodb describe-table \
    --table-name "$DYNAMODB_TABLE" \
    --region "$REGION" > /dev/null 2>&1; then
  echo "DynamoDB table already exists, skipping."
else
  aws dynamodb create-table \
    --table-name "$DYNAMODB_TABLE" \
    --attribute-definitions AttributeName=LockID,AttributeType=S \
    --key-schema AttributeName=LockID,KeyType=HASH \
    --billing-mode PAY_PER_REQUEST \
    --region "$REGION"
  echo "DynamoDB table created."
fi

# === Step 6: Create IAM user ===
echo "Setting up $IAM_USER IAM user..."
if aws iam get-user --user-name "$IAM_USER" > /dev/null 2>&1; then
  echo "User $IAM_USER already exists, skipping."
else
  aws iam create-user --user-name "$IAM_USER"
  echo "User created."
fi

# === Step 7: Create least-privilege policy ===
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
POLICY_FILE="/tmp/terraform_llm_policy.json"

cat > "$POLICY_FILE" <<'POLICY'
{
  "Version": "2012-10-17",
  "Statement": [
    {"Sid": "EC2AndVPC", "Effect": "Allow", "Action": ["ec2:*"], "Resource": "*"},
    {"Sid": "AutoScaling", "Effect": "Allow", "Action": ["autoscaling:*"], "Resource": "*"},
    {"Sid": "LoadBalancing", "Effect": "Allow", "Action": ["elasticloadbalancing:*"], "Resource": "*"},
    {"Sid": "RDS", "Effect": "Allow", "Action": ["rds:*"], "Resource": "*"},
    {"Sid": "S3", "Effect": "Allow", "Action": ["s3:*"], "Resource": "*"},
    {"Sid": "DynamoDB", "Effect": "Allow", "Action": ["dynamodb:GetItem","dynamodb:PutItem","dynamodb:DeleteItem","dynamodb:DescribeTable","dynamodb:CreateTable","dynamodb:DeleteTable"], "Resource": "*"},
    {"Sid": "CloudWatch", "Effect": "Allow", "Action": ["cloudwatch:PutMetricAlarm","cloudwatch:DeleteAlarms","cloudwatch:DescribeAlarms","cloudwatch:ListTagsForResource","cloudwatch:TagResource","cloudwatch:UntagResource"], "Resource": "*"},
    {"Sid": "Lambda", "Effect": "Allow", "Action": ["lambda:CreateFunction","lambda:DeleteFunction","lambda:GetFunction","lambda:GetFunctionConfiguration","lambda:GetFunctionCodeSigningConfig","lambda:UpdateFunctionCode","lambda:UpdateFunctionConfiguration","lambda:AddPermission","lambda:RemovePermission","lambda:GetPolicy","lambda:TagResource","lambda:UntagResource","lambda:ListTags","lambda:ListVersionsByFunction","lambda:PublishVersion","lambda:InvokeFunction","lambda:GetFunctionEventInvokeConfig","lambda:PutFunctionEventInvokeConfig"], "Resource": "*"},
    {"Sid": "CloudWatchLogs", "Effect": "Allow", "Action": ["logs:CreateLogGroup","logs:DeleteLogGroup","logs:DescribeLogGroups","logs:PutRetentionPolicy","logs:TagLogGroup","logs:ListTagsForResource"], "Resource": "*"},
    {"Sid": "SNS", "Effect": "Allow", "Action": ["sns:CreateTopic","sns:DeleteTopic","sns:Subscribe","sns:Unsubscribe","sns:GetTopicAttributes","sns:SetTopicAttributes","sns:ListTopics","sns:ListSubscriptionsByTopic","sns:GetSubscriptionAttributes","sns:SetSubscriptionAttributes","sns:TagResource","sns:ListTagsForResource"], "Resource": "*"},
    {"Sid": "IAMForUserSelf", "Effect": "Allow", "Action": ["iam:ListAttachedUserPolicies"], "Resource": "arn:aws:iam::*:user/terraform-sa"},
    {"Sid": "SSM", "Effect": "Allow", "Action": ["ssm:PutParameter","ssm:GetParameter","ssm:GetParameters","ssm:DeleteParameter","ssm:DescribeParameters","ssm:AddTagsToResource","ssm:ListTagsForResource"], "Resource": "*"},
    {"Sid": "IAMForInstances", "Effect": "Allow", "Action": ["iam:CreateRole","iam:DeleteRole","iam:GetRole","iam:PassRole","iam:AttachRolePolicy","iam:DetachRolePolicy","iam:ListAttachedRolePolicies","iam:CreateInstanceProfile","iam:DeleteInstanceProfile","iam:GetInstanceProfile","iam:AddRoleToInstanceProfile","iam:RemoveRoleFromInstanceProfile","iam:ListInstanceProfilesForRole","iam:TagRole","iam:ListRoleTags","iam:CreateServiceLinkedRole","iam:ListRolePolicies","iam:PutRolePolicy","iam:GetRolePolicy","iam:DeleteRolePolicy","iam:TagInstanceProfile"], "Resource": "*"},
    {"Sid": "Route53", "Effect": "Allow", "Action": ["route53:*"], "Resource": "*"}
  ]
}
POLICY

if aws iam get-policy \
    --policy-arn "arn:aws:iam::${ACCOUNT_ID}:policy/${POLICY_NAME}" > /dev/null 2>&1; then
  echo "Policy exists, updating..."
  VERSION_ID=$(aws iam list-policy-versions \
    --policy-arn "arn:aws:iam::${ACCOUNT_ID}:policy/${POLICY_NAME}" \
    --query 'Versions[?!IsDefaultVersion].VersionId' \
    --output text | awk '{print $1}')
  if [ -n "$VERSION_ID" ]; then
    aws iam delete-policy-version \
      --policy-arn "arn:aws:iam::${ACCOUNT_ID}:policy/${POLICY_NAME}" \
      --version-id "$VERSION_ID"
  fi
  aws iam create-policy-version \
    --policy-arn "arn:aws:iam::${ACCOUNT_ID}:policy/${POLICY_NAME}" \
    --policy-document "file://${POLICY_FILE}" \
    --set-as-default
else
  aws iam create-policy \
    --policy-name "$POLICY_NAME" \
    --policy-document "file://${POLICY_FILE}"
fi
echo "Policy ready."

# === Step 8: Attach policy ===
aws iam attach-user-policy \
  --user-name "$IAM_USER" \
  --policy-arn "arn:aws:iam::${ACCOUNT_ID}:policy/${POLICY_NAME}" \
  && echo "Policy attached." || echo "Already attached."

# === Step 9: Create access keys ===
EXISTING_KEYS=$(aws iam list-access-keys \
  --user-name "$IAM_USER" \
  --query 'AccessKeyMetadata[].AccessKeyId' \
  --output text)

if [ -n "$EXISTING_KEYS" ]; then
  echo "Access keys already exist — skipping."
  echo "To rotate: delete in AWS Console and re-run."
else
  KEYS=$(aws iam create-access-key --user-name "$IAM_USER")
  ACCESS_KEY=$(echo "$KEYS" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['AccessKey']['AccessKeyId'])")
  SECRET_KEY=$(echo "$KEYS" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['AccessKey']['SecretAccessKey'])")

  mkdir -p ~/.aws
  chmod 700 ~/.aws

  cat >> ~/.aws/credentials << EOF

[distributed-llm-aws]
aws_access_key_id=$ACCESS_KEY
aws_secret_access_key=$SECRET_KEY
EOF

  cat >> ~/.aws/config << EOF

[profile distributed-llm-aws]
region=$REGION
output=json
EOF

  chmod 600 ~/.aws/credentials
  chmod 600 ~/.aws/config
  echo "Credentials saved under profile [distributed-llm-aws]"
fi

echo ""
echo "=== Bootstrap complete ==="
echo "Region:        $REGION"
echo "State bucket:  s3://$BUCKET_NAME"
echo "Lock table:    $DYNAMODB_TABLE"
echo "IAM user:      $IAM_USER"
echo ""
echo "Next steps:"
echo "  1. Verify: aws sts get-caller-identity --profile distributed-llm-aws"
echo "  2. Create terraform/backend.tf"
echo "  3. Run: terraform init"
echo ""
echo "NEVER commit ~/.aws/ or terraform.tfvars to Git!"