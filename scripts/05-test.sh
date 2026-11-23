#!/usr/bin/env bash
# Testes de fumaça: valida o MCP Server direto e o registro dele no kagent.
source "$(dirname "$0")/lib.sh"

use_cluster_context

pretty() { if command -v jq >/dev/null 2>&1; then jq "$@"; else cat; fi; }

# A resposta pode vir como JSON puro ou como evento SSE ("data: {...}").
mcp_call() {
  curl -sS -X POST "http://127.0.0.1:18080/mcp" \
    -H "Content-Type: application/json" \
    -H "Accept: application/json, text/event-stream" \
    -d "$1" | sed -n -e 's/^data: //' -e '/^{/p'
}

step "1/3 Chamando o MCP Server diretamente (tools/list)"
port_forward catalog svc/service-catalog 18080:8080
tools_json="$(mcp_call '{"jsonrpc":"2.0","id":1,"method":"tools/list","params":{}}')"
echo "${tools_json}" | pretty '.result.tools[] | {name, description}' 2>/dev/null || echo "${tools_json}"
for tool in list_services get_service_owner get_runbook check_change_freeze; do
  grep -q "\"${tool}\"" <<<"${tools_json}" || fail "Tool ${tool} não encontrada na resposta"
done
ok "As 4 tools estão expostas"

step "2/3 Executando uma tool (tools/call get_service_owner)"
mcp_call '{"jsonrpc":"2.0","id":2,"method":"tools/call","params":{"name":"get_service_owner","arguments":{"service":"checkout-api"}}}' \
  | pretty '.result.content[0].text | fromjson? // .' 2>/dev/null || true
ok "Tool executada"

step "3/3 Verificando os recursos no kagent"
kubectl -n "${KAGENT_NAMESPACE}" get remotemcpserver service-catalog-mcp -o wide
echo
echo "Tools descobertas pelo kagent:"
kubectl -n "${KAGENT_NAMESPACE}" get remotemcpserver service-catalog-mcp \
  -o jsonpath='{range .status.discoveredTools[*]}  - {.name}{"\n"}{end}' 2>/dev/null || true
echo
kubectl -n "${KAGENT_NAMESPACE}" get agent "${AGENT_NAME}"
kubectl -n "${KAGENT_NAMESPACE}" get agent "${AGENT_NAME}" \
  -o jsonpath='{range .status.conditions[*]}  {.type}={.status} {.message}{"\n"}{end}'
echo
step "Situação das apps de demonstração"
kubectl -n shop get pods
ok "Testes concluídos. Próximo passo: make ask"
