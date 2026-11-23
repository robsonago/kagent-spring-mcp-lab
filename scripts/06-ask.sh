#!/usr/bin/env bash
# Envia uma pergunta ao agente. Usa o kagent CLI se existir; senão, chama o
# endpoint A2A do controller com curl (JSON-RPC "message/send").
#
# Uso: scripts/06-ask.sh "sua pergunta"
source "$(dirname "$0")/lib.sh"

use_cluster_context

QUESTION="${1:-Há algum Pod com problema no namespace shop? Faça a triagem completa e diga quem devo acionar.}"

step "Abrindo acesso ao controller do kagent (porta 8083)"
port_forward "${KAGENT_NAMESPACE}" svc/kagent-controller 8083:8083

echo
echo "${BOLD}Pergunta:${RESET} ${QUESTION}"
echo "(o agente pode levar de 20 s a 2 min, dependendo do modelo)"
echo

if command -v kagent >/dev/null 2>&1; then
  kagent invoke --namespace "${KAGENT_NAMESPACE}" --agent "${AGENT_NAME}" --task "${QUESTION}"
  exit 0
fi

require_cmd jq
A2A_URL="http://127.0.0.1:8083/api/a2a/${KAGENT_NAMESPACE}/${AGENT_NAME}/"
MESSAGE_ID="msg-$(date +%s)-${RANDOM}"

payload="$(jq -n --arg text "${QUESTION}" --arg id "${MESSAGE_ID}" '{
  jsonrpc: "2.0",
  id: 1,
  method: "message/send",
  params: { message: { kind: "message", role: "user", messageId: $id,
                       parts: [ { kind: "text", text: $text } ] } }
}')"

response="$(curl -sS --max-time 300 -X POST "${A2A_URL}" \
  -H "Content-Type: application/json" -d "${payload}")"

if jq -e '.error' >/dev/null 2>&1 <<<"${response}"; then
  echo "${response}" | jq .
  fail "O agente retornou erro"
fi

# A resposta final pode vir em artifacts (Task) ou direto em parts (Message).
answer="$(jq -r '
  [ (.result.artifacts[]?.parts[]? | select(.kind == "text") | .text),
    (.result.parts[]? | select(.kind == "text") | .text) ] | join("\n")
' <<<"${response}")"

if [[ -n "${answer}" ]]; then
  echo "${BOLD}Resposta do agente:${RESET}"
  echo "${answer}"
else
  warn "Formato de resposta inesperado; exibindo JSON bruto"
  echo "${response}" | jq .
fi
