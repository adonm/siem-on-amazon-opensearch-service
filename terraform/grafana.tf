resource "aws_grafana_workspace" "this" {
  count                    = var.create_grafana_workspace ? 1 : 0
  name                     = "${local.name}-grafana"
  account_access_type      = "CURRENT_ACCOUNT"
  authentication_providers = ["AWS_SSO"]
  permission_type          = "CUSTOMER_MANAGED"
  role_arn                 = aws_iam_role.grafana[0].arn
  data_sources             = ["AMAZON_OPENSEARCH_SERVICE", "CLOUDWATCH"]
}

resource "aws_grafana_workspace_service_account" "terraform" {
  count        = var.create_grafana_workspace && var.manage_grafana_dashboards ? 1 : 0
  workspace_id = aws_grafana_workspace.this[0].id
  name         = "siem-terraform"
  grafana_role = "ADMIN"
}

resource "aws_grafana_workspace_service_account_token" "terraform" {
  count              = var.create_grafana_workspace && var.manage_grafana_dashboards ? 1 : 0
  workspace_id       = aws_grafana_workspace.this[0].id
  service_account_id = aws_grafana_workspace_service_account.terraform[0].service_account_id
  name               = "siem-terraform"
  seconds_to_live    = 2592000
}

resource "grafana_data_source" "opensearch" {
  count    = var.create_grafana_workspace && var.manage_grafana_dashboards ? 1 : 0
  provider = grafana.managed

  uid         = "siem-opensearch"
  name        = "SIEM OpenSearch Serverless"
  type        = "grafana-opensearch-datasource"
  url         = aws_opensearchserverless_collection.this.collection_endpoint
  is_default  = true
  access_mode = "proxy"

  json_data_encoded = jsonencode({
    database        = "log-*"
    flavor          = "opensearch"
    sigV4Auth       = true
    sigV4AuthType   = "workspace-iam-role"
    sigV4Region     = var.aws_region
    timeField       = "@timestamp"
    version         = "2.19.0"
    logMessageField = "@message"
  })

  depends_on = [aws_opensearchserverless_access_policy.data]
}

resource "grafana_dashboard" "converted" {
  for_each = toset(var.create_grafana_workspace && var.manage_grafana_dashboards ? [
    for file in fileset("${path.module}/grafana_dashboards", "*.json") : file
    if file != "conversion_report.json"
  ] : [])
  provider = grafana.managed

  config_json = file("${path.module}/grafana_dashboards/${each.key}")
  overwrite   = true

  depends_on = [grafana_data_source.opensearch]
}
