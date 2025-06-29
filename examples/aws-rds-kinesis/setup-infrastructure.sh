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

echo "🏗️  Setting up AWS Infrastructure for Outbox Demo in region: $AWS_REGION..."


# Check if we're in the right directory
if [ ! -d "terraform" ]; then
    echo "❌ terraform directory not found. Please run this script from the examples/aws-rds-kinesis directory."
    exit 1
fi

# Use database password from environment variable (already validated above)
db_password="$DB_PASSWORD"
echo "🔐 Using database password from environment variable"

echo ""
echo "🚀 Deploying AWS infrastructure..."

cd terraform


# Initialize Terraform
echo "📋 Initializing Terraform..."
terraform init


# Plan deployment
echo "📝 Planning Terraform deployment..."
terraform plan -var="db_password=$db_password" -var="aws_region=$AWS_REGION"


# Apply Terraform configuration
echo "🏗️  Applying Terraform configuration..."
terraform apply -var="db_password=$db_password" -var="aws_region=$AWS_REGION" -auto-approve

# Get the RDS endpoint from Terraform output
echo "📋 Getting RDS endpoint from Terraform..."
rds_endpoint=$(terraform output -raw rds_endpoint)

# Go back to the main directory to update .env
cd ..

# Update .env file with the RDS endpoint
echo "📝 Updating .env file with RDS endpoint..."
if [ -f ".env" ]; then
    # Update existing .env file
    if grep -q "^DB_HOST=" .env; then
        sed -i.bak "s/^DB_HOST=.*/DB_HOST=$rds_endpoint/" .env && rm .env.bak
    else
        echo "DB_HOST=$rds_endpoint" >> .env
    fi
else
    echo "⚠️  .env file not found. Creating from .env.example..."
    cp .env.example .env
    sed -i.bak "s/^DB_HOST=.*/DB_HOST=$rds_endpoint/" .env && rm .env.bak
fi

echo ""
echo "✅ AWS infrastructure deployed successfully!"
echo "✅ .env file updated with RDS endpoint: $rds_endpoint"
echo ""
echo "📋 Next steps:"
echo "1. Update .env with your AWS credentials if not already set"
echo "2. Run: ./setup-application.sh"