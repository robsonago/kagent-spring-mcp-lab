#!/usr/bin/env bash
# Remove o cluster kind inteiro.
source "$(dirname "$0")/lib.sh"

require_cmd kind

step "Removendo cluster kind '${CLUSTER_NAME}'"
kind delete cluster --name "${CLUSTER_NAME}"
ok "Cluster removido"
