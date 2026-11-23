# kagent + Spring Boot MCP Server: agente de IA de SRE rodando no Kubernetes

Laboratório completo e reproduzível: um **agente de IA declarativo (kagent)** que faz a triagem
de incidentes no cluster, combinando as tools nativas de Kubernetes do kagent com tools de
negócio expostas por uma **API Spring Boot 4 + Spring AI 2 (MCP Server)**.

Tudo roda localmente num cluster **kind**. Um comando sobe o ambiente e outro faz a pergunta ao agente.

```
make up     # cluster + kagent + MCP Server + apps de demo + agente + testes
make ask    # "Há algum Pod com problema no namespace shop?"
```

## O que você vai ver

O namespace `shop` tem um `checkout-api` **quebrado de propósito**: falta uma variável no ConfigMap
e o Pod entra em `CrashLoopBackOff`. Ao perguntar ao agente, ele:

1. lista os Pods e lê eventos e logs com as tools nativas do kagent (`k8s_get_resources`, `k8s_get_pod_logs`...);
2. identifica o serviço pelo label e consulta **o nosso MCP Server em Spring Boot**: quem é o dono, quem está de
   on-call, qual é o runbook para `CrashLoopBackOff` e se há congelamento de mudanças hoje;
3. devolve um relatório de triagem com evidências, causa provável, quem acionar e os comandos de correção.

O agente **só tem tools de leitura**. A correção é aplicada por um humano (`make fix-demo`).

## Arquitetura

```
                      ┌────────────────────────── cluster kind ──────────────────────────┐
                      │                                                                  │
  make ask --A2A-->   │  namespace kagent                                                │
  (curl ou CLI)       │  ┌───────────────────┐   ModelConfig --> OpenAI / Anthropic      │
                      │  │ Agent             │                                           │
  make ui ----------> │  │ sre-triage-agent  │── RemoteMCPServer kagent-tool-server ──┐  │
                      │  └───────────────────┘        (tools nativas de K8s)           │ │
                      │            │                                                   │ │
                      │            │ RemoteMCPServer service-catalog-mcp      API do Kubernetes
                      │            │ (Streamable HTTP, POST /mcp)               (Pods, logs, eventos)
                      │            │                                                      │
                      │  namespace catalog                       namespace shop           │
                      │  ┌──────────────────────────┐           ┌──────────────────────┐  │
                      │  │ service-catalog (x2)     │           │ checkout-api  ✖ crash│  │
                      │  │ Spring Boot 4.1          │           │ cart-api      ✔      │  │
                      │  │ Spring AI 2.0 · @McpTool │           └──────────────────────┘  │
                      │  │ MCP STATELESS            │                                     │
                      │  └──────────────────────────┘                                     │
                      └───────────────────────────────────────────────────────────────────┘
```

| Recurso | Arquivo | Papel |
|---|---|---|
| `Deployment/Service service-catalog` | `k8s/catalog/service-catalog.yaml` | MCP Server em Spring Boot, 2 réplicas |
| `RemoteMCPServer service-catalog-mcp` | `k8s/kagent/remote-mcp-server.yaml` | Registra o MCP Server no kagent; o kagent descobre as tools via `tools/list` |
| `ModelConfig lab-model-config` | gerado em `scripts/04-deploy.sh` | Provedor/modelo do LLM + Secret com a chave |
| `Agent sre-triage-agent` | `k8s/kagent/agent.yaml` | Prompt de sistema + lista de tools permitidas |
| Apps `checkout-api` e `cart-api` | `k8s/demo-shop/shop.yaml` | Cenário de incidente |

## Pré-requisitos

| Ferramenta | Versão testada/sugerida | Instalação |
|---|---|---|
| Docker (Desktop, Engine, OrbStack, Colima...) | 24+ com **8 GiB de RAM** para o Docker | https://docs.docker.com/get-docker/ |
| kind | 0.27+ | https://kind.sigs.k8s.io/docs/user/quick-start/#installation |
| kubectl | 1.30+ | https://kubernetes.io/docs/tasks/tools/ |
| Helm | 3.14+ (suporte a charts OCI) | https://helm.sh/docs/intro/install/ |
| make, curl | qualquer | já vêm no macOS/Linux |
| jq | opcional (recomendado) | `brew install jq` / `apt install jq` |
| kagent CLI | opcional | `brew install kagent` |
| JDK 21 + Maven | opcional, só para rodar os testes Java fora do Docker | |

Você também precisa de uma **chave de API** da OpenAI **ou** da Anthropic.

> **Windows:** use o WSL2 (Ubuntu) com o Docker Desktop integrado ao WSL. Os scripts são Bash.

## Passo a passo

### 1. Clonar e configurar

```bash
git clone https://github.com/robsonago/kagent-spring-mcp-lab.git
cd kagent-spring-mcp-lab
cp .env.example .env
# edite o .env: LLM_PROVIDER=openai e OPENAI_API_KEY=sk-...
#            ou LLM_PROVIDER=anthropic e ANTHROPIC_API_KEY=sk-ant-...
```

O `.env` está no `.gitignore`. Também dá para exportar as variáveis no shell em vez de usar o arquivo.

### 2. Subir tudo

```bash
make up
```

Isso executa, em ordem (cada etapa também pode ser rodada sozinha):

| Alvo | Script | O que faz |
|---|---|---|
| `make check` | `00-check-prereqs.sh` | Verifica ferramentas, Docker e a chave do LLM |
| `make cluster` | `01-create-cluster.sh` | Cria o cluster kind `kagent-lab` |
| `make kagent` | `02-install-kagent.sh` | Instala `kagent-crds` e `kagent` via Helm (OCI, versão fixada) |
| `make build` | `03-build-and-load.sh` | Build multi-stage da imagem Spring Boot + `kind load` (sem registry) |
| `make deploy` | `04-deploy.sh` | MCP Server, apps de demo, Secret, ModelConfig, RemoteMCPServer e Agent |
| `make test` | `05-test.sh` | Chama `/mcp` direto e confere se o kagent descobriu as tools |

Na primeira vez leva de 5 a 10 minutos (download de imagens e build do Maven).

### 3. Conversar com o agente

```bash
make ask
make ask Q="Quem é o dono do cart-api e qual o canal de on-call?"
make ask Q="Posso fazer deploy do checkout-api hoje?"
```

Ou pela interface web:

```bash
make ui     # abra http://localhost:8080 e escolha o agente sre-triage-agent
```

### 4. Corrigir e repetir

```bash
make fix-demo     # aplica o runbook: adiciona PAYMENT_GATEWAY_URL e reinicia
make ask          # o agente agora deve reportar que está tudo saudável
make break-demo   # quebra de novo, para repetir a demonstração
```

### 5. Limpar

```bash
make down
```

## Testando o MCP Server sem o kagent

O MCP Server é uma API HTTP comum (JSON-RPC 2.0). Com o port-forward ativo:

```bash
kubectl -n catalog port-forward svc/service-catalog 18080:8080
```

```bash
curl -s -X POST http://localhost:18080/mcp \
  -H "Content-Type: application/json" \
  -H "Accept: application/json, text/event-stream" \
  -d '{"jsonrpc":"2.0","id":1,"method":"tools/list","params":{}}' | jq

curl -s -X POST http://localhost:18080/mcp \
  -H "Content-Type: application/json" \
  -H "Accept: application/json, text/event-stream" \
  -d '{"jsonrpc":"2.0","id":2,"method":"tools/call","params":{"name":"get_runbook","arguments":{"service":"checkout-api","symptom":"CrashLoopBackOff"}}}' | jq
```

O header `Accept` precisa conter os dois tipos; sem isso o servidor responde `400`.
Também funciona com o [MCP Inspector](https://github.com/modelcontextprotocol/inspector)
(`npx @modelcontextprotocol/inspector`, transporte *Streamable HTTP*, URL `http://localhost:18080/mcp`).

Para rodar a aplicação fora do cluster: `cd service-catalog && mvn spring-boot:run`.

## Estrutura do repositório

```
.
├── Makefile                      # ponto de entrada (make help)
├── .env.example                  # provedor, chave e versões
├── kind/kind-config.yaml
├── scripts/                      # automação idempotente, um script por etapa
├── k8s/
│   ├── catalog/                  # MCP Server (Deployment + Service)
│   ├── demo-shop/                # apps do cenário de incidente
│   └── kagent/                   # helm-values, RemoteMCPServer, Agent
├── service-catalog/              # Spring Boot 4.1 + Spring AI 2.0
│   ├── Dockerfile
│   └── src/main/java/dev/kagentlab/catalog/
│       ├── mcp/CatalogTools.java       # @McpTool: adaptador MCP
│       ├── service/CatalogService.java # regras de negócio (não conhece MCP)
│       └── domain/                     # records de configuração e de resposta
└── .github/workflows/ci.yml      # build + testes + MCP no kind (sem LLM)
```

## Decisões de arquitetura

- **MCP em modo `STATELESS`.** Sem sessão em memória, qualquer réplica atende qualquer chamada. Por isso o
  Deployment tem 2 réplicas atrás de um Service comum, sem sticky session. As tools não precisam de
  recursos bidirecionais do MCP (sampling, elicitation), então o modo stateless basta.
- **Adaptador fino.** `CatalogTools` só traduz MCP para chamadas ao `CatalogService`. A regra de negócio
  pode ser reutilizada por REST, mensageria ou testes sem depender do protocolo.
- **Descrições das tools tratadas como contrato.** O LLM decide qual tool chamar pela descrição. Escreva-as
  como documentação de API: o que faz, quando usar e um exemplo de parâmetro.
- **Princípio do menor privilégio.** O `Agent` declara explicitamente quais tools pode usar (`toolNames`),
  todas de leitura, e as tools do catálogo carregam `readOnlyHint = true`. Para tools que alteram o
  cluster, use `requireApproval` no Agent (human-in-the-loop).
- **Erros úteis para o LLM.** Serviço desconhecido gera um erro que lista os serviços válidos, e o agente
  consegue se corrigir sozinho na chamada seguinte.
- **Versões fixadas.** kagent `0.10.6`, Spring Boot `4.1.2`, Spring AI `2.0.2`, Java 21.

## Solução de problemas

| Sintoma | O que verificar |
|---|---|
| Pods `Pending` no namespace `kagent` | Pouca memória no Docker. Aumente para 8 GiB. |
| `RemoteMCPServer` sem `ACCEPTED=True` | `kubectl -n kagent describe remotemcpserver service-catalog-mcp` e `make logs`. O service-catalog precisa estar Ready. |
| Agente não fica `Ready` | `kubectl -n kagent describe agent sre-triage-agent` e `kubectl -n kagent logs deploy/sre-triage-agent` |
| Erro 401/403 na resposta do agente | Chave do LLM inválida, ou o modelo não está disponível na sua conta. Ajuste `LLM_MODEL` no `.env` e rode `make deploy`. |
| `ErrImageNeverPull`/`ImagePullBackOff` no service-catalog | Rode `make build` de novo; a imagem precisa ser carregada no kind. |
| Mudou o código Java | `make redeploy-app` |
| Mudou o prompt ou as tools do agente | Edite `k8s/kagent/agent.yaml` e rode `kubectl apply -f k8s/kagent/agent.yaml` |

## Próximos passos

- Autenticação no MCP Server (OAuth2 Resource Server do Spring Security) e `headersFrom` no `RemoteMCPServer`.
- Tools de escrita (ex.: `restart_deployment`) protegidas com `requireApproval`.
- Trocar o `application.yml` por uma fonte real (Backstage, CMDB, banco de dados).
- Observabilidade: Micrometer + OpenTelemetry no MCP Server e tracing do kagent.
- Upgrade para o kagent 1.x quando sair do alpha (o modelo de recursos muda: `AgentTemplate` + `Harness`).

## Referências

- kagent: https://kagent.dev · https://github.com/kagent-dev/kagent
- Spring AI MCP Server: https://docs.spring.io/spring-ai/reference/api/mcp/mcp-server-boot-starter-docs.html
- MCP: https://modelcontextprotocol.io

## Licença

MIT
