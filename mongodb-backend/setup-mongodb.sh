#!/bin/bash

# Check if mongocli is installed
if ! command -v mongocli &> /dev/null; then
    echo "Installing MongoDB CLI..."
    npm install -g mongocli
fi

# Login to MongoDB Atlas
echo "Please login to MongoDB Atlas..."
mongocli auth login

# Create project
echo "Creating project..."
PROJECT_NAME="E-Voting System"
PROJECT_ID=$(mongocli iam projects create "$PROJECT_NAME" --output json | jq -r '.id')

# Create cluster
echo "Creating cluster..."
CLUSTER_NAME="e-voting-cluster"
mongocli atlas cluster create "$CLUSTER_NAME" \
  --projectId "$PROJECT_ID" \
  --provider AWS \
  --region US_EAST_1 \
  --tier M0 \
  --members 3 \
  --diskSizeGB 2

# Wait for cluster to be ready
echo "Waiting for cluster to be ready..."
sleep 300

# Get connection string
echo "Getting connection string..."
CONNECTION_STRING=$(mongocli atlas cluster connectionstring "$CLUSTER_NAME" --projectId "$PROJECT_ID" --output json | jq -r '.connectionStrings.standardSrv')

# Create database user
echo "Creating database user..."
DB_USERNAME="evoting_admin"
DB_PASSWORD=$(openssl rand -base64 12)
mongocli atlas dbusers create \
  --username "$DB_USERNAME" \
  --password "$DB_PASSWORD" \
  --projectId "$PROJECT_ID" \
  --role "readWrite@e-voting"

# Update .env file
echo "Updating .env file..."
sed -i "s|MONGODB_URI=.*|MONGODB_URI=$CONNECTION_STRING|" .env
sed -i "s|DB_USERNAME=.*|DB_USERNAME=$DB_USERNAME|" .env
sed -i "s|DB_PASSWORD=.*|DB_PASSWORD=$DB_PASSWORD|" .env

echo "Setup complete!"
echo "Your MongoDB connection details have been saved to .env"
echo "Please keep your credentials secure!" 