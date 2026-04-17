#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
K8S_DIR="$(dirname "$SCRIPT_DIR")"
REPO_ROOT="$(cd "$K8S_DIR/../../.." && pwd)"
SEED_DIR="$REPO_ROOT/platform/docker/mongodb/seed"

NAMESPACE="${1:-cinema-dev}"
MONGO_HOST="mongodb-0.mongodb.${NAMESPACE}.svc.cluster.local"

echo "=== Deploying MongoDB to namespace: $NAMESPACE ==="

# Step 1: Render and apply MongoDB StatefulSet
echo ""
echo ">>> Step 1: Rendering MongoDB template..."
"${K8S_DIR}/bin/render" -infra mongodb -base "$K8S_DIR"

echo ""
echo ">>> Step 2: Applying MongoDB manifests..."
kubectl apply -f "${K8S_DIR}/rendered/infrastructure/mongodb.yaml"

# Step 3: Wait for MongoDB to be ready
echo ""
echo ">>> Step 3: Waiting for MongoDB to be ready..."
kubectl wait --namespace "$NAMESPACE" \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/name=mongodb \
  --timeout=180s

# Step 4: Delete previous seed job if exists
echo ""
echo ">>> Step 4: Cleaning up previous seed job..."
kubectl delete job mongodb-seed --namespace "$NAMESPACE" --ignore-not-found
kubectl delete configmap mongodb-seed-scripts --namespace "$NAMESPACE" --ignore-not-found

# Step 5: Create ConfigMap with modified seed scripts (K8s-compatible hostnames)
echo ""
echo ">>> Step 5: Creating seed scripts ConfigMap..."

# Create temp dir for modified scripts
TEMP_DIR=$(mktemp -d)
trap "rm -rf $TEMP_DIR" EXIT

# Copy and modify scripts to use K8s hostname
for script in "$SEED_DIR"/*.js; do
  # Replace docker-compose hostname with K8s hostname
  sed "s|mongo:27017|${MONGO_HOST}:27017|g; s|host: \"mongo\"|host: \"${MONGO_HOST}\"|g" \
    "$script" > "$TEMP_DIR/$(basename "$script")"
done

kubectl create configmap mongodb-seed-scripts \
  --namespace "$NAMESPACE" \
  --from-file="$TEMP_DIR"

# Step 6: Run seed Job with nodeSelector/tolerations
echo ""
echo ">>> Step 6: Running seed job..."

cat <<YAML | kubectl apply -f -
apiVersion: batch/v1
kind: Job
metadata:
  name: mongodb-seed
  namespace: $NAMESPACE
spec:
  backoffLimit: 5
  ttlSecondsAfterFinished: 600
  template:
    spec:
      restartPolicy: OnFailure
      nodeSelector:
        owner: cristian-ramirez
      tolerations:
        - key: "dedicated"
          operator: "Equal"
          value: "selatam_demo_space"
          effect: "NoSchedule"
      containers:
        - name: mongo-seed
          image: mongo:8.0
          command:
            - /bin/bash
            - -c
            - |
              set -e
              MONGO_HOST="${MONGO_HOST}"
              
              echo "=== MongoDB Seed ==="
              echo "Host: \$MONGO_HOST"
              
              echo ""
              echo "Waiting for MongoDB..."
              for i in \$(seq 1 60); do
                if mongosh --host \$MONGO_HOST:27017 --eval "db.adminCommand('ping')" > /dev/null 2>&1; then
                  echo "MongoDB ready!"
                  break
                fi
                echo "  Waiting... (\$i/60)"
                sleep 2
              done
              
              echo ""
              echo "Running seed scripts..."
              for script in /scripts/*.js; do
                [ -f "\$script" ] || continue
                echo "  \$(basename \$script)"
                mongosh --host \$MONGO_HOST:27017 < "\$script" 2>&1 || echo "  (warning: script had errors)"
              done
              
              echo ""
              echo "Waiting for PRIMARY..."
              for i in \$(seq 1 30); do
                PRIMARY=\$(mongosh --host \$MONGO_HOST:27017 --quiet --eval "rs.status().members?.find(m => m.stateStr === 'PRIMARY')?.name" 2>/dev/null || echo "")
                if [ -n "\$PRIMARY" ] && [ "\$PRIMARY" != "null" ] && [ "\$PRIMARY" != "undefined" ]; then
                  echo "  PRIMARY: \$PRIMARY"
                  break
                fi
                sleep 2
              done
              
              echo ""
              echo "Verification..."
              mongosh --host \$MONGO_HOST:27017 --eval "
                try { print('Replica: ' + rs.status().set); } catch(e) { print('Replica: standalone'); }
                db = db.getSiblingDB('cinema');
                print('Movies: ' + db.movies.countDocuments());
                print('Showtimes: ' + db.showtimes.countDocuments());
                db = db.getSiblingDB('cinema_seats');
                print('Room layouts: ' + db.room_layouts.countDocuments());
              "
              echo "=== Seed Complete ==="
          volumeMounts:
            - name: scripts
              mountPath: /scripts
      volumes:
        - name: scripts
          configMap:
            name: mongodb-seed-scripts
YAML

# Step 7: Wait for seed to complete
echo ""
echo ">>> Step 7: Waiting for seed job to complete..."
if kubectl wait --namespace "$NAMESPACE" --for=condition=complete job/mongodb-seed --timeout=180s; then
  echo ""
  echo ">>> Seed job logs:"
  kubectl logs -n "$NAMESPACE" job/mongodb-seed
else
  echo ""
  echo ">>> Seed job failed. Logs:"
  kubectl logs -n "$NAMESPACE" job/mongodb-seed || kubectl describe job mongodb-seed -n "$NAMESPACE"
fi

echo ""
echo "=== MongoDB deployment complete ==="
