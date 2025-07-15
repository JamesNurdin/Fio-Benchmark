#!/bin/bash

NODES=("os-gpu-02" "os-gpu-03" "os-gpu-04")
RUN_NAME="actual-test"

for NODE in "${NODES[@]}"; do
  RELEASE="fio-bench-${NODE}"
  echo "⏳ Launching FIO benchmark on $NODE (Helm release: $RELEASE)"

  helm upgrade --install "$RELEASE" . \
    -n pgr24james \
    --set nodes={$NODE} \
    --set run_name="${RUN_NAME}" \
    --set useEmptyDir=false \
    --set fioPvcName="fio-test"

  echo "  Waiting for pod on $NODE to complete..."

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

    STATUS=$(kubectl get pod "$POD_NAME" -n pgr24james -o jsonpath='{.status.phase}')
    if [[ "$STATUS" == "Succeeded" || "$STATUS" == "Failed" ]]; then
      echo "✅ $POD_NAME on $NODE finished with status: $STATUS"
      break
    fi

    echo "⏳ Still running... status = $STATUS"
    sleep 10
  done
done

echo "🎉 All FIO benchmarks completed sequentially."
