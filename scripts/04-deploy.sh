#!/usr/bin/env bash
# Faz o deploy do MCP Server, das apps de demonstração e dos recursos do kagent.
source "$(dirname "$0")/lib.sh"

require_api_key
use_cluster_context

step "Deploy do service-catalog (MCP Server Spring Boot)"
kubectl apply -f "${ROOT_DIR}/k8s/catalog/service-catalog.yaml"
kubectl -n catalog rollout status deployment/service-catalog --timeout=300s
ok "service-catalog no ar"

step "Deploy das apps de demonstração (namespace shop)"
kubectl apply -f "${ROOT_DIR}/k8s/demo-shop/shop.yaml"
ok "Apps aplicadas (o checkout-api vai entrar em CrashLoopBackOff de propósito)"

step "Credencial do LLM e ModelConfig (${KAGENT_PROVIDER_ENUM} / ${LLM_MODEL})"
kubectl -n "${KAGENT_NAMESPACE}" create secret generic lab-llm-credentials \
  --from-literal=API_KEY="${LLM_API_KEY}" \
  --dry-run=client -o yaml | kubectl apply -f -

kubectl apply -f - <<EOF
apiVersion: kagent.dev/v1alpha2
kind: ModelConfig
metadata:
  name: lab-model-config
  namespace: ${KAGENT_NAMESPACE}
spec:
  provider: ${KAGENT_PROVIDER_ENUM}
  model: ${LLM_MODEL}
  apiKeySecret: lab-llm-credentials
  apiKeySecretKey: API_KEY
  ${KAGENT_PROVIDER_BLOCK}
EOF

step "Registrando o MCP Server no kagent (RemoteMCPServer)"
kubectl apply -f "${ROOT_DIR}/k8s/kagent/remote-mcp-server.yaml"

step "Criando o agente ${AGENT_NAME}"
kubectl apply -f "${ROOT_DIR}/k8s/kagent/agent.yaml"

echo "Aguardando o RemoteMCPServer ser aceito (o kagent chama tools/list no Spring Boot)..."
kubectl -n "${KAGENT_NAMESPACE}" wait --for=condition=Accepted remotemcpserver/service-catalog-mcp --timeout=120s \
  || warn "RemoteMCPServer ainda não aceito. Veja: kubectl -n kagent describe remotemcpserver service-catalog-mcp"

echo "Aguardando o agente ficar Ready (o kagent cria um Deployment para ele)..."
kubectl -n "${KAGENT_NAMESPACE}" wait --for=condition=Ready "agent/${AGENT_NAME}" --timeout=300s \
  || warn "O agente ainda não está Ready. Veja: kubectl -n kagent describe agent ${AGENT_NAME}"

echo
kubectl -n "${KAGENT_NAMESPACE}" get modelconfig,remotemcpserver,agent
ok "Deploy concluído"
