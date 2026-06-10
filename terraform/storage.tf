resource "aws_s3_bucket" "logs" {
  bucket        = local.log_bucket_name
  force_destroy = false
}

resource "aws_s3_bucket_server_side_encryption_configuration" "logs" {
  bucket = aws_s3_bucket.logs.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "logs" {
  bucket                  = aws_s3_bucket.logs.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_sqs_queue" "direct_dlq" {
  name                      = "${local.name}-direct-dlq"
  message_retention_seconds = 1209600
}

resource "aws_sqs_queue" "direct" {
  name                       = "${local.name}-direct-ingest"
  visibility_timeout_seconds = 300
  message_retention_seconds  = 1209600

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.direct_dlq.arn
    maxReceiveCount     = 5
  })
}

resource "aws_sqs_queue_policy" "direct" {
  queue_url = aws_sqs_queue.direct.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = { Service = "s3.amazonaws.com" }
        Action    = "sqs:SendMessage"
        Resource  = aws_sqs_queue.direct.arn
        Condition = {
          ArnEquals = { "aws:SourceArn" = aws_s3_bucket.logs.arn }
        }
      }
    ]
  })
}

resource "aws_s3_bucket_notification" "logs" {
  bucket = aws_s3_bucket.logs.id

  queue {
    queue_arn = aws_sqs_queue.direct.arn
    events    = ["s3:ObjectCreated:*"]
  }

  depends_on = [aws_sqs_queue_policy.direct]
}
