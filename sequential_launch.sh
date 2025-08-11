#!/bin/bash

NODES=("os-gpu-01" "os-gpu-02" "os-gpu-03" "os-gpu-04" "os-gpu-05")
RUN_NAME="benchmark-new-network"

for NODE in "${NODES[@]}"; do
  RELEASE="fio-bench-${NODE}"
  echo "⏳ Launching FIO benchmark on $NODE (Helm release: $RELEASE)"

  helm upgrade --install "$RELEASE" . \
    -n pgr24james \
    --set nodes={$NODE} \
    --set run_name="${RUN_NAME}" \
    --set useEmptyDir=false \
    --set dataDir="100_data" \
    --set fileSize="100G"\
    --set iterations=5 \
    --set probe_node=false \
    --set fioPvcName="fio-test"

  echo "  Waiting for pod on $NODE to complete..."

  while true; do
  while true; do
    POD_NAME=$(kubectl get pods -n pgr24james \
      -l benchmark=fio-readonly \
      --field-selector spec.nodeName=${NODE} \
      -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)

    if [[ -z "$POD_NAME" ]]; then
      echo "Pod not yet scheduled on $NODE... retrying in 5s"
      sleep 5
      continue
    fi

    CONTAINER_STATUS=$(kubectl get pod "$POD_NAME" -n pgr24james -o jsonpath='{.status.containerStatuses[?(@.name=="fio")].state.terminated.reason}')

    if [[ "$CONTAINER_STATUS" == "Completed" || "$CONTAINER_STATUS" == "Error" ]]; then
      echo "✅ Container 'fio' in $POD_NAME finished with status: $CONTAINER_STATUS"
      break
    fi

    echo "⏳ 'fio' container still running... current status: $CONTAINER_STATUS"
    sleep 10
  done
  echo "🧹 Deleting Helm release: $RELEASE"
  helm uninstall "$RELEASE" -n pgr24james
done
echo "🎉 All FIO benchmarks completed sequentially."
