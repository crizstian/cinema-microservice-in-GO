# Dockerfile for MongoDB initialization
# Bakes in the init scripts to avoid volume mount issues with Docker-in-Docker
FROM mongo:8.0

COPY *.js /scripts/

ENTRYPOINT ["bash", "-c", "\
  mongosh --host mongo:27017 --eval 'rs.initiate({_id:\"rs0\",members:[{_id:0,host:\"mongo:27017\"}]})' 2>/dev/null || true && \
  sleep 3 && \
  for script in /scripts/*.js; do \
    [ -f \"$script\" ] && mongosh --host mongo:27017 < \"$script\"; \
  done \
"]
