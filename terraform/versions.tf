terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.28.0"
    }
    random = {
      source  = "hashicorp/random"
      version = ">= 3.6.0"
    }
    grafana = {
      source  = "grafana/grafana"
      version = ">= 4.12.0"
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = local.tags
  }
}

provider "grafana" {
  alias = "managed"
  url   = var.create_grafana_workspace ? "https://${aws_grafana_workspace.this[0].endpoint}" : "http://localhost"
  auth  = var.create_grafana_workspace ? aws_grafana_workspace_service_account_token.terraform[0].key : "unused"
}
