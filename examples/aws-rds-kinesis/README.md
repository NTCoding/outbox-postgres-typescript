# Outbox Pattern with AWS RDS PostgreSQL and Kinesis

This is a minimal implementation of the outbox pattern using AWS RDS PostgreSQL with AWS DMS streaming changes to Kinesis Data Streams.

## Architecture

1. **Application** writes business data and outbox messages to RDS PostgreSQL in a single transaction
2. **AWS DMS** captures changes from the outbox table and streams them to Kinesis
3. **Kinesis Consumer** processes the streamed outbox messages

## Prerequisites

- AWS CLI configured with appropriate permissions
- Terraform installed
- Node.js 18+
- TypeScript

## Setup

### 1. Deploy AWS Infrastructure

```bash
./setup-infrastructure.sh
```

This script will:
- Check prerequisites (AWS CLI, Terraform)
- Prompt for a secure database password
- Deploy the complete AWS infrastructure using Terraform
- Create RDS PostgreSQL, Kinesis Data Stream, DMS components, VPC, and security groups

### 2. Configure Application

```bash
cp .env.example .env
# Edit .env with your RDS endpoint (from Terraform output) and AWS credentials
```

### 3. Setup and Start Application

```bash
./setup-application.sh
npm run setup-db
npm start
```

Visit `http://localhost:3000` to see the demo.

## How It Works

1. **Add Person**: Creates a person record and outbox message in a single transaction
2. **DMS Streaming**: AWS DMS captures outbox table changes and streams to Kinesis
3. **Message Processing**: Kinesis consumer receives and processes the streamed messages

## Key Files

- `src/database.ts` - Database operations with transactional outbox writes
- `src/kinesis-consumer.ts` - Kinesis stream consumer
- `src/server.ts` - Express server with web UI
- `terraform/main.tf` - AWS infrastructure as code

## Testing

1. Add a person through the web UI
2. Check the outbox table for the new message
3. Verify the message appears in Kinesis stream
4. Observe console logs showing message processing

## Cleanup

```bash
cd terraform
terraform destroy -auto-approve
```

## Cost Considerations

This demo uses:
- RDS db.t3.micro instance (~$13/month)
- DMS dms.t3.micro instance (~$13/month)
- Kinesis stream with 1 shard (~$11/month)

Remember to destroy resources when done testing.