package dev.kagentlab.catalog;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import java.time.Clock;
import java.time.Instant;
import java.time.ZoneOffset;
import java.util.List;

import dev.kagentlab.catalog.domain.CatalogProperties;
import dev.kagentlab.catalog.domain.CatalogProperties.ChangeFreeze;
import dev.kagentlab.catalog.domain.CatalogProperties.Owner;
import dev.kagentlab.catalog.domain.CatalogProperties.Runbook;
import dev.kagentlab.catalog.domain.CatalogProperties.ServiceEntry;
import dev.kagentlab.catalog.service.CatalogService;

import org.junit.jupiter.api.Test;

class CatalogServiceTest {

    private static final CatalogProperties CATALOG = new CatalogProperties(
            List.of(
                    new ServiceEntry("checkout-api", "shop", "tier-1", "Checkout",
                            new Owner("payments", "Ana", "#payments-oncall", "Ana -> TL"),
                            List.of(new Runbook("CrashLoopBackOff", List.of("ver logs")),
                                    new Runbook("latência alta", List.of("ver dashboard")))),
                    new ServiceEntry("cart-api", "shop", "tier-2", "Cart",
                            new Owner("storefront", "Bruno", "#storefront", "Bruno -> TL"),
                            List.of())),
            List.of(new ChangeFreeze("black-friday", "2026-11-26", "2026-11-30", "Pico de vendas")));

    private static CatalogService serviceAt(String isoInstant) {
        return new CatalogService(CATALOG, Clock.fixed(Instant.parse(isoInstant), ZoneOffset.UTC));
    }

    @Test
    void filtraServicosPorTime() {
        assertThat(serviceAt("2026-11-20T12:00:00Z").listServices("payments"))
                .singleElement()
                .satisfies(s -> assertThat(s.name()).isEqualTo("checkout-api"));
    }

    @Test
    void encontraRunbookPeloSintomaIgnorandoCaixa() {
        var result = serviceAt("2026-11-20T12:00:00Z").getRunbook("CHECKOUT-API", "crashloopbackoff");
        assertThat(result.exactMatch()).isTrue();
        assertThat(result.runbooks()).singleElement()
                .satisfies(r -> assertThat(r.symptom()).isEqualTo("CrashLoopBackOff"));
    }

    @Test
    void devolveTodosOsRunbooksQuandoSintomaNaoBate() {
        var result = serviceAt("2026-11-20T12:00:00Z").getRunbook("checkout-api", "disco cheio");
        assertThat(result.exactMatch()).isFalse();
        assertThat(result.runbooks()).hasSize(2);
    }

    @Test
    void bloqueiaDeployTier1DuranteCongelamento() {
        var status = serviceAt("2026-11-27T12:00:00Z").checkChangeFreeze("checkout-api");
        assertThat(status.deployAllowed()).isFalse();
        assertThat(status.activeFreeze()).isEqualTo("black-friday");
    }

    @Test
    void permiteDeployNaoCriticoDuranteCongelamento() {
        var status = serviceAt("2026-11-27T12:00:00Z").checkChangeFreeze("cart-api");
        assertThat(status.deployAllowed()).isTrue();
    }

    @Test
    void permiteDeployForaDoCongelamento() {
        var status = serviceAt("2026-11-20T12:00:00Z").checkChangeFreeze("checkout-api");
        assertThat(status.deployAllowed()).isTrue();
        assertThat(status.activeFreeze()).isNull();
    }

    @Test
    void erroDeServicoDesconhecidoListaOsConhecidos() {
        assertThatThrownBy(() -> serviceAt("2026-11-20T12:00:00Z").getOwner("payment-api"))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessageContaining("checkout-api")
                .hasMessageContaining("cart-api");
    }
}
