resource "aws_iam_role" "osis" {
  name = "${local.name}-osis-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = { Service = "osis-pipelines.amazonaws.com" }
        Action    = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy" "osis" {
  name = "${local.name}-osis-policy"
  role = aws_iam_role.osis.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = concat([
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Resource = [aws_s3_bucket.logs.arn, "${aws_s3_bucket.logs.arn}/*"]
      },
      {
        Effect = "Allow"
        Action = [
          "sqs:ChangeMessageVisibility",
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes",
          "sqs:ReceiveMessage"
        ]
        Resource = [aws_sqs_queue.direct.arn]
      },
      {
        Effect   = "Allow"
        Action   = ["aoss:APIAccessAll"]
        Resource = [aws_opensearchserverless_collection.this.arn]
      }
      ], local.security_lake_enabled ? [
      {
        Effect   = "Allow"
        Action   = ["s3:GetObject", "s3:ListBucket"]
        Resource = concat(var.security_lake_bucket_arns, [for arn in var.security_lake_bucket_arns : "${arn}/*"])
      },
      {
        Effect = "Allow"
        Action = [
          "sqs:ChangeMessageVisibility",
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes",
          "sqs:ReceiveMessage"
        ]
        Resource = [var.security_lake_sqs_arn]
      }
    ] : [])
  })
}

resource "aws_iam_role" "grafana" {
  count = var.create_grafana_workspace ? 1 : 0
  name  = "${local.name}-grafana-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = { Service = "grafana.amazonaws.com" }
        Action    = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy" "grafana" {
  count = var.create_grafana_workspace ? 1 : 0
  name  = "${local.name}-grafana-policy"
  role  = aws_iam_role.grafana[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "cloudwatch:DescribeAlarmHistory",
          "cloudwatch:DescribeAlarms",
          "cloudwatch:GetMetricData",
          "cloudwatch:ListMetrics",
          "logs:DescribeLogGroups",
          "logs:GetLogEvents",
          "logs:GetQueryResults",
          "logs:StartQuery",
          "logs:StopQuery"
        ]
        Resource = "*"
      },
      {
        Effect   = "Allow"
        Action   = ["aoss:APIAccessAll"]
        Resource = aws_opensearchserverless_collection.this.arn
      }
    ]
  })
}
