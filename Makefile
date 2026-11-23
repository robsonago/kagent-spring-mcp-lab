SHELL := /usr/bin/env bash
.DEFAULT_GOAL := help

Q ?= Há algum Pod com problema no namespace shop? Faça a triagem completa e diga quem devo acionar.

.PHONY: help
help: ## Mostra os comandos disponíveis
	@grep -E '^[a-zA-Z_-]+:.*?## ' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-12s\033[0m %s\n", $$1, $$2}'

.PHONY: up
up: check cluster kagent build deploy test ## Sobe tudo do zero (cluster, kagent, app, agente) e testa

.PHONY: check
check: ## Verifica pré-requisitos e a chave do LLM
	@scripts/00-check-prereqs.sh

.PHONY: cluster
cluster: ## Cria o cluster kind
	@scripts/01-create-cluster.sh

.PHONY: kagent
kagent: ## Instala o kagent via Helm
	@scripts/02-install-kagent.sh

.PHONY: build
build: ## Constrói a imagem do MCP Server e carrega no kind
	@scripts/03-build-and-load.sh

.PHONY: deploy
deploy: ## Aplica MCP Server, apps de demo, ModelConfig, RemoteMCPServer e Agent
	@scripts/04-deploy.sh

.PHONY: test
test: ## Testes de fumaça (MCP direto + registro no kagent)
	@scripts/05-test.sh

.PHONY: ask
ask: ## Pergunta ao agente. Ex.: make ask Q="quem é o dono do cart-api?"
	@scripts/06-ask.sh "$(Q)"

.PHONY: fix-demo
fix-demo: ## Corrige o checkout-api (aplica o runbook)
	@scripts/07-fix-demo.sh

.PHONY: break-demo
break-demo: ## Quebra o checkout-api de novo
	@scripts/08-break-demo.sh

.PHONY: ui
ui: ## Abre a UI do kagent em http://localhost:8080
	@echo "UI em http://localhost:8080 (Ctrl+C para sair)"
	@kubectl -n kagent port-forward svc/kagent-ui 8080:8080

.PHONY: logs
logs: ## Logs do MCP Server
	@kubectl -n catalog logs -l app.kubernetes.io/name=service-catalog --tail=100 -f

.PHONY: redeploy-app
redeploy-app: build ## Reconstrói a imagem e reinicia o MCP Server
	@kubectl -n catalog rollout restart deployment/service-catalog
	@kubectl -n catalog rollout status deployment/service-catalog

.PHONY: unit-test
unit-test: ## Roda os testes Java localmente (requer JDK 21 e Maven)
	@cd service-catalog && mvn -B verify

.PHONY: down
down: ## Remove o cluster
	@scripts/99-destroy.sh
