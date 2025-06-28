#!/bin/bash

set -e

echo "🔧 Setting up Outbox Pattern Demo with PostgreSQL Logical Replication"
echo "=================================================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Default database configuration
DB_HOST=${DB_HOST:-localhost}
DB_PORT=${DB_PORT:-5432}
DB_USER=${DB_USER:-postgres}
DB_NAME=${DB_NAME:-outbox_demo}

echo -e "\n📦 Installing Node.js dependencies..."
npm install

echo -e "\n🐘 Checking PostgreSQL connection..."
if ! psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d postgres -c "SELECT 1;" > /dev/null 2>&1; then
    echo -e "${RED}❌ Cannot connect to PostgreSQL. Please ensure PostgreSQL is running and credentials are correct.${NC}"
    echo "Connection details:"
    echo "  Host: $DB_HOST"
    echo "  Port: $DB_PORT"
    echo "  User: $DB_USER"
    echo ""
    echo "You can set these environment variables:"
    echo "  export DB_HOST=your_host"
    echo "  export DB_PORT=your_port"
    echo "  export DB_USER=your_user"
    echo "  export DB_PASSWORD=your_password"
    exit 1
fi

echo -e "${GREEN}✅ PostgreSQL connection successful${NC}"

echo -e "\n🗄️  Creating database '$DB_NAME' if it doesn't exist..."
psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d postgres -c "CREATE DATABASE $DB_NAME;" 2>/dev/null || echo "Database already exists"

echo -e "\n⚙️  Verifying PostgreSQL configuration for logical replication..."

# Check current wal_level
CURRENT_WAL_LEVEL=$(psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -t -c "SHOW wal_level;" | xargs)

if [ "$CURRENT_WAL_LEVEL" != "logical" ]; then
    echo -e "${RED}❌ Current wal_level is '$CURRENT_WAL_LEVEL', but 'logical' is required${NC}"
    echo "Please ensure PostgreSQL is configured for logical replication."
    echo "See the Prerequisites section in README.md for setup instructions."
    exit 1
else
    echo -e "${GREEN}✅ wal_level is configured for logical replication${NC}"
fi

echo -e "\n🏗️  Setting up database schema and logical replication..."
npm run setup-db

echo -e "\n🔧 Building the application..."
npm run build

echo -e "\n📝 Creating environment file..."
if [ ! -f .env ]; then
    cp .env.example .env
    echo -e "${GREEN}✅ Created .env file from template${NC}"
    echo "You can modify .env if needed for your configuration."
else
    echo "✅ .env file already exists"
fi

echo -e "\n${GREEN}🎉 Setup completed successfully!${NC}"
echo "=================================================================="
echo ""
echo "To start the application:"
echo "  npm start"
echo ""
echo "Or for development:"
echo "  npm run dev"
echo ""
echo "Then visit: http://localhost:3000"
echo ""
echo "Log files will be created:"
echo "  - outbox-processed.log (processed messages)"
echo "  - outbox-errors.log (error messages)"