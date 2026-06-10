locals {
  # Highest-value routing knowledge retained from the old es_loader aws.ini.
  # OSIS remains intentionally generic; use these prefixes/indexes when wiring
  # producers or deciding what should move to Security Lake normalization.
  recommended_log_sources = {
    cloudtrail      = { index = "log-aws-cloudtrail", key_hint = "CloudTrail/ or CloudTrail-Insight/" }
    guardduty       = { index = "log-aws-guardduty", key_hint = "/GuardDuty/" }
    securityhub     = { index = "log-aws-securityhub", key_hint = "SecurityHub or securityhub" }
    vpcflowlogs     = { index = "log-aws-vpcflowlogs", key_hint = "vpcflowlogs" }
    waf             = { index = "log-aws-waf", key_hint = "aws-waf-logs- or _waflogs_" }
    cloudfront      = { index = "log-aws-cloudfront", key_hint = "CloudFront standard or realtime prefixes" }
    elb             = { index = "log-aws-elb", key_hint = "elasticloadbalancing_*" }
    s3accesslog     = { index = "log-aws-s3accesslog", key_hint = "S3 access log object names" }
    networkfirewall = { index = "log-aws-networkfirewall", key_hint = "_network-firewall_" }
    route53resolver = { index = "log-aws-r53resolver", key_hint = "vpcdnsquerylogs" }
    rds_mysql       = { index = "log-aws-rds-mysql", key_hint = "mysql/mariadb audit, general, error, slowquery" }
    rds_postgresql  = { index = "log-aws-rds-postgresql", key_hint = "postgresql" }
    clientvpn       = { index = "log-aws-clientvpn", key_hint = "/ClientVPN/" }
    securitylake    = { index = "log-ocsf", key_hint = "Security Lake parquet/OCSF" }
  }
}
