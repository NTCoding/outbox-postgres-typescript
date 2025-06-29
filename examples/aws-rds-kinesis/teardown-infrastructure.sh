#!/bin/bash

set -e

# Load environment variables from .env file
if [ -f ".env" ]; then
    echo "📋 Loading environment variables from .env file..."
    export $(grep -v '^#' .env | xargs)
else
    echo "❌ .env file not found. Please copy .env.example to .env and configure it."
    echo "   Required variables: AWS_REGION, DB_PASSWORD"
    exit 1
fi

# Check required environment variables
if [ -z "$AWS_REGION" ]; then
    echo "❌ AWS_REGION environment variable is not set in .env file"
    exit 1
fi

if [ -z "$DB_PASSWORD" ]; then
    echo "❌ DB_PASSWORD environment variable is not set in .env file"
    exit 1
fi

echo "🧹 Tearing down AWS Infrastructure for Outbox Demo in region: $AWS_REGION..."

# Check if we're in the right directory
if [ ! -d "terraform" ]; then
    echo "❌ terraform directory not found. Please run this script from the examples/aws-rds-kinesis directory."
    exit 1
fi

cd terraform

# Check if Terraform is installed
if ! command -v terraform &> /dev/null; then
    echo "❌ Terraform is not installed. Please install it first."
    exit 1
fi

echo "🏗️  Running terraform destroy..."

# Initialize Terraform
terraform init

# Run terraform destroy (handles no-state case automatically)
terraform destroy -var="db_password=$DB_PASSWORD" -var="aws_region=$AWS_REGION" -auto-approve

# Clean up Terraform files
echo "🧹 Cleaning up Terraform state and cache..."
rm -rf .terraform.lock.hcl .terraform/ terraform.tfstate* || true

echo ""
echo "✅ AWS infrastructure teardown complete!"
echo ""
echo "💡 All AWS resources have been destroyed and cleaned up."
echo "   No further charges should be incurred."