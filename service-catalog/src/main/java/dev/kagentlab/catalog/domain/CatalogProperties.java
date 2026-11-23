package dev.kagentlab.catalog.domain;

import java.util.List;

import org.springframework.boot.context.properties.ConfigurationProperties;

/**
 * Dados do catálogo carregados do application.yml (prefixo "catalog").
 * Num cenário real viria de um CMDB, Backstage, banco de dados etc.
 */
@ConfigurationProperties(prefix = "catalog")
public record CatalogProperties(List<ServiceEntry> services, List<ChangeFreeze> freezes) {

    public CatalogProperties {
        services = services == null ? List.of() : List.copyOf(services);
        freezes = freezes == null ? List.of() : List.copyOf(freezes);
    }

    public record ServiceEntry(
            String name,
            String namespace,
            String tier,
            String description,
            Owner owner,
            List<Runbook> runbooks) {

        public ServiceEntry {
            runbooks = runbooks == null ? List.of() : List.copyOf(runbooks);
        }
    }

    public record Owner(String team, String onCall, String slackChannel, String escalation) {
    }

    public record Runbook(String symptom, List<String> steps) {

        public Runbook {
            steps = steps == null ? List.of() : List.copyOf(steps);
        }
    }

    /** Janela de congelamento, datas no formato ISO (yyyy-MM-dd), inclusivas. */
    public record ChangeFreeze(String name, String start, String end, String reason) {
    }
}
