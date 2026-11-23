#!/usr/bin/env bash
# Aplica a correção recomendada pelo runbook (fora do agente, como faria um humano).
source "$(dirname "$0")/lib.sh"

use_cluster_context

step "Corrigindo ConfigMap checkout-config"
kubectl -n shop patch configmap checkout-config --type merge \
  -p '{"data":{"PAYMENT_GATEWAY_URL":"http://payment-gateway.shop.svc.cluster.local:8080"}}'
kubectl -n shop rollout restart deployment/checkout-api
kubectl -n shop rollout status deployment/checkout-api --timeout=120s
kubectl -n shop logs deployment/checkout-api --tail=5
ok "checkout-api saudável. Pergunte de novo ao agente com: make ask"
