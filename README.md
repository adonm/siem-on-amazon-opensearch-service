# Simplified SIEM on Amazon OpenSearch Serverless

This branch removes the legacy CDK/CloudFormation/Lambda implementation and
keeps a simplified Terraform deployment path:

- Amazon OpenSearch Serverless NextGen
- Amazon OpenSearch Ingestion Service (OSIS) instead of custom Lambda/EKS workers
- Optional Security Lake fallback ingestion
- Amazon Managed Grafana with converted dashboard JSON

Start here:

```bash
cd terraform
terraform init
terraform apply
```

See [`terraform/README.md`](terraform/README.md) for variables, Security Lake
fallback setup, and Grafana dashboard import details.
