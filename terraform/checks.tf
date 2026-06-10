check "osis_capacity" {
  assert {
    condition     = var.osis_min_units <= var.osis_max_units
    error_message = "osis_min_units must be less than or equal to osis_max_units."
  }
}

check "security_lake_inputs" {
  assert {
    condition = !var.enable_security_lake_fallback || (
      var.security_lake_sqs_url != "" &&
      var.security_lake_sqs_arn != "" &&
      length(var.security_lake_bucket_arns) > 0
    )
    error_message = "When enable_security_lake_fallback is true, set security_lake_sqs_url, security_lake_sqs_arn, and security_lake_bucket_arns."
  }
}

check "grafana_dashboard_inputs" {
  assert {
    condition     = !var.manage_grafana_dashboards || var.create_grafana_workspace
    error_message = "manage_grafana_dashboards requires create_grafana_workspace=true."
  }
}
