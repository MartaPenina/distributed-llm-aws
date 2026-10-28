<#
  deploy.ps1 - повне розгортання distributed-llm-aws-v2 на НОВОМУ AWS-акаунті.

  Запуск (з кореня репо, PowerShell):
    .\deploy.ps1                         # адмін-ключі в профілі "default"
    .\deploy.ps1 -AdminProfile myadmin   # інший адмін-профіль
    .\deploy.ps1 -SkipPacker             # AMI вже зібрані і вписані в tfvars
    .\deploy.ps1 -Confirm                # питати підтвердження на кожен apply

  Кроки:
    1. Перевірка інструментів і адмін-креденшелів
    2. S3-бакет для стейту (versioning + block public access + encryption)
    3. IAM user terraform-sa + policy + ключі -> профіль "distributed-llm-aws-v2"
    4. Packer: ollama + bastion AMI (свіжа Ubuntu 24.04), ID пишуться в terraform.tfvars
    5. terraform main (без моніторингу)
    6. terraform rds
    7. terraform main повністю
    8. Вивід NS-серверів Route53 для реєстратора домену
#>
param(
  [string]$AdminProfile = "default",
  [switch]$SkipPacker,
  [switch]$Confirm
)

$ErrorActionPreference = "Stop"

$Region     = "eu-central-1"
$Bucket     = "distributed-llm-aws-v2-tf-state-v2-new"
$TfProfile  = "distributed-llm-aws-v2"
$IamUser    = "terraform-sa"
$PolicyName = "TerraformDistributedLLMPolicy"
$Domain     = "fault-lens-penina.pp.ua"

$Root    = $PSScriptRoot
$TfDir   = Join-Path $Root "terraform"
$RdsDir  = Join-Path $TfDir "rds"
$PkDir   = Join-Path $Root "packer"
$TfVars  = Join-Path $TfDir "terraform.tfvars"

function Step($msg) { Write-Host "`n=== $msg ===" -ForegroundColor Cyan }
function Ok($msg)   { Write-Host "  [OK] $msg" -ForegroundColor Green }

# Запуск зовнішньої команди з перевіркою коду виходу (PS 5.1 сам не зупиняється)
function Run {
  param([string]$Exe, [string[]]$CmdArgs)
  & $Exe @CmdArgs
  if ($LASTEXITCODE -ne 0) { throw "Помилка: $Exe $($CmdArgs -join ' ') (exit $LASTEXITCODE)" }
}
# Тиха команда: повертає вивід або $null при помилці
function Try-Out {
  param([string]$Exe, [string[]]$CmdArgs)
  $old = $ErrorActionPreference; $ErrorActionPreference = "Continue"
  $out = & $Exe @CmdArgs 2>$null
  $code = $LASTEXITCODE
  $ErrorActionPreference = $old
  if ($code -ne 0) { return $null }
  return $out
}

# ---------------------------------------------------------------- 1
Step "1. Перевірка інструментів"
foreach ($t in @("aws", "terraform") + $(if (-not $SkipPacker) { @("packer") } else { @() })) {
  if (-not (Get-Command $t -ErrorAction SilentlyContinue)) { throw "Не знайдено '$t' у PATH" }
  Ok $t
}

$PubKey = Join-Path $HOME ".ssh\id_ed25519.pub"
if (-not (Test-Path $PubKey)) { throw "Немає $PubKey. Створи: ssh-keygen -t ed25519 (Enter на всі питання) і перезапусти" }
Ok "SSH key: $PubKey"

$AccountId = Try-Out aws @("sts", "get-caller-identity", "--profile", $AdminProfile, "--query", "Account", "--output", "text")
if (-not $AccountId) { throw "Адмін-профіль '$AdminProfile' не працює. Зроби: aws configure --profile $AdminProfile (ключі НОВОГО акаунта)" }
$AccountId = "$AccountId".Trim()
Ok "Новий акаунт: $AccountId (профіль $AdminProfile)"

$A = @("--profile", $AdminProfile, "--region", $Region)

# ---------------------------------------------------------------- 2
Step "2. S3-бакет $Bucket"
if (Try-Out aws (@("s3api", "head-bucket", "--bucket", $Bucket) + $A)) {
  Ok "вже існує"
} else {
  $r = Try-Out aws (@("s3api", "create-bucket", "--bucket", $Bucket, "--create-bucket-configuration", "LocationConstraint=$Region") + $A)
  if (-not $r) { throw "Не вдалось створити бакет $Bucket (можливо ім'я зайняте глобально) - зміни `$Bucket у скрипті і в .tf файлах" }
  Ok "створено"
}
Run aws (@("s3api", "put-bucket-versioning", "--bucket", $Bucket, "--versioning-configuration", "Status=Enabled") + $A)
Run aws (@("s3api", "put-public-access-block", "--bucket", $Bucket, "--public-access-block-configuration",
  "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true") + $A)
Ok "versioning + public access block"

# ---------------------------------------------------------------- 3
Step "3. IAM $IamUser + профіль $TfProfile"
$cur = Try-Out aws @("sts", "get-caller-identity", "--profile", $TfProfile, "--query", "Account", "--output", "text")
if ($cur -and "$cur".Trim() -eq $AccountId) {
  Ok "профіль $TfProfile вже дивиться в акаунт $AccountId"
} else {
  if (-not (Try-Out aws (@("iam", "get-user", "--user-name", $IamUser) + $A))) {
    Run aws (@("iam", "create-user", "--user-name", $IamUser) + $A) | Out-Null
    Ok "user створено"
  }

  $policy = @'
{
  "Version": "2012-10-17",
  "Statement": [
    {"Sid": "EC2AndVPC", "Effect": "Allow", "Action": ["ec2:*"], "Resource": "*"},
    {"Sid": "AutoScaling", "Effect": "Allow", "Action": ["autoscaling:*"], "Resource": "*"},
    {"Sid": "LoadBalancing", "Effect": "Allow", "Action": ["elasticloadbalancing:*"], "Resource": "*"},
    {"Sid": "RDS", "Effect": "Allow", "Action": ["rds:*"], "Resource": "*"},
    {"Sid": "S3", "Effect": "Allow", "Action": ["s3:*"], "Resource": "*"},
    {"Sid": "CloudWatch", "Effect": "Allow", "Action": ["cloudwatch:PutMetricAlarm","cloudwatch:DeleteAlarms","cloudwatch:DescribeAlarms","cloudwatch:ListTagsForResource","cloudwatch:TagResource","cloudwatch:UntagResource"], "Resource": "*"},
    {"Sid": "Lambda", "Effect": "Allow", "Action": ["lambda:CreateFunction","lambda:DeleteFunction","lambda:GetFunction","lambda:GetFunctionConfiguration","lambda:GetFunctionCodeSigningConfig","lambda:UpdateFunctionCode","lambda:UpdateFunctionConfiguration","lambda:AddPermission","lambda:RemovePermission","lambda:GetPolicy","lambda:TagResource","lambda:UntagResource","lambda:ListTags","lambda:ListVersionsByFunction","lambda:PublishVersion","lambda:InvokeFunction","lambda:GetFunctionEventInvokeConfig","lambda:PutFunctionEventInvokeConfig"], "Resource": "*"},
    {"Sid": "CloudWatchLogs", "Effect": "Allow", "Action": ["logs:CreateLogGroup","logs:DeleteLogGroup","logs:DescribeLogGroups","logs:PutRetentionPolicy","logs:TagLogGroup","logs:ListTagsForResource","logs:TagResource","logs:UntagResource"], "Resource": "*"},
    {"Sid": "SNS", "Effect": "Allow", "Action": ["sns:CreateTopic","sns:DeleteTopic","sns:Subscribe","sns:Unsubscribe","sns:GetTopicAttributes","sns:SetTopicAttributes","sns:ListTopics","sns:ListSubscriptionsByTopic","sns:GetSubscriptionAttributes","sns:SetSubscriptionAttributes","sns:TagResource","sns:ListTagsForResource"], "Resource": "*"},
    {"Sid": "IAMForUserSelf", "Effect": "Allow", "Action": ["iam:ListAttachedUserPolicies"], "Resource": "arn:aws:iam::*:user/terraform-sa"},
    {"Sid": "SSM", "Effect": "Allow", "Action": ["ssm:PutParameter","ssm:GetParameter","ssm:GetParameters","ssm:DeleteParameter","ssm:DescribeParameters","ssm:AddTagsToResource","ssm:ListTagsForResource"], "Resource": "*"},
    {"Sid": "IAMForInstances", "Effect": "Allow", "Action": ["iam:CreateRole","iam:DeleteRole","iam:GetRole","iam:PassRole","iam:AttachRolePolicy","iam:DetachRolePolicy","iam:ListAttachedRolePolicies","iam:CreateInstanceProfile","iam:DeleteInstanceProfile","iam:GetInstanceProfile","iam:AddRoleToInstanceProfile","iam:RemoveRoleFromInstanceProfile","iam:ListInstanceProfilesForRole","iam:TagRole","iam:ListRoleTags","iam:CreateServiceLinkedRole","iam:ListRolePolicies","iam:PutRolePolicy","iam:GetRolePolicy","iam:DeleteRolePolicy","iam:TagInstanceProfile"], "Resource": "*"},
    {"Sid": "Route53", "Effect": "Allow", "Action": ["route53:*"], "Resource": "*"}
  ]
}
'@
  $pf = Join-Path $env:TEMP "tf_llm_policy.json"
  [IO.File]::WriteAllText($pf, $policy, (New-Object Text.UTF8Encoding $false))
  $pUri = "file://" + ($pf -replace '\\', '/')
  $pArn = "arn:aws:iam::${AccountId}:policy/$PolicyName"

  if (Try-Out aws (@("iam", "get-policy", "--policy-arn", $pArn) + $A)) {
    $old = Try-Out aws (@("iam", "list-policy-versions", "--policy-arn", $pArn, "--query", "Versions[?!IsDefaultVersion].VersionId", "--output", "text") + $A)
    foreach ($v in ("$old" -split '\s+' | Where-Object { $_ })) {
      Run aws (@("iam", "delete-policy-version", "--policy-arn", $pArn, "--version-id", $v) + $A)
    }
    Run aws (@("iam", "create-policy-version", "--policy-arn", $pArn, "--policy-document", $pUri, "--set-as-default") + $A) | Out-Null
  } else {
    Run aws (@("iam", "create-policy", "--policy-name", $PolicyName, "--policy-document", $pUri) + $A) | Out-Null
  }
  Run aws (@("iam", "attach-user-policy", "--user-name", $IamUser, "--policy-arn", $pArn) + $A)
  Ok "policy $PolicyName attached"

  # максимум 2 ключі на юзера - видаляємо старі, якщо вже 2
  $keys = Try-Out aws (@("iam", "list-access-keys", "--user-name", $IamUser, "--query", "AccessKeyMetadata[].AccessKeyId", "--output", "text") + $A)
  $keyList = @("$keys" -split '\s+' | Where-Object { $_ })
  if ($keyList.Count -ge 2) {
    Run aws (@("iam", "delete-access-key", "--user-name", $IamUser, "--access-key-id", $keyList[0]) + $A)
  }
  $k = (& aws iam create-access-key --user-name $IamUser --profile $AdminProfile --output json) | Out-String | ConvertFrom-Json
  if ($LASTEXITCODE -ne 0) { throw "Не вдалось створити access key" }

  # aws configure set ПЕРЕЗАПИСУЄ старий профіль (той, що від старого акаунта)
  Run aws @("configure", "set", "aws_access_key_id",     $k.AccessKey.AccessKeyId,     "--profile", $TfProfile)
  Run aws @("configure", "set", "aws_secret_access_key", $k.AccessKey.SecretAccessKey, "--profile", $TfProfile)
  Run aws @("configure", "set", "region", $Region, "--profile", $TfProfile)
  Run aws @("configure", "set", "output", "json",  "--profile", $TfProfile)
  # прибираємо можливий старий aws_session_token з секції профілю
  $cf = Join-Path $HOME ".aws\credentials"
  if (Test-Path $cf) {
    $in = $false
    $new = foreach ($l in (Get-Content $cf)) {
      if ($l -match '^\s*\[(.+)\]\s*$') { $in = ($Matches[1] -eq $TfProfile) }
      if ($in -and $l -match '^\s*aws_session_token\s*=') { continue }
      $l
    }
    [IO.File]::WriteAllLines($cf, [string[]]$new, (New-Object Text.UTF8Encoding $false))
  }

  Write-Host "  чекаю 15с поки IAM-ключ розповсюдиться..."
  Start-Sleep 15
  $cur = Try-Out aws @("sts", "get-caller-identity", "--profile", $TfProfile, "--query", "Account", "--output", "text")
  if ("$cur".Trim() -ne $AccountId) { throw "Профіль $TfProfile не працює після створення ключа, перезапусти скрипт через хвилину" }
  Ok "профіль $TfProfile -> $AccountId"
}

# ---------------------------------------------------------------- 4
function Build-Ami([string]$template) {
  Write-Host "  packer build $template (10-20 хв)..."
  $lines = New-Object System.Collections.Generic.List[string]
  & packer build -machine-readable -var "base_ami=$BaseAmi" -var "aws_profile=$TfProfile" -var "aws_region=$Region" $template |
    ForEach-Object {
      $lines.Add($_)
      $p = $_ -split ','
      if ($p.Count -ge 5 -and $p[2] -eq 'ui') { Write-Host ("    " + ($p[4] -replace '%!\(PACKER_COMMA\)', ',')) }
    }
  if ($LASTEXITCODE -ne 0) { throw "packer build $template впав" }
  $art = $lines | Where-Object { $_ -match ',artifact,0,id,' } | Select-Object -Last 1
  if (-not $art) { throw "Не знайшов AMI ID у виводі packer ($template)" }
  return (($art -split ',')[-1] -split ':')[-1].Trim()
}

if ($SkipPacker) {
  Step "4. Packer пропущено (-SkipPacker)"
} else {
  Step "4. Packer AMI"
  $BaseAmi = Try-Out aws (@("ssm", "get-parameter", "--name",
    "/aws/service/canonical/ubuntu/server/24.04/stable/current/amd64/hvm/ebs-gp3/ami-id",
    "--query", "Parameter.Value", "--output", "text") + $A)
  if (-not $BaseAmi) { $BaseAmi = "ami-08ea642491f096f83" }
  $BaseAmi = "$BaseAmi".Trim()
  Ok "base Ubuntu 24.04 AMI: $BaseAmi"

  Push-Location $PkDir
  try {
    Run packer @("init", "ollama-ami.pkr.hcl")
    Run packer @("init", "bastion-ami.pkr.hcl")
    $OllamaAmi  = Build-Ami "ollama-ami.pkr.hcl"
    Ok "ollama AMI: $OllamaAmi"
    $BastionAmi = Build-Ami "bastion-ami.pkr.hcl"
    Ok "bastion AMI: $BastionAmi"
  } finally { Pop-Location }

  $tv = [IO.File]::ReadAllText($TfVars)
  $tv = $tv -replace '(?m)^# TODO: AMI.*\r?\n', ''
  $tv = $tv -replace '(?m)^(ami_id\s*=\s*)"[^"]*"',         "`${1}`"$OllamaAmi`""
  $tv = $tv -replace '(?m)^(bastion_ami_id\s*=\s*)"[^"]*"', "`${1}`"$BastionAmi`""
  [IO.File]::WriteAllText($TfVars, $tv, (New-Object Text.UTF8Encoding $false))
  Ok "terraform.tfvars оновлено"
}

# ---------------------------------------------------------------- 5-7
$Approve = if ($Confirm) { @() } else { @("-auto-approve") }

function Tf-Init([string]$dir) {
  Push-Location $dir
  try {
    if (Test-Path ".terraform") { Remove-Item -Recurse -Force ".terraform" }
    Run terraform @("init", "-reconfigure", "-input=false")
  } finally { Pop-Location }
}

Step "5. Terraform main (без моніторингу)"
Tf-Init $TfDir
Push-Location $TfDir
try {
  Run terraform (@("apply", "-input=false",
    "-target=module.networking", "-target=module.security",
    "-target=module.compute",    "-target=module.route53") + $Approve)
} finally { Pop-Location }

Step "6. Terraform RDS"
Tf-Init $RdsDir
Push-Location $RdsDir
try { Run terraform (@("apply", "-input=false") + $Approve) } finally { Pop-Location }

Step "7. Terraform main повністю"
Push-Location $TfDir
try {
  Run terraform (@("apply", "-input=false") + $Approve)
  terraform output
} finally { Pop-Location }

# ---------------------------------------------------------------- 8
Step "8. Route53 NS -> пропиши у реєстратора домену $Domain"
$zid = Try-Out aws @("route53", "list-hosted-zones-by-name", "--dns-name", $Domain, "--max-items", "1",
  "--query", "HostedZones[0].Id", "--output", "text", "--profile", $TfProfile)
if ($zid) {
  $zid = "$zid".Trim()
  aws route53 get-hosted-zone --id $zid --query "DelegationSet.NameServers" --output table --profile $TfProfile
}

Write-Host "`nГОТОВО." -ForegroundColor Green
Write-Host "  - Онови NS у реєстратора (вище), інакше HTTPS/chat/grafana не запрацюють"
Write-Host "  - Підтверди підписку SNS у листі від AWS на alert_email"
