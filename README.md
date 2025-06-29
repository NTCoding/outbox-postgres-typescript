# Outbox Pattern Examples with PostgreSQL and TypeScript

This repository contains minimal implementations of the outbox pattern using different streaming approaches with PostgreSQL and TypeScript.

## Examples

### 1. [Logical Replication](./examples/logical-replication/)

Uses PostgreSQL's built-in logical replication with push-based streaming.

**Architecture:**
- PostgreSQL logical replication slot captures outbox changes
- wal2json extension converts changes to JSON
- Application subscribes directly to the replication stream

**Best for:**
- Local development and testing
- Direct PostgreSQL access scenarios
- Minimal external dependencies

### 2. [AWS RDS + Kinesis](./examples/aws-rds-kinesis/)

Uses AWS DMS to stream outbox changes from RDS PostgreSQL to Kinesis Data Streams.

**Architecture:**
- AWS DMS captures changes from RDS PostgreSQL outbox table
- Changes are streamed to Kinesis Data Streams
- Application consumes from Kinesis stream

**Best for:**
- Production AWS environments
- Managed service approach
- Integration with other AWS services

## Common Pattern

Both examples implement the same core outbox pattern:

1. **Transactional Write**: Business data and outbox message written in single transaction
2. **Change Capture**: External system captures outbox table changes
3. **Stream Processing**: Application processes the captured changes
4. **Business Data**: Same `people` table and outbox message format

## Quick Start

Choose the example that fits your use case:

```bash
# PostgreSQL Logical Replication
cd examples/logical-replication
./setup.sh

# AWS RDS + Kinesis  
cd examples/aws-rds-kinesis
./setup.sh
```