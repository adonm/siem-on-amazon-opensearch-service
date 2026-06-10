output "log_bucket_name" {
  value = aws_s3_bucket.logs.bucket
}

output "direct_ingest_queue_url" {
  value = aws_sqs_queue.direct.id
}

output "opensearch_collection_endpoint" {
  value = aws_opensearchserverless_collection.this.collection_endpoint
}

output "opensearch_collection_arn" {
  value = aws_opensearchserverless_collection.this.arn
}

output "osis_direct_pipeline_arn" {
  value = aws_osis_pipeline.direct.pipeline_arn
}

output "osis_security_lake_pipeline_arn" {
  value = try(aws_osis_pipeline.security_lake[0].pipeline_arn, null)
}

output "grafana_workspace_endpoint" {
  value = try(aws_grafana_workspace.this[0].endpoint, null)
}
