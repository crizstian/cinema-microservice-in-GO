#!/bin/bash
set -euo pipefail

SERVICES="${1:-booking}"
RUN_MODE="${2:-validate}"
BRANCH="${3:-step-1}"

ACCOUNT_ID="EeRjnXTnS4GrLG5VNNJZUw"
ORG="sandbox"
PROJECT="CristianRamirez"
PIPELINE="CI_Golang_v2"

if [ -z "${HARNESS_API_KEY:-}" ]; then
  echo "ERROR: HARNESS_API_KEY not set"
  exit 1
fi

# Map RUN_MODE to InputSet
case "$RUN_MODE" in
  build) INPUTSET="build_service" ;;
  full)  INPUTSET="full_pipeline" ;;
  *)     INPUTSET="validate_service" ;;
esac

echo "Pipeline: $PIPELINE"
echo "Services: $SERVICES"
echo "Run Mode: $RUN_MODE"
echo "Branch:   $BRANCH"
echo ""

RESPONSE=$(curl -s -X POST \
  "https://app.harness.io/pipeline/api/pipeline/execute/$PIPELINE?accountIdentifier=$ACCOUNT_ID&orgIdentifier=$ORG&projectIdentifier=$PROJECT" \
  -H "Content-Type: application/json" \
  -H "x-api-key: $HARNESS_API_KEY" \
  -d "{
    \"inputSetReferences\": [\"$INPUTSET\"],
    \"pipelineInputs\": {
      \"properties\": {
        \"ci\": { \"codebase\": { \"build\": { \"type\": \"branch\", \"spec\": { \"branch\": \"$BRANCH\" }}}}
      },
      \"variables\": [
        {\"name\": \"SERVICES\", \"value\": \"$SERVICES\", \"type\": \"String\"}
      ]
    }
  }")

EXEC_ID=$(echo "$RESPONSE" | jq -r '.data.planExecution.uuid // empty' 2>/dev/null)

if [ -n "$EXEC_ID" ]; then
  echo "Execution started: $EXEC_ID"
  echo "https://app.harness.io/ng/account/$ACCOUNT_ID/ci/orgs/$ORG/projects/$PROJECT/pipelines/$PIPELINE/executions/$EXEC_ID/pipeline"
else
  echo "$RESPONSE" | jq . 2>/dev/null || echo "$RESPONSE"
  exit 1
fi
