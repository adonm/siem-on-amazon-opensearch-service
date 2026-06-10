resource "aws_grafana_workspace" "this" {
  count                    = var.create_grafana_workspace ? 1 : 0
  name                     = "${local.name}-grafana"
  account_access_type      = "CURRENT_ACCOUNT"
  authentication_providers = ["AWS_SSO"]
  permission_type          = "CUSTOMER_MANAGED"
  role_arn                 = aws_iam_role.grafana[0].arn
  data_sources             = ["AMAZON_OPENSEARCH_SERVICE", "CLOUDWATCH"]
}

resource "terraform_data" "grafana_import" {
  count = var.create_grafana_workspace && var.import_grafana_dashboards ? 1 : 0

  input = {
    workspace_id        = aws_grafana_workspace.this[0].id
    workspace_endpoint  = aws_grafana_workspace.this[0].endpoint
    collection_endpoint = aws_opensearchserverless_collection.this.collection_endpoint
    dashboards_hash     = filesha256("${path.module}/grafana_dashboards/conversion_report.json")
  }

  provisioner "local-exec" {
    command = "python3 ${path.module}/scripts/import_grafana_dashboards.py --workspace-id ${self.input.workspace_id} --workspace-endpoint ${self.input.workspace_endpoint} --opensearch-endpoint ${self.input.collection_endpoint} --region ${var.aws_region} --dashboards-dir ${path.module}/grafana_dashboards"
  }

  depends_on = [aws_opensearchserverless_access_policy.data]
}
