resource "aws_s3_bucket" "seabook" {
  bucket = "iac-hello-world-${lower(terraform.workspace)}-my-tf-test-bucket"
}

resource "aws_lambda_permission" "allow_bucket" {
  statement_id  = "AllowExecutionFromS3Bucket"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.seabook.arn
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.seabook.arn
}

resource "aws_s3_bucket_notification" "bucket_notification" {
  bucket = aws_s3_bucket.seabook.id

  lambda_function {
    lambda_function_arn = aws_lambda_function.seabook.arn
    events              = ["s3:ObjectCreated:*"]
  }

  depends_on = [aws_lambda_permission.allow_bucket]
}




#sns
resource "aws_sns_topic" "seabook" {
  name = "seabook-updates-topic-${lower(terraform.workspace)}"
}

resource "aws_sns_topic_subscription" "lambda_sns_target" {
  topic_arn = aws_sns_topic.seabook.arn
  protocol  = "lambda"
  endpoint  = aws_lambda_function.seabook.arn
}

resource "aws_lambda_permission" "allow_sns_invoke" {
  statement_id  = "AllowExecutionFromSNS"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.seabook.function_name
  principal     = "sns.amazonaws.com"
  source_arn    = aws_sns_topic.seabook.arn
}

#sqs

resource "aws_sqs_queue" "seabook_queue" {
  name = "seabook-queue-${lower(terraform.workspace)}"
  visibility_timeout_seconds = 30
}

resource "aws_lambda_event_source_mapping" "sqs_trigger" {
  event_source_arn = aws_sqs_queue.seabook_queue.arn
  function_name    = aws_lambda_function.seabook.arn

  batch_size       = 1
  enabled          = true
  
  depends_on = [
    aws_iam_role_policy_attachment.lambda_sqs
  ]
}
# ============================================
# S3 BUCKET
# ============================================

# Crear bucket S3 con nombre único
resource "aws_s3_bucket" "seabook_bucket" {
  bucket = "seabook-bucket-${lower(terraform.workspace)}-${random_id.bucket_suffix.hex}"
  
  tags = {
    Name        = "seabook-bucket-${terraform.workspace}"
    Environment = terraform.workspace
    Service     = "S3"
  }
}

# Sufijo aleatorio para evitar conflictos
resource "random_id" "bucket_suffix" {
  byte_length = 4
}

# Versionamiento del bucket
resource "aws_s3_bucket_versioning" "seabook_versioning" {
  bucket = aws_s3_bucket.seabook_bucket.id
  versioning_configuration {
    status = "Enabled"
  }
}

# Cifrado del bucket
resource "aws_s3_bucket_server_side_encryption_configuration" "seabook_encryption" {
  bucket = aws_s3_bucket.seabook_bucket.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Bloquear acceso público
resource "aws_s3_bucket_public_access_block" "seabook_block_public" {
  bucket = aws_s3_bucket.seabook_bucket.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Notificación: S3 -> Lambda (trigger)
resource "aws_s3_bucket_notification" "seabook_s3_notification" {
  bucket = aws_s3_bucket.seabook_bucket.id

  lambda_function {
    lambda_function_arn = aws_lambda_function.seabook_lambda.arn
    events              = ["s3:ObjectCreated:*"]
    filter_prefix       = "uploads/"
    filter_suffix       = ".jpg"
  }

  lambda_function {
    lambda_function_arn = aws_lambda_function.seabook_lambda.arn
    events              = ["s3:ObjectCreated:*"]
    filter_prefix       = "documents/"
    filter_suffix       = ".pdf"
  }

  depends_on = [aws_lambda_permission.allow_s3_invoke]
}

# Permiso para que S3 invoque Lambda
resource "aws_lambda_permission" "allow_s3_invoke" {
  statement_id  = "AllowExecutionFromS3"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.seabook_lambda.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.seabook_bucket.arn
}

# ============================================
# SNS TOPIC
# ============================================

# Crear tópico SNS
resource "aws_sns_topic" "seabook_sns" {
  name = "seabook-sns-${lower(terraform.workspace)}"
  
  delivery_policy = jsonencode({
    http = {
      defaultHealthyRetryPolicy = {
        minDelayTarget = 20
        maxDelayTarget = 20
        numRetries      = 3
        backoffFunction = "linear"
      }
    }
  })
  
  tags = {
    Environment = terraform.workspace
    Service     = "SNS"
  }
}

# Suscribir SNS a Lambda (trigger)
resource "aws_sns_topic_subscription" "seabook_sns_lambda" {
  topic_arn = aws_sns_topic.seabook_sns.arn
  protocol  = "lambda"
  endpoint  = aws_lambda_function.seabook_lambda.arn
  
  # Filtro opcional: solo mensajes con prioridad alta o media
  filter_policy = jsonencode({
    priority = ["high", "medium"]
  })
}

# Suscripción opcional por email
resource "aws_sns_topic_subscription" "seabook_sns_email" {
  count     = var.enable_email_notifications ? 1 : 0
  topic_arn = aws_sns_topic.seabook_sns.arn
  protocol  = "email"
  endpoint  = var.notification_email
}

# Permiso para que SNS invoque Lambda
resource "aws_lambda_permission" "allow_sns_invoke" {
  statement_id  = "AllowExecutionFromSNS"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.seabook_lambda.function_name
  principal     = "sns.amazonaws.com"
  source_arn    = aws_sns_topic.seabook_sns.arn
}

# ============================================
# SQS QUEUE
# ============================================

# Cola principal SQS
resource "aws_sqs_queue" "seabook_sqs" {
  name                       = "seabook-sqs-${lower(terraform.workspace)}"
  visibility_timeout_seconds = 30
  message_retention_seconds  = 345600  # 4 días
  max_message_size           = 262144  # 256 KB
  receive_wait_time_seconds  = 20      # Long polling
  sqs_managed_sse_enabled    = true    # Cifrado
  
  # Dead Letter Queue
  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.seabook_dlq.arn
    maxReceiveCount     = 3
  })
  
  tags = {
    Environment = terraform.workspace
    Service     = "SQS"
  }
}

# Dead Letter Queue (mensajes fallidos)
resource "aws_sqs_queue" "seabook_dlq" {
  name                      = "seabook-dlq-${lower(terraform.workspace)}"
  message_retention_seconds = 1209600  # 14 días
  
  tags = {
    Environment = terraform.workspace
    Service     = "SQS-DLQ"
  }
}

# Política para permitir que SNS envíe a SQS
resource "aws_sqs_queue_policy" "seabook_sqs_policy" {
  queue_url = aws_sqs_queue.seabook_sqs.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = "*"
        Action    = "sqs:SendMessage"
        Resource  = aws_sqs_queue.seabook_sqs.arn
        Condition = {
          ArnEquals = {
            "aws:SourceArn" = aws_sns_topic.seabook_sns.arn
          }
        }
      }
    ]
  })
}

# Suscribir SQS a SNS (mensajes van de SNS -> SQS)
resource "aws_sns_topic_subscription" "seabook_sns_sqs" {
  topic_arn = aws_sns_topic.seabook_sns.arn
  protocol  = "sqs"
  endpoint  = aws_sqs_queue.seabook_sqs.arn
}

# Trigger: SQS -> Lambda (Lambda consume de la cola)
resource "aws_lambda_event_source_mapping" "seabook_sqs_trigger" {
  event_source_arn = aws_sqs_queue.seabook_sqs.arn
  function_name    = aws_lambda_function.seabook_lambda.function_name
  
  batch_size                         = 10
  maximum_batching_window_in_seconds = 60
  enabled                            = true
  function_response_types            = ["ReportBatchItemFailures"]
  
  depends_on = [
    aws_lambda_function.seabook_lambda,
    aws_iam_role_policy_attachment.lambda_sqs
  ]
}



