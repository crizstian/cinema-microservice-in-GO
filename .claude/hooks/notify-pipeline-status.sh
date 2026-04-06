#!/bin/sh
# Stop hook: notifica el estado final de pipelines en la sesión

LOG_FILE="/tmp/claude-pipeline.log"

if [ -f "$LOG_FILE" ]; then
  COUNT=$(wc -l < "$LOG_FILE" 2>/dev/null || echo "0")
  echo "Session completed. Pipeline commands logged: $COUNT"
  echo '{"feedback": "Session ended. Run harness_status to get a final pipeline health summary."}'
  # Limpiar log de sesión
  rm -f "$LOG_FILE"
fi

exit 0