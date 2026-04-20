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


