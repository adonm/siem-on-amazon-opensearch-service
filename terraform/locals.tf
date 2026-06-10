data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}

resource "random_id" "suffix" {
  byte_length = 4
}

locals {
  name                  = var.name
  collection_group_name = substr("nextgen-${var.collection_name}", 0, 32)
  log_bucket_name       = var.log_bucket_name != "" ? var.log_bucket_name : "${local.name}-${data.aws_caller_identity.current.account_id}-${var.aws_region}-logs-${random_id.suffix.hex}"
  osis_direct_name      = substr("${local.name}-direct", 0, 28)
  osis_sl_name          = substr("${local.name}-securitylake", 0, 28)

  security_lake_enabled = var.enable_security_lake_fallback

  aoss_osis_access = {
    Description = "OSIS write access"
    Principal   = [aws_iam_role.osis.arn]
    Rules = [
      {
        ResourceType = "collection"
        Resource     = ["collection/${var.collection_name}"]
        Permission   = ["aoss:DescribeCollectionItems"]
      },
      {
        ResourceType = "index"
        Resource     = ["index/${var.collection_name}/*"]
        Permission = [
          "aoss:CreateIndex",
          "aoss:DescribeIndex",
          "aoss:ReadDocument",
          "aoss:UpdateIndex",
          "aoss:WriteDocument"
        ]
      }
    ]
  }

  aoss_grafana_access = var.create_grafana_workspace ? [{
    Description = "Grafana read access"
    Principal   = [aws_iam_role.grafana[0].arn]
    Rules = [
      {
        ResourceType = "collection"
        Resource     = ["collection/${var.collection_name}"]
        Permission   = ["aoss:DescribeCollectionItems"]
      },
      {
        ResourceType = "index"
        Resource     = ["index/${var.collection_name}/*"]
        Permission   = ["aoss:DescribeIndex", "aoss:ReadDocument"]
      }
    ]
  }] : []

  aoss_admin_access = length(var.admin_principal_arns) > 0 ? [{
    Description = "Admin access"
    Principal   = var.admin_principal_arns
    Rules = [
      {
        ResourceType = "collection"
        Resource     = ["collection/${var.collection_name}"]
        Permission   = ["aoss:*"]
      },
      {
        ResourceType = "index"
        Resource     = ["index/${var.collection_name}/*"]
        Permission   = ["aoss:*"]
      }
    ]
  }] : []

  tags = merge({
    Project   = "siem-on-opensearch-simplified"
    ManagedBy = "terraform"
  }, var.tags)
}
