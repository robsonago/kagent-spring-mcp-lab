#!/usr/bin/env bash
# Volta o checkout-api ao estado quebrado, para repetir a demonstração.
source "$(dirname "$0")/lib.sh"

use_cluster_context

step "Removendo PAYMENT_GATEWAY_URL do ConfigMap"
kubectl -n shop patch configmap checkout-config --type json \
  -p '[{"op":"remove","path":"/data/PAYMENT_GATEWAY_URL"}]' 2>/dev/null || true
kubectl -n shop rollout restart deployment/checkout-api
ok "checkout-api vai voltar a falhar em alguns segundos"
