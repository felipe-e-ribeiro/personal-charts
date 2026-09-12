{{/*
Nome base do app. Quando usado como dependência (subchart), .Chart.Name
sempre seria "platform-chart" independente de qual app está consumindo --
por isso usamos .Release.Name (o nome do app) como base, não .Chart.Name.
*/}}
{{- define "platform-chart.name" -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "platform-chart.fullname" -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Labels comuns e labels de seleção (usados tanto em metadata quanto em
selectors -- selectors são imutáveis, então mantemos esse subconjunto
estável entre upgrades).
*/}}
{{- define "platform-chart.labels" -}}
helm.sh/chart: {{ printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{ include "platform-chart.selectorLabels" . }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end -}}

{{- define "platform-chart.selectorLabels" -}}
app.kubernetes.io/name: {{ include "platform-chart.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{/*
Labels/selector por componente (api, frontend, cronjob, postgres). Passe um
dict com "component" + o contexto raiz (Release/Chart/Values), ex:
{{ include "platform-chart.componentLabels" (dict "component" "api" "Release" .Release "Chart" .Chart "Values" .Values) }}
*/}}
{{- define "platform-chart.componentLabels" -}}
{{ include "platform-chart.labels" . }}
app.kubernetes.io/component: {{ .component }}
{{- end -}}

{{- define "platform-chart.componentSelectorLabels" -}}
{{ include "platform-chart.selectorLabels" . }}
app.kubernetes.io/component: {{ .component }}
{{- end -}}

{{/*
Nome do Secret com as credenciais/tokens da aplicação -- ou o
existingSecret informado, ou o gerado pelo chart.
*/}}
{{- define "platform-chart.secretName" -}}
{{- if .Values.secrets.existingSecret -}}
{{- .Values.secrets.existingSecret -}}
{{- else -}}
{{- printf "%s-secrets" (include "platform-chart.fullname" .) -}}
{{- end -}}
{{- end -}}

{{/*
DATABASE_URL efetiva: usa secrets.databaseUrl se informado, senão monta a
partir do Postgres self-hosted do próprio chart.
*/}}
{{- define "platform-chart.databaseUrl" -}}
{{- if .Values.secrets.databaseUrl -}}
{{- .Values.secrets.databaseUrl -}}
{{- else -}}
{{- printf "%s://%s:%s@%s-postgres:5432/%s" .Values.postgres.urlScheme .Values.postgres.username .Values.secrets.postgresPassword (include "platform-chart.fullname" .) .Values.postgres.database -}}
{{- end -}}
{{- end -}}

{{/*
"true" se o chart consegue de fato montar uma DATABASE_URL (databaseUrl
explícita, ou postgres self-hosted com senha conhecida). Evita que o chart
injete uma DATABASE_URL com senha vazia sobrescrevendo (via precedência de
`env` sobre `envFrom`) uma DATABASE_URL real vinda de secrets.existingSecret
-- ver nota em values.yaml sobre o fluxo de produção via ArgoCD.
*/}}
{{- define "platform-chart.hasResolvedDatabaseUrl" -}}
{{- if or .Values.secrets.databaseUrl (and .Values.postgres.enabled .Values.secrets.postgresPassword) -}}
true
{{- end -}}
{{- end -}}

{{/*
Base URL pública do app, derivada de ingress.host (com https quando TLS
está ligado). Só faz sentido se ingress.enabled.
*/}}
{{- define "platform-chart.publicUrl" -}}
{{- printf "%s://%s" (ternary "https" "http" .Values.ingress.tls.enabled) .Values.ingress.host -}}
{{- end -}}

{{/*
Repositório de imagem completo (prefixa image.registry se definido). Espera
um dict com "repository", "tag" e "Values" (o `include`/`ExecuteTemplate`
do Helm reseta "$" pro dado passado, então precisamos do Values explícito
no dict em vez de usar "$.Values").
*/}}
{{- define "platform-chart.image" -}}
{{- if .Values.image.registry -}}
{{- printf "%s/%s:%s" .Values.image.registry .repository .tag -}}
{{- else -}}
{{- printf "%s:%s" .repository .tag -}}
{{- end -}}
{{- end -}}
