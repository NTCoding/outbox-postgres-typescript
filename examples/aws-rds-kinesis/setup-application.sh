#!/bin/bash

set -e

echo "📱 Setting up Outbox Demo Application..."

# Check if AWS CLI is installed
if ! command -v aws &> /dev/null; then
    echo "❌ AWS CLI is not installed. Please install it first."
    exit 1
fi

# Check if Terraform is installed
if ! command -v terraform &> /dev/null; then
    echo "❌ Terraform is not installed. Please install it first."
    exit 1
fi

# Check if Node.js is installed
if ! command -v node &> /dev/null; then
    echo "❌ Node.js is not installed. Please install it first."
    exit 1
fi

echo "✅ Prerequisites check passed"

# Install npm dependencies
echo "📦 Installing Node.js dependencies..."
npm install

# Check if .env exists
if [ ! -f .env ]; then
    echo "⚠️  .env file not found. Please copy .env.example to .env and configure it."
    echo "   You'll need to deploy the AWS infrastructure first to get the RDS endpoint."
    echo ""
    echo "   Steps:"
    echo "   1. Run: ./setup-infrastructure.sh"
    echo "   2. Copy .env.example to .env and update with RDS endpoint"
    echo "   3. Run this setup script again"
    exit 1
fi

echo "✅ Environment file found"

# Build the application
echo "🔨 Building application..."
npm run build

# Setup database tables
echo "🗄️  Setting up database tables..."
npm run setup-db

echo "✅ Outbox Demo Application setup complete!"
echo ""
echo "Next steps:"
echo "1. Start the DMS task in AWS Console"
echo "2. Run: npm start"
echo "3. Visit: http://localhost:3000"