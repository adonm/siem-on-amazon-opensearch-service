resource "aws_opensearchserverless_collection_group" "this" {
  name             = local.collection_group_name
  generation       = "NEXTGEN"
  standby_replicas = "ENABLED"
  description      = "Simplified SIEM NextGen collection group"

  capacity_limits {
    min_indexing_capacity_in_ocu = 0
    min_search_capacity_in_ocu   = 0
    max_indexing_capacity_in_ocu = 8
    max_search_capacity_in_ocu   = 8
  }
}

resource "aws_opensearchserverless_security_policy" "network" {
  name        = "${local.name}-network"
  type        = "network"
  description = "Simplified SIEM public network policy"

  policy = jsonencode([
    {
      Rules = [
        {
          ResourceType = "collection"
          Resource     = ["collection/${var.collection_name}"]
        },
        {
          ResourceType = "dashboard"
          Resource     = ["collection/${var.collection_name}"]
        }
      ]
      AllowFromPublic = true
    }
  ])
}

resource "aws_opensearchserverless_collection" "this" {
  name                  = var.collection_name
  description           = "Simplified SIEM logs collection"
  type                  = "SEARCH"
  collection_group_name = aws_opensearchserverless_collection_group.this.name
  standby_replicas      = "ENABLED"

  encryption_config {
    aws_owned_key = true
  }

  depends_on = [aws_opensearchserverless_security_policy.network]
}

resource "aws_opensearchserverless_access_policy" "data" {
  name        = "${local.name}-data"
  type        = "data"
  description = "Simplified SIEM data access policy"

  policy = jsonencode(concat(
    [local.aoss_osis_access],
    local.aoss_grafana_access,
    local.aoss_admin_access
  ))
}
