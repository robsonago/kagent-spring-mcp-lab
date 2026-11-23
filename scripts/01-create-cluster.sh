#!/usr/bin/env bash
# Cria o cluster kind (idempotente).
source "$(dirname "$0")/lib.sh"

require_cmd kind

step "Criando cluster kind '${CLUSTER_NAME}'"
if kind get clusters 2>/dev/null | grep -qx "${CLUSTER_NAME}"; then
  ok "Cluster já existe, reaproveitando"
else
  kind create cluster --name "${CLUSTER_NAME}" --config "${ROOT_DIR}/kind/kind-config.yaml" --wait 120s
fi

use_cluster_context
kubectl wait --for=condition=Ready nodes --all --timeout=120s
ok "Cluster pronto: $(kubectl config current-context)"
