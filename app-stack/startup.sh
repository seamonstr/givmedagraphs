#!/bin/bash
set -e

echo "🗑️ Removing old containers..."
docker-compose down --remove-orphans

echo "🔨 Forcing rebuild of all images..."
docker-compose build --no-cache

echo "🚀 Starting services..."
docker-compose up
