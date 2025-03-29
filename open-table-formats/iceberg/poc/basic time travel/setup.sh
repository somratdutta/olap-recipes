#!/bin/bash

set -e  # Exit on error

echo "📁 Creating required directories..."
mkdir -p ./warehouse
mkdir -p ./notebooks

echo "🔐 Setting full access permissions..."
sudo chmod -R 777 ./warehouse
sudo chmod -R 777 ./notebooks

echo "🐳 Starting Docker Compose..."
docker-compose up -d
