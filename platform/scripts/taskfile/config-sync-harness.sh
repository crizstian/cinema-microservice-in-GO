#!/bin/bash
# config-sync-harness.sh
# Generates Harness service YAML files from config/services.yaml
# These can be used to create/update Harness services via API or UI

set -e

CONFIG_FILE="platform/config/services.yaml"
OUTPUT_DIR="platform/deploy/harness/services"

if ! command -v yq &> /dev/null; then
    echo "ERROR: yq is required. Install with: brew install yq"
    exit 1
fi

if [ ! -f "$CONFIG_FILE" ]; then
    echo "ERROR: $CONFIG_FILE not found"
    exit 1
fi

mkdir -p "$OUTPUT_DIR"

echo "Generating Harness service definitions from $CONFIG_FILE..."

for svc in $(yq '.services | keys | .[]' "$CONFIG_FILE"); do
    port=$(yq ".services.${svc}.port" "$CONFIG_FILE")
    dbName=$(yq ".services.${svc}.dbName" "$CONFIG_FILE")
    image=$(yq ".services.${svc}.image" "$CONFIG_FILE")
    cpu_req=$(yq ".services.${svc}.resources.cpu_request" "$CONFIG_FILE")
    mem_req=$(yq ".services.${svc}.resources.mem_request" "$CONFIG_FILE")
    cpu_lim=$(yq ".services.${svc}.resources.cpu_limit" "$CONFIG_FILE")
    mem_lim=$(yq ".services.${svc}.resources.mem_limit" "$CONFIG_FILE")

    # Convert service name to identifier (no hyphens)
    identifier="${svc}service"

    cat > "$OUTPUT_DIR/${svc}-service.yaml" << EOF
# Harness Service Definition
# Generated from config/services.yaml
# Use: harness_create or harness_update to sync

service:
  name: ${svc}-service
  identifier: ${identifier}
  serviceDefinition:
    type: Kubernetes
    spec:
      manifests:
        - manifest:
            identifier: templates
            type: K8sManifest
            spec:
              store:
                type: Github
                spec:
                  connectorRef: CristianConnector
                  gitFetchType: Branch
                  paths:
                    - platform/deploy/kubernetes/templates/services/
                  repoName: cinema-microservice-in-GO
                  branch: <+pipeline.variables.branch>
              valuesPaths:
                - platform/deploy/kubernetes/values/base.yaml
                - platform/deploy/kubernetes/values/environments/<+env.name>.yaml
                - platform/deploy/kubernetes/values/services/${svc}.yaml
              skipResourceVersioning: true
      artifacts:
        primary:
          primaryArtifactRef: artifact
          sources:
            - identifier: artifact
              type: DockerRegistry
              spec:
                connectorRef: DockerCristian
                imagePath: ${image}
                tag: <+input>
      variables:
        - name: port
          type: String
          value: "${port}"
        - name: dbName
          type: String
          value: "${dbName}"
        - name: cpu_request
          type: String
          value: "${cpu_req}"
        - name: mem_request
          type: String
          value: "${mem_req}"
        - name: cpu_limit
          type: String
          value: "${cpu_lim}"
        - name: mem_limit
          type: String
          value: "${mem_lim}"
  gitOpsEnabled: false
EOF

    echo "Generated: $OUTPUT_DIR/${svc}-service.yaml"
done

echo ""
echo "=== Summary ==="
echo "Generated $(ls -1 $OUTPUT_DIR/*.yaml | wc -l) Harness service definitions in $OUTPUT_DIR/"
echo ""
echo "To sync with Harness, use the MCP tool:"
echo "  harness_update(resource_type='service', resource_id='<identifier>', body={yaml: '<content>'})"
