#!/bin/bash
# XIAM System Deployment Helper Script
# This script assists with generating secure keys and preparing for deployment

set -e  # Exit on error

# Function to generate a random string
generate_secret() {
  openssl rand -base64 64 | tr -d '\n'
}

# Banner
echo "======================================================"
echo "XIAM Customer Identity and Access Management System"
echo "Deployment Helper Script"
echo "======================================================"

# Create .env file for docker-compose
if [ ! -f .env ]; then
  echo "Creating .env file with secure random secrets..."
  cat > .env << EOL
# Auto-generated secure deployment configuration
# Created on $(date)

# Phoenix configuration
SECRET_KEY_BASE=$(generate_secret)
PHX_HOST=your-domain-here.com

# JWT configuration
JWT_SECRET=$(generate_secret)

# Admin user
ADMIN_EMAIL=admin@your-domain.com
ADMIN_PASSWORD=$(openssl rand -base64 12)

# Database
DATABASE_URL=ecto://postgres:postgres@db/xiam_prod

# SMTP for emails
SMTP_SERVER=smtp.your-provider.com
SMTP_PORT=587
SMTP_USERNAME=your-username
SMTP_PASSWORD=your-password
SMTP_FROM=noreply@your-domain.com

# OAuth providers (if using)
GITHUB_CLIENT_ID=
GITHUB_CLIENT_SECRET=
GOOGLE_CLIENT_ID=
GOOGLE_CLIENT_SECRET=
EOL
  echo ".env file created with secure random values"
  echo "IMPORTANT: Please edit .env to set your custom configuration values!"
  echo "           The admin password has been auto-generated as: $(grep ADMIN_PASSWORD .env | cut -d= -f2)"
  echo "           Make sure to change this in production!"
else
  echo ".env file already exists. Skipping creation."
fi

# Prepare release directories
mkdir -p rel

# Check if Docker is available
if command -v docker &> /dev/null; then
  echo "Docker is installed. You can build and run using:"
  echo "  docker-compose build"
  echo "  docker-compose up -d"
else
  echo "Docker not found. For containerized deployment, please install Docker."
  echo "Alternatively, you can deploy using Elixir releases:"
  echo "  MIX_ENV=prod mix release"
fi

echo ""
echo "Deployment preparations complete!"
echo "For production deployment, please ensure you:"
echo "1. Update the .env file with your actual domain and credentials"
echo "2. Configure your web server or load balancer for HTTPS"
echo "3. Set appropriate file permissions"
echo "4. Configure database backups"
echo "5. Set up monitoring and alerting"
echo ""
echo "For detailed deployment instructions, refer to the documentation."
echo "======================================================"

# Make script executable
chmod +x bin/deploy.sh
