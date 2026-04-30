# ============================================
# OUTPUTS
# ============================================

output "s3_bucket_name" {
  description = "Nombre del bucket S3"
  value       = aws_s3_bucket.seabook_bucket.id
}

output "s3_bucket_arn" {
  description = "ARN del bucket S3"
  value       = aws_s3_bucket.seabook_bucket.arn
}

output "sns_topic_arn" {
  description = "ARN del tópico SNS"
  value       = aws_sns_topic.seabook_sns.arn
}

output "sns_topic_name" {
  description = "Nombre del tópico SNS"
  value       = aws_sns_topic.seabook_sns.name
}

output "sqs_queue_url" {
  description = "URL de la cola SQS"
  value       = aws_sqs_queue.seabook_sqs.url
}

output "sqs_queue_arn" {
  description = "ARN de la cola SQS"
  value       = aws_sqs_queue.seabook_sqs.arn
}

output "sqs_dlq_arn" {
  description = "ARN de la Dead Letter Queue"
  value       = aws_sqs_queue.seabook_dlq.arn
}

# ============================================
# OUTPUTS
# ============================================

output "lambda_function_arn" {
  description = "ARN de la función Lambda"
  value       = aws_lambda_function.seabook_lambda.arn
}

output "lambda_function_name" {
  description = "Nombre de la función Lambda"
  value       = aws_lambda_function.seabook_lambda.function_name
}

output "lambda_role_arn" {
  description = "ARN del rol IAM de Lambda"
  value       = aws_iam_role.seabook_lambda_role.arn
}