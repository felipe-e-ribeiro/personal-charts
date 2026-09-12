# platform-chart

Chart Helm compartilhado para os apps pessoais rodando no cluster OKE
pessoal. Inspirado na ideia geral do padrão usado no trabalho (chart comum
publicado num registry OCI, consumido por cada app via dependência no
`Chart.yaml`) — sem copiar nenhum código, adaptado do zero para uso pessoal
com escopo bem mais enxuto.

Cobre dois formatos de app: **API HTTP** e **frontend estático/SPA**, com
**CronJob** e **Postgres self-hosted** como componentes opcionais. Veja o
design completo em
[`personal-chard/docs/superpowers/specs/2026-09-12-personal-platform-chart-design.md`](../personal-chard/docs/superpowers/specs/2026-09-12-personal-platform-chart-design.md).

## Como um app consome este chart

```yaml
# Chart.yaml do app
apiVersion: v2
name: minha-api
version: 0.1.0
dependencies:
  - name: platform-chart
    version: "^0.1.0"
    repository: "oci://ghcr.io/<usuario>/charts"
```

```yaml
# values.yaml do app -- config aninhada sob "platform-chart:"
platform-chart:
  api:
    image:
      repository: ghcr.io/<usuario>/minha-api
      tag: "sha-abc123"
  ingress:
    enabled: true
    host: minha-api.seudominio.dev
```

Depois: `helm dependency build && helm template .` no repo do app (veja
`values.yaml` deste chart para o schema completo de cada seção).

## Componentes e flags

| Componente | Flag | Gera |
|---|---|---|
| API HTTP | `api.enabled` (default `true`) | Deployment + Service |
| Frontend estático | `frontend.enabled` (default `false`) | Deployment + Service |
| Ingress | `ingress.enabled` (default `false`) | Ingress roteando `/` pro frontend e `ingress.apiPath` pra API, quando ambos coexistem |
| Autoscaling da API | `api.autoscaling.enabled` (default `false`) | HorizontalPodAutoscaler |
| Job periódico | `cronjob.enabled` (default `false`) | CronJob (um único, comando livre via `cronjob.command`) |
| Postgres self-hosted | `postgres.enabled` (default `false`) | StatefulSet + Service headless |
| Secret gerenciado pelo chart | `secrets.create` (default `false`) | Secret a partir de `secrets.data` (mapa livre) |
| Observabilidade (Prometheus Operator) | `monitoring.enabled` (default `false`) | ServiceMonitor (+ PrometheusRule se `monitoring.prometheusRule.enabled`) |

Deliberadamente fora do chart por ora: `nodeSelector`/`tolerations`/
`affinity`, múltiplos CronJobs por release, `PodDisruptionBudget`,
`NetworkPolicy`, automação de secrets (Sealed Secrets/External Secrets).

## Validar localmente (sem cluster)

```bash
helm lint .
helm template test . -f ci/test-values/full-example.yaml
```

A CI (`.github/workflows/release.yaml`) roda o mesmo lint/template como
sanity check antes de publicar uma nova versão no GHCR, em toda tag
`vX.Y.Z`.
