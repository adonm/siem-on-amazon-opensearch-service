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
- Optional Amazon Managed Grafana workspace plus Terraform-managed datasource
  and dashboards from `terraform/grafana_dashboards`.

## Assumptions

- Direct ingestion is intentionally generic and expects JSON/NDJSON-style logs.
  For broad AWS security telemetry, enable Security Lake and use the fallback
  pipeline so Security Lake performs OCSF normalization.
- Managed Grafana uses IAM Identity Center (`AWS_SSO`), which must be enabled in
  the target account/Region.
- Dashboard import is handled by Terraform providers; no local Python tooling is
  required for the normal path.
- Provider support for AOSS NextGen requires a recent AWS provider (`>= 6.28`).

## Usage

```bash
cd terraform
terraform init
terraform apply -var-file=examples/basic.tfvars.example
```

Security Lake fallback example:

```bash
terraform apply \
  -var-file=examples/basic.tfvars.example \
  -var='enable_security_lake_fallback=true' \
  -var='security_lake_sqs_url=https://sqs.us-east-1.amazonaws.com/123456789012/AmazonSecurityLake-...' \
  -var='security_lake_sqs_arn=arn:aws:sqs:us-east-1:123456789012:AmazonSecurityLake-...' \
  -var='security_lake_bucket_arns=["arn:aws:s3:::aws-security-data-lake-us-east-1-..."]'
```

## Day-to-day checks

From the repository root:

```bash
just check
just clean
```

The normal path uses only Terraform providers. No CDK, build scripts, Lambda
packages, Python importer, or generated CloudFormation templates are required.

## Intentional simplifications

- OSIS replaces Lambda/EKS ingestion workers.
- Security Lake is the preferred fallback for services/logs that require deeper
  normalization than the generic direct pipeline.
- The old loader's most useful routing knowledge is retained as the
  `recommended_log_sources` Terraform output; producers should prefer those
  prefixes/index families or Security Lake OCSF where possible.
- Grafana dashboards were generated from the OpenSearch Dashboards saved objects;
  unsupported visualization types are kept as text/note panels rather than
  failing the deployment.
