#!/bin/bash
echo "🧹 Stopping and cleaning up containers, and local folders..."
docker-compose down -v
docker rm $(docker ps -a -q)
rm -rf ./warehouse ./notebooks
echo "✅ Cleanup complete!"
