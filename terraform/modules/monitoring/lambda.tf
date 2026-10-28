# IAM role that allows AWS Lambda service to execute this function
resource "aws_iam_role" "discord_notifier" {
  name = "${var.project_name}-${var.environment}-discord-notifier-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

# Basic permission to write logs to CloudWatch (for debugging Lambda failures)
resource "aws_iam_role_policy_attachment" "discord_notifier_logs" {
  role       = aws_iam_role.discord_notifier.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Packages the Python script into the zip format Lambda requires
data "archive_file" "discord_notifier" {
  type        = "zip"
  source_file = "${path.module}/../../../lambda/discord_notifier.py"
  output_path = "${path.module}/../../../lambda/discord_notifier.zip"
}

# Reads the Discord webhook URL from SSM at deploy time (not stored in code)
data "aws_ssm_parameter" "discord_webhook" {
  name            = "/distributed-llm-aws-v2/dev/discord_webhook_url"
  with_decryption = true
}

# The Lambda function itself — translates SNS alarm messages into Discord webhook format
resource "aws_lambda_function" "discord_notifier" {
  function_name    = "${var.project_name}-${var.environment}-discord-notifier"
  role             = aws_iam_role.discord_notifier.arn
  handler          = "discord_notifier.lambda_handler"
  runtime          = "python3.12"
  filename         = data.archive_file.discord_notifier.output_path
  source_code_hash = data.archive_file.discord_notifier.output_base64sha256
  timeout          = 10

  environment {
    variables = {
      DISCORD_WEBHOOK_URL = data.aws_ssm_parameter.discord_webhook.value
    }
  }
}

# Allows SNS to invoke this Lambda function when a message is published
resource "aws_lambda_permission" "allow_sns" {
  statement_id  = "AllowSNSInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.discord_notifier.function_name
  principal     = "sns.amazonaws.com"
  source_arn    = aws_sns_topic.alerts.arn
}

# Subscribes the Lambda function to the existing SNS alerts topic
resource "aws_sns_topic_subscription" "discord" {
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "lambda"
  endpoint  = aws_lambda_function.discord_notifier.arn
}
