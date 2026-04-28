#!/bin/bash
# Setup Monitored Services for CV
# This script creates monitored services for each Go service in each environment

set -euo pipefail

SERVICES="booking movie payment user cinema showtime seat notification"
ENVIRONMENTS="dev staging prod"
HARNESS_ACCOUNT_ID="${HARNESS_ACCOUNT_ID:-}"
HARNESS_API_KEY="${HARNESS_API_KEY:-}"
HARNESS_ORG="sandbox"
HARNESS_PROJECT="CristianRamirez"
PROMETHEUS_CONNECTOR="selatamprom"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

check_prerequisites() {
    if [[ -z "$HARNESS_ACCOUNT_ID" ]]; then
        log_error "HARNESS_ACCOUNT_ID is not set"
        exit 1
    fi
    if [[ -z "$HARNESS_API_KEY" ]]; then
        log_error "HARNESS_API_KEY is not set"
        exit 1
    fi
}

create_monitored_service() {
    local service=$1
    local env=$2
    local namespace="cinema-${env}"
    local ms_identifier="${service}_${env}"
    local ms_name="${service}_${env}"

    log_info "Creating monitored service: $ms_name"

    # Generate the monitored service JSON
    cat <<EOF > /tmp/monitored-service-${ms_identifier}.json
{
  "orgIdentifier": "${HARNESS_ORG}",
  "projectIdentifier": "${HARNESS_PROJECT}",
  "identifier": "${ms_identifier}",
  "name": "${ms_name}",
  "type": "Application",
  "description": "Monitored service for ${service} in ${env}",
  "serviceRef": "${service}servicegitops",
  "environmentRef": "${env}",
  "sources": {
    "healthSources": [
        {
          "name": "Prometheus",
          "identifier": "prometheus",
          "type": "Prometheus",
          "spec": {
            "connectorRef": "${PROMETHEUS_CONNECTOR}",
            "metricDefinitions": [
              {
                "identifier": "response_time_p99",
                "metricName": "Response Time P99",
                "riskProfile": {
                  "category": "Performance",
                  "metricType": "RESP_TIME",
                  "thresholdTypes": ["ACT_WHEN_HIGHER"]
                },
                "analysis": {
                  "deploymentVerification": {
                    "enabled": true,
                    "serviceInstanceFieldName": "pod"
                  },
                  "liveMonitoring": {
                    "enabled": true
                  }
                },
                "query": "histogram_quantile(0.99, sum(rate(http_request_duration_seconds_bucket{namespace=\"${namespace}\", pod=~\"${service}.*\"}[5m])) by (le, pod))",
                "groupName": "Performance"
              },
              {
                "identifier": "error_rate_5xx",
                "metricName": "5xx Error Rate",
                "riskProfile": {
                  "category": "Errors",
                  "metricType": "ERROR",
                  "thresholdTypes": ["ACT_WHEN_HIGHER"]
                },
                "analysis": {
                  "deploymentVerification": {
                    "enabled": true,
                    "serviceInstanceFieldName": "pod"
                  },
                  "liveMonitoring": {
                    "enabled": true
                  }
                },
                "query": "sum(rate(http_requests_total{namespace=\"${namespace}\", pod=~\"${service}.*\", status=~\"5..\"}[5m])) by (pod)",
                "groupName": "Errors"
              },
              {
                "identifier": "cpu_usage",
                "metricName": "CPU Usage",
                "riskProfile": {
                  "category": "Infrastructure",
                  "metricType": "INFRA",
                  "thresholdTypes": ["ACT_WHEN_HIGHER"]
                },
                "analysis": {
                  "deploymentVerification": {
                    "enabled": true,
                    "serviceInstanceFieldName": "pod"
                  },
                  "liveMonitoring": {
                    "enabled": true
                  }
                },
                "query": "sum(rate(container_cpu_usage_seconds_total{namespace=\"${namespace}\", pod=~\"${service}.*\", container!=\"POD\"}[5m])) by (pod) * 100",
                "groupName": "Infrastructure"
              },
              {
                "identifier": "memory_usage_mb",
                "metricName": "Memory Usage (MB)",
                "riskProfile": {
                  "category": "Infrastructure",
                  "metricType": "INFRA",
                  "thresholdTypes": ["ACT_WHEN_HIGHER"]
                },
                "analysis": {
                  "deploymentVerification": {
                    "enabled": true,
                    "serviceInstanceFieldName": "pod"
                  },
                  "liveMonitoring": {
                    "enabled": true
                  }
                },
                "query": "sum(container_memory_usage_bytes{namespace=\"${namespace}\", pod=~\"${service}.*\", container!=\"POD\"}) by (pod) / 1024 / 1024",
                "groupName": "Infrastructure"
              },
              {
                "identifier": "requests_per_second",
                "metricName": "Requests/sec",
                "riskProfile": {
                  "category": "Performance",
                  "metricType": "THROUGHPUT",
                  "thresholdTypes": ["ACT_WHEN_LOWER"]
                },
                "analysis": {
                  "deploymentVerification": {
                    "enabled": true,
                    "serviceInstanceFieldName": "pod"
                  },
                  "liveMonitoring": {
                    "enabled": true
                  }
                },
                "query": "sum(rate(http_requests_total{namespace=\"${namespace}\", pod=~\"${service}.*\"}[5m])) by (pod)",
                "groupName": "Throughput"
              }
            ]
          }
        }
      ]
    }
}
EOF

    # Create via API
    local response
    response=$(curl -s -w "\n%{http_code}" -X POST \
        "https://app.harness.io/cv/api/monitored-service?accountId=${HARNESS_ACCOUNT_ID}&orgIdentifier=${HARNESS_ORG}&projectIdentifier=${HARNESS_PROJECT}" \
        -H "x-api-key: ${HARNESS_API_KEY}" \
        -H "Content-Type: application/json" \
        -d @/tmp/monitored-service-${ms_identifier}.json)

    local http_code
    http_code=$(echo "$response" | tail -1)
    local body
    body=$(echo "$response" | sed '$d')

    if [[ "$http_code" == "200" ]] || [[ "$http_code" == "201" ]]; then
        log_info "Created: $ms_name"
    elif [[ "$http_code" == "409" ]]; then
        log_warn "Already exists: $ms_name"
    else
        log_error "Failed to create $ms_name: $http_code"
        echo "$body" | jq . 2>/dev/null || echo "$body"
    fi

    rm -f /tmp/monitored-service-${ms_identifier}.json
}

main() {
    log_info "Setting up Monitored Services for CV"
    log_info "Services: $SERVICES"
    log_info "Environments: $ENVIRONMENTS"

    check_prerequisites

    for service in $SERVICES; do
        for env in $ENVIRONMENTS; do
            create_monitored_service "$service" "$env"
        done
    done

    log_info "Done!"
}

main "$@"
