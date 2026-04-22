# Serverless Expense Tracker: Architecture & System Design

An automated, event-driven serverless pipeline for ingesting, extracting, and syncing financial receipts. This project serves as a practical implementation of advanced cloud-native patterns, focusing on asynchronous decoupling, resilience, and operational efficiency.

---

## 🏛 Core Architectural Principles

This system was designed with the following constraints and principles in mind:
1. **Asynchronous & Event-Driven:** No component synchronously waits for another. State is passed through managed queues, streams, and orchestrators.
2. **Serverless First:** Zero infrastructure to provision or patch. The architecture scales to zero when idle, minimizing costs for intermittent workloads.
3. **Optimized Network Paths:** Avoiding unnecessary managed services (like API Gateway) where native SDKs or direct integrations offer better performance and higher payload limits.
4. **Resilience over Reliability:** Acknowledging that third-party LLM APIs will fail, timeout, or hallucinate, and designing the orchestration layer to handle these gracefully.

---

## 🧩 System Components & Key Design Decisions

### 1. The Ingestion Layer: Telegram to S3
* **Mechanism:** A Telegram Bot webhook pushes event payloads directly to an AWS Lambda Function URL.
* **Design Decision - Bypassing API Gateway:** Traditional architectures place API Gateway in front of Lambda. This was explicitly rejected because API Gateway enforces a strict 10MB payload limit (problematic for 4K receipt photos) and adds unnecessary cost/latency. Lambda Function URLs provide a direct, secure HTTPS endpoint.
* **Design Decision - Native Compression:** By utilizing Telegram as the ingestion client, the system benefits from Telegram's native client-side image compression, saving S3 storage costs and reducing Lambda memory requirements during processing.
* **Data Flow:** The Lambda function authenticates the webhook, fetches the image bytes into memory, and performs a direct `boto3` PutObject to S3, bypassing presigned-url generation entirely.

### 2. The Orchestration Layer: AWS Step Functions
* **Mechanism:** An EventBridge rule detects the `ObjectCreated` event in the `raw_receipts/` S3 prefix and triggers an AWS Step Function State Machine.
* **Design Decision - State Externalization:** Calling external AI APIs (OpenRouter) is inherently flaky. Instead of writing complex retry loops and timeout handlers inside a Lambda function, that logic is offloaded to Step Functions. 
* **Resilience:** The state machine is configured with exponential backoff for API timeouts and routes unprocessable receipts (or persistent failures) to an SQS Dead Letter Queue (DLQ) for manual review.

### 3. The Extraction Layer: Vision LLM OCR
* **Mechanism:** A processing Lambda pulls the image from S3 and interfaces with **Nvidia Nemotron-Nano-12b-V2-VL** via OpenRouter.
* **Design Decision - Prompt Engineering for Strict Schema:** The LLM is constrained to output strict, parseable JSON. The schema enforces data normalization (e.g., standardizing "Vendor", "TotalAmount", "Taxes", and nested "LineItems").
* **Validation:** If the LLM fails to locate critical compliance data (like a Tax ID), the payload is still written to the database but flagged with a `NeedsReview` boolean.

### 4. The Data & Reporting Layer: DynamoDB to Google Sheets
* **Mechanism:** The Step Function writes the validated JSON to a DynamoDB table.
* **Design Decision - EventBridge Pipes:** To sync data to Google Sheets, the system uses DynamoDB Streams (`NEW_IMAGE`). Instead of writing a custom Lambda to poll the stream (which requires managing shard iterators and batching logic), **EventBridge Pipes** is used. It natively polls the stream, filters out non-insert events, and invokes the Sheets Sync Lambda.
* **Security:** Google Cloud Service Account credentials are not stored in code. They are encrypted in **AWS Systems Manager (SSM) Parameter Store** and decrypted at runtime by the Sync Lambda.

---

## 🛠 Infrastructure as Code (Terraform) Strategy

The infrastructure is provisioned entirely via Terraform, organized using **System-Level Modularization** rather than raw resource modules. 

* **`modules/system_ingestion/`**: Encapsulates the S3 bucket, Lambda URL, and Telegram webhook binding.
* **`modules/system_processing/`**: Contains the Step Function definition, OCR Lambda, IAM roles, and SQS DLQ.
* **`modules/system_reporting/`**: Manages the DynamoDB table, EventBridge Pipe, SSM parameters, and Sheets Sync Lambda.

**Why this approach?** It treats the infrastructure as logical business domains. If we later replace Google Sheets with PostgreSQL, we only modify the `reporting` module, leaving `ingestion` and `processing` completely untouched.

---

## 🔮 Future Scalability Considerations

* **Rate Limiting:** Currently, the EventBridge Pipe invokes the Sheets Lambda directly. If receipt volume spikes, this could trigger Google Sheets API rate limits (HTTP 429). A future iteration would place an SQS queue between the Pipe and the Lambda to buffer and throttle writes.
* **Multi-Tenancy:** The DynamoDB partition key could be updated from `ReceiptID` to `UserID#ReceiptID`, allowing the bot to serve multiple users and route data to different spreadsheets based on the Telegram `chat_id`.