# Simplified Terraform SIEM stack

This is a simplified Terraform path for a new deployment model. It intentionally
drops the CDK solution's complex variants: no managed OpenSearch domains, no
OpenSearch Serverless Classic mode, no GovCloud/China special casing, no VPC
endpoint matrix, and no Lambda log-loader workers.

## What it creates

- Amazon OpenSearch Serverless **NextGen** collection group and `SEARCH`
  collection.
- S3 log landing bucket and SQS notification queue.
- Amazon OpenSearch Ingestion pipeline for direct S3/SQS ingestion.
- Optional second OpenSearch Ingestion pipeline for an existing Amazon Security
  Lake subscriber SQS queue as an OCSF fallback path.
- Optional Amazon Managed Grafana workspace plus local dashboard import using
  the generated Grafana dashboards in `terraform/grafana_dashboards`.

## Assumptions

- Direct ingestion is intentionally generic and expects JSON/NDJSON-style logs.
  For broad AWS security telemetry, enable Security Lake and use the fallback
  pipeline so Security Lake performs OCSF normalization.
- Managed Grafana uses IAM Identity Center (`AWS_SSO`), which must be enabled in
  the target account/Region.
- The Grafana dashboard importer runs on the Terraform runner and requires
  `python3`, `boto3`, and `requests`.
- Provider support for AOSS NextGen requires a recent AWS provider (`>= 6.28`).

## Usage

```bash
cd terraform
terraform init
terraform apply \
  -var='aws_region=us-east-1' \
  -var='admin_principal_arns=["arn:aws:iam::123456789012:role/Admin"]'
```

Security Lake fallback example:

```bash
terraform apply \
  -var='enable_security_lake_fallback=true' \
  -var='security_lake_sqs_url=https://sqs.us-east-1.amazonaws.com/123456789012/AmazonSecurityLake-...' \
  -var='security_lake_sqs_arn=arn:aws:sqs:us-east-1:123456789012:AmazonSecurityLake-...' \
  -var='security_lake_bucket_arns=["arn:aws:s3:::aws-security-data-lake-us-east-1-..."]'
```

## Intentional simplifications

- OSIS replaces Lambda/EKS ingestion workers.
- Security Lake is the preferred fallback for services/logs that require deeper
  normalization than the generic direct pipeline.
- Grafana dashboards are generated from the OpenSearch Dashboards saved objects;
  unsupported visualization types are kept as text/note panels rather than
  failing the deployment.
