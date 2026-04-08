#!/usr/bin/env bash
# Check health status of infrastructure and services
# Usage: ./health.sh

set -euo pipefail

echo "Infrastructure:"
curl -s http://localhost:27017 > /dev/null 2>&1 && echo "  [OK] MongoDB" || echo "  [--] MongoDB"
redis-cli ping > /dev/null 2>&1 && echo "  [OK] Redis" || echo "  [--] Redis"
echo ""
echo "Services:"
for port in 8000 8001 8002 8004 8082 8085 3003 3004; do
  curl -s "http://localhost:$port/health" > /dev/null 2>&1 && echo "  [OK] :$port" || echo "  [--] :$port"
done
