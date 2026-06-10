resource "aws_cloudwatch_log_group" "osis_direct" {
  name              = "/aws/vendedlogs/OpenSearchIngestion/${local.osis_direct_name}"
  retention_in_days = 30
}

resource "aws_osis_pipeline" "direct" {
  pipeline_name = local.osis_direct_name
  min_units     = var.osis_min_units
  max_units     = var.osis_max_units

  pipeline_configuration_body = templatefile("${path.module}/templates/osis-s3-aoss.yaml.tftpl", {
    pipeline_name       = local.osis_direct_name
    sqs_queue_url       = aws_sqs_queue.direct.id
    region              = var.aws_region
    osis_role_arn       = aws_iam_role.osis.arn
    collection_endpoint = aws_opensearchserverless_collection.this.collection_endpoint
    index_prefix        = "log-direct"
    codec               = var.osis_direct_codec
  })

  log_publishing_options {
    is_logging_enabled = true
    cloudwatch_log_destination {
      log_group = aws_cloudwatch_log_group.osis_direct.name
    }
  }

  depends_on = [
    aws_iam_role_policy.osis,
    aws_opensearchserverless_access_policy.data
  ]
}

resource "aws_cloudwatch_log_group" "osis_security_lake" {
  count             = local.security_lake_enabled ? 1 : 0
  name              = "/aws/vendedlogs/OpenSearchIngestion/${local.osis_sl_name}"
  retention_in_days = 30
}

resource "aws_osis_pipeline" "security_lake" {
  count         = local.security_lake_enabled ? 1 : 0
  pipeline_name = local.osis_sl_name
  min_units     = var.osis_min_units
  max_units     = var.osis_max_units

  pipeline_configuration_body = templatefile("${path.module}/templates/osis-s3-aoss.yaml.tftpl", {
    pipeline_name       = local.osis_sl_name
    sqs_queue_url       = var.security_lake_sqs_url
    region              = var.aws_region
    osis_role_arn       = aws_iam_role.osis.arn
    collection_endpoint = aws_opensearchserverless_collection.this.collection_endpoint
    index_prefix        = "log-ocsf-securitylake"
    codec               = var.security_lake_codec
  })

  log_publishing_options {
    is_logging_enabled = true
    cloudwatch_log_destination {
      log_group = aws_cloudwatch_log_group.osis_security_lake[0].name
    }
  }

  depends_on = [
    aws_iam_role_policy.osis,
    aws_opensearchserverless_access_policy.data
  ]
}
