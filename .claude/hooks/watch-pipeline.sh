#!/bin/sh
# PostToolUse hook: inspecciona si el comando Bash fue una ejecución de pipeline

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | grep -o '"command":"[^"]*"' | head -1 | sed 's/"command":"//;s/"//')

# Solo actuar si el comando involucra harness o pipeline
if echo "$COMMAND" | grep -qiE "(harness|pipeline|deploy)"; then
  TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
  echo "[$TIMESTAMP] Pipeline command detected: $COMMAND" >> /tmp/claude-pipeline.log
  # Señal para que Claude revise el estado
  echo '{"feedback": "Pipeline command executed. Please verify execution status using harness_status or harness_list for executions."}'
fi

exit 0