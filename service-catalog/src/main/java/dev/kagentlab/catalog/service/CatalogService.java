package dev.kagentlab.catalog.service;

import java.time.Clock;
import java.time.LocalDate;
import java.util.List;
import java.util.Locale;
import java.util.Optional;

import dev.kagentlab.catalog.domain.CatalogProperties;
import dev.kagentlab.catalog.domain.CatalogProperties.ChangeFreeze;
import dev.kagentlab.catalog.domain.CatalogProperties.Runbook;
import dev.kagentlab.catalog.domain.CatalogProperties.ServiceEntry;
import dev.kagentlab.catalog.domain.Views.FreezeStatus;
import dev.kagentlab.catalog.domain.Views.OwnerInfo;
import dev.kagentlab.catalog.domain.Views.RunbookResult;
import dev.kagentlab.catalog.domain.Views.ServiceSummary;

import org.springframework.stereotype.Service;

/**
 * Regras de negócio do catálogo. Não conhece MCP: pode ser reutilizada por
 * um controller REST, um job, testes etc.
 */
@Service
public class CatalogService {

    private final CatalogProperties catalog;
    private final Clock clock;

    public CatalogService(CatalogProperties catalog, Clock clock) {
        this.catalog = catalog;
        this.clock = clock;
    }

    public List<ServiceSummary> listServices(String team) {
        return catalog.services().stream()
                .filter(s -> isBlank(team) || s.owner().team().equalsIgnoreCase(team.trim()))
                .map(s -> new ServiceSummary(s.name(), s.namespace(), s.owner().team(), s.tier(), s.description()))
                .toList();
    }

    public OwnerInfo getOwner(String serviceName) {
        ServiceEntry s = require(serviceName);
        return new OwnerInfo(s.name(), s.owner().team(), s.owner().onCall(),
                s.owner().slackChannel(), s.owner().escalation());
    }

    public RunbookResult getRunbook(String serviceName, String symptom) {
        ServiceEntry s = require(serviceName);
        if (isBlank(symptom)) {
            return new RunbookResult(s.name(), null, false, s.runbooks());
        }
        String needle = symptom.trim().toLowerCase(Locale.ROOT);
        List<Runbook> matches = s.runbooks().stream()
                .filter(r -> r.symptom().toLowerCase(Locale.ROOT).contains(needle)
                        || needle.contains(r.symptom().toLowerCase(Locale.ROOT)))
                .toList();
        // Sem correspondência exata, devolve todos: o LLM escolhe o mais próximo.
        return matches.isEmpty()
                ? new RunbookResult(s.name(), symptom, false, s.runbooks())
                : new RunbookResult(s.name(), symptom, true, matches);
    }

    public FreezeStatus checkChangeFreeze(String serviceName) {
        ServiceEntry s = require(serviceName);
        LocalDate today = LocalDate.now(clock);
        Optional<ChangeFreeze> active = catalog.freezes().stream()
                .filter(f -> !today.isBefore(LocalDate.parse(f.start())) && !today.isAfter(LocalDate.parse(f.end())))
                .findFirst();

        // Serviços tier-1 seguem a janela de congelamento; os demais apenas recebem um alerta.
        boolean critical = "tier-1".equalsIgnoreCase(s.tier());
        boolean allowed = active.isEmpty() || !critical;
        String recommendation = active.isEmpty()
                ? "Sem congelamento ativo. Siga o processo normal de mudança."
                : critical
                    ? "Congelamento ativo para serviço tier-1: apenas hotfix aprovado pelo on-call (" + s.owner().onCall() + ")."
                    : "Congelamento ativo, mas o serviço não é tier-1: deploy permitido com aviso no canal " + s.owner().slackChannel() + ".";

        return new FreezeStatus(s.name(), s.tier(), today.toString(), allowed,
                active.map(ChangeFreeze::name).orElse(null),
                active.map(ChangeFreeze::reason).orElse(null),
                recommendation);
    }

    private ServiceEntry require(String serviceName) {
        if (isBlank(serviceName)) {
            throw new IllegalArgumentException("Informe o nome do serviço. Conhecidos: " + knownNames());
        }
        String wanted = serviceName.trim();
        return catalog.services().stream()
                .filter(s -> s.name().equalsIgnoreCase(wanted))
                .findFirst()
                .orElseThrow(() -> new IllegalArgumentException(
                        "Serviço '" + wanted + "' não existe no catálogo. Conhecidos: " + knownNames()));
    }

    private List<String> knownNames() {
        return catalog.services().stream().map(ServiceEntry::name).toList();
    }

    private static boolean isBlank(String value) {
        return value == null || value.isBlank();
    }
}
