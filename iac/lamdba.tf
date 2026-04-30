data "aws_iam_policy_document" "assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "seabook" {
  name               = "lambda_hello_execution_role"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
}

#logs cloudwatch temporales
resource "aws_cloudwatch_log_group" "seabook_logs" {
  name              = "/aws/lambda/hello_lambda_function"
  retention_in_days = 14
}

#permiso de logs
resource "aws_iam_role_policy_attachment" "lambda_logs" {
  role       = aws_iam_role.seabook.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Package the Lambda function code
data "archive_file" "seabook" {
  type        = "zip"
  source_file = "${path.module}/hello/index.js"
  output_path = "${path.module}/hello/hello.zip"
}

# Lambda function
resource "aws_lambda_function" "seabook" {
  filename      = data.archive_file.seabook.output_path
  function_name = "hello_lambda_function"
  role          = aws_iam_role.seabook.arn
  handler       = "index.handler"
  code_sha256   = data.archive_file.seabook.output_base64sha256

  runtime = "nodejs20.x"

  environment {
    variables = {
      DATABASE_ENDPOINT = var.DATABASE_ENDPOINT
    }
  }
}

#SQS permisos

resource "aws_iam_role_policy_attachment" "lambda_sqs" {
  role       = aws_iam_role.seabook.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaSQSQueueExecutionRole"
}
# ============================================
# IAM ROLE PARA LAMBDA
# ============================================

# Política de asunción de rol
data "aws_iam_policy_document" "lambda_assume_role" {
  statement {
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
    actions = ["sts:AssumeRole"]
  }
}

# Rol IAM para la función Lambda
resource "aws_iam_role" "seabook_lambda_role" {
  name               = "seabook-lambda-role-${terraform.workspace}"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json
  
  tags = {
    Environment = terraform.workspace
  }
}

# Política personalizada para Lambda (permisos específicos)
resource "aws_iam_role_policy" "seabook_lambda_policy" {
  name = "seabook-lambda-policy-${terraform.workspace}"
  role = aws_iam_role.seabook_lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      # CloudWatch Logs
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      },
      # S3
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.seabook_bucket.arn,
          "${aws_s3_bucket.seabook_bucket.arn}/*"
        ]
      },
      # SNS
      {
        Effect = "Allow"
        Action = [
          "sns:Publish",
          "sns:Subscribe"
        ]
        Resource = aws_sns_topic.seabook_sns.arn
      },
      # SQS
      {
        Effect = "Allow"
        Action = [
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes",
          "sqs:ChangeMessageVisibility",
          "sqs:SendMessage"
        ]
        Resource = [
          aws_sqs_queue.seabook_sqs.arn,
          aws_sqs_queue.seabook_dlq.arn
        ]
      }
    ]
  })
}

# Adjuntar políticas administradas por AWS
resource "aws_iam_role_policy_attachment" "lambda_basic_execution" {
  role       = aws_iam_role.seabook_lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy_attachment" "lambda_sqs" {
  role       = aws_iam_role.seabook_lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaSQSQueueExecutionRole"
}

# ============================================
# CLOUDWATCH LOGS
# ============================================

resource "aws_cloudwatch_log_group" "seabook_lambda_logs" {
  name              = "/aws/lambda/${aws_lambda_function.seabook_lambda.function_name}"
  retention_in_days = 14
  
  tags = {
    Environment = terraform.workspace
  }
}

# ============================================
# FUNCIÓN LAMBDA
# ============================================

# Empaquetar el código de la Lambda
data "archive_file" "seabook_lambda_code" {
  type        = "zip"
  source_dir  = "${path.module}/hello"
  output_path = "${path.module}/hello/hello.zip"
}

# Función Lambda
resource "aws_lambda_function" "seabook_lambda" {
  filename         = data.archive_file.seabook_lambda_code.output_path
  function_name    = "seabook-lambda-${terraform.workspace}"
  role             = aws_iam_role.seabook_lambda_role.arn
  handler          = "index.handler"
  runtime          = "nodejs20.x"
  timeout          = 60
  memory_size      = 256
  source_code_hash = data.archive_file.seabook_lambda_code.output_base64sha256

  environment {
    variables = {
      S3_BUCKET_NAME  = aws_s3_bucket.seabook_bucket.id
      SNS_TOPIC_ARN   = aws_sns_topic.seabook_sns.arn
      SQS_QUEUE_URL   = aws_sqs_queue.seabook_sqs.url
      ENVIRONMENT     = terraform.workspace
    }
  }

  tags = {
    Environment = terraform.workspace
    Service     = "Lambda"
  }
}

# ============================================
# VERSIÓN Y ALIAS (para despliegues seguros)
# ============================================

resource "aws_lambda_function_version" "seabook_lambda_version" {
  function_name = aws_lambda_function.seabook_lambda.function_name
  publish       = true
}

resource "aws_lambda_alias" "seabook_lambda_alias" {
  name             = "production"
  description      = "Producción alias"
  function_name    = aws_lambda_function.seabook_lambda.function_name
  function_version = aws_lambda_function_version.seabook_lambda_version.version
}