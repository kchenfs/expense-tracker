# Enterprise Expense Tracker

Event-driven, serverless expense tracker with LLM-powered OCR parsing.

## Architecture

```
Frontend → API Gateway → Auth Lambda → S3 Pre-signed URL
                                              ↓
                                    S3 ObjectCreated event
                                              ↓
                                     Step Functions SM
                                       ↙          ↘
                               OCR Parser λ    (on failure) → DLQ
                                       ↓
                                  DynamoDB write
                                       ↓
                               S3 Lifecycle → Glacier (24h)
```

## Stack
- **IaC**: Terraform (all infrastructure)
- **Compute**: AWS Lambda (Python 3.12)
- **Orchestration**: AWS Step Functions (Express Workflow)
- **Storage**: S3 Standard → Glacier Instant Retrieval (lifecycle)
- **Database**: DynamoDB (on-demand)
- **API**: API Gateway REST
- **Observability**: Datadog Lambda layer + custom metrics
- **CI/CD**: GitHub Actions

## Project Layout

```
expense-tracker/
├── terraform/
│   ├── modules/
│   │   ├── s3/
│   │   ├── dynamodb/
│   │   ├── lambda/
│   │   ├── step_functions/
│   │   └── api_gateway/
│   └── environments/
│       └── dev/
├── lambdas/
│   ├── auth_presign/      # Generates S3 pre-signed upload URL
│   ├── ocr_parser/        # Calls Anthropic API, extracts receipt fields
│   └── db_writer/         # Writes parsed JSON to DynamoDB
├── frontend/              # Lightweight HTML/JS upload UI
├── scripts/               # Local dev helpers
└── .github/workflows/     # CI/CD pipeline
```

## Quick Start

```bash
# 1. Bootstrap
cp terraform/environments/dev/terraform.tfvars.example terraform/environments/dev/terraform.tfvars
# Fill in your values (AWS account, Anthropic key ARN, Datadog key ARN)

# 2. Deploy
cd terraform/environments/dev
terraform init
terraform apply

# 3. Run frontend locally
open frontend/index.html
```

## Environment Variables (set in Terraform, injected via SSM)
| Variable | Where |
|---|---|
| `ANTHROPIC_API_KEY` | SSM Parameter Store (SecureString) |
| `DATADOG_API_KEY` | SSM Parameter Store (SecureString) |
| `DYNAMODB_TABLE_NAME` | Lambda env var |
| `RECEIPTS_BUCKET` | Lambda env var |
