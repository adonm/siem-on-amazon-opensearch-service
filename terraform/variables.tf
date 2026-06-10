variable "aws_region" {
  description = "AWS Region for the simplified SIEM stack."
  type        = string
  default     = "us-east-1"
}

variable "name" {
  description = "Short lowercase deployment name used in resource names."
  type        = string
  default     = "siem"

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{2,20}$", var.name))
    error_message = "name must start with a lowercase letter and contain 3-21 lowercase letters, numbers, or hyphens."
  }
}

variable "collection_name" {
  description = "OpenSearch Serverless NextGen collection name."
  type        = string
  default     = "siem-logs"
}

variable "log_bucket_name" {
  description = "Optional existing/global S3 log landing bucket name. Leave empty to create one."
  type        = string
  default     = ""
}

variable "admin_principal_arns" {
  description = "IAM principal ARNs that should have full AOSS data access for break-glass/admin use."
  type        = list(string)
  default     = []
}

variable "osis_min_units" {
  description = "Minimum OpenSearch Ingestion OCUs per pipeline."
  type        = number
  default     = 1
}

variable "osis_max_units" {
  description = "Maximum OpenSearch Ingestion OCUs per pipeline."
  type        = number
  default     = 4
}

variable "osis_direct_codec" {
  description = "Data Prepper S3 source codec for direct S3 ingestion. Use json or ndjson for simplified ingestion."
  type        = string
  default     = "json"
}

variable "enable_security_lake_fallback" {
  description = "Create a second OSIS pipeline that consumes an existing Security Lake subscriber SQS queue."
  type        = bool
  default     = false
}

variable "security_lake_sqs_url" {
  description = "Security Lake subscriber SQS queue URL. Required when enable_security_lake_fallback is true."
  type        = string
  default     = ""
}

variable "security_lake_sqs_arn" {
  description = "Security Lake subscriber SQS queue ARN. Required when enable_security_lake_fallback is true."
  type        = string
  default     = ""
}

variable "security_lake_bucket_arns" {
  description = "Security Lake source bucket ARNs readable by the fallback OSIS role."
  type        = list(string)
  default     = []
}

variable "security_lake_codec" {
  description = "Data Prepper S3 source codec for Security Lake objects. Security Lake normally uses parquet."
  type        = string
  default     = "parquet"
}

variable "create_grafana_workspace" {
  description = "Create Amazon Managed Grafana. Requires IAM Identity Center in this account/Region."
  type        = bool
  default     = true
}

variable "import_grafana_dashboards" {
  description = "Run the local Grafana API importer after workspace creation. Requires python3, boto3, and requests on the Terraform runner."
  type        = bool
  default     = true
}

variable "tags" {
  description = "Additional tags."
  type        = map(string)
  default     = {}
}
