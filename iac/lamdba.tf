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