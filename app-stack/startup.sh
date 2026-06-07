#!/bin/bash
set -e

echo "🔨 Forcing rebuild of all images..."
docker-compose build --no-cache

echo "🚀 Starting services..."
docker-compose up
