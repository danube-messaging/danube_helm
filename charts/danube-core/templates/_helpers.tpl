{{- define "danube-core.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "danube-core.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := include "danube-core.name" . -}}
{{- if contains $name .Release.Name -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{- define "danube-core.chart" -}}
{{ .Chart.Name }}-{{ .Chart.Version | replace "+" "_" }}
{{- end -}}

{{- define "danube-core.labels" -}}
helm.sh/chart: {{ include "danube-core.chart" . }}
app.kubernetes.io/name: {{ include "danube-core.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end -}}

{{- define "danube-core.selectorLabels" -}}
app.kubernetes.io/name: {{ include "danube-core.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{- define "danube-core.broker.name" -}}
{{ include "danube-core.fullname" . }}-broker
{{- end -}}

{{- define "danube-core.broker.headless" -}}
{{ include "danube-core.fullname" . }}-broker-headless
{{- end -}}

{{/*
Generate comma-separated Raft seed-node addresses from broker StatefulSet pods.
Each entry is <pod>.<headless>.<namespace>.svc.cluster.local:<raft_port>.
Used by --seed-nodes so brokers can discover each other for Raft cluster formation.
*/}}
{{- define "danube-core.broker.seedNodes" -}}
{{- $replicas := int .Values.broker.replicaCount -}}
{{- $name := include "danube-core.broker.name" . -}}
{{- $headless := include "danube-core.broker.headless" . -}}
{{- $raftPort := int .Values.broker.ports.raft -}}
{{- range $i := until $replicas -}}
{{- if $i }},{{ end -}}
{{- printf "%s-%d.%s.%s.svc.cluster.local:%d" $name $i $headless $.Release.Namespace $raftPort -}}
{{- end -}}
{{- end -}}

{{- define "danube-core.prometheus.name" -}}
{{ include "danube-core.fullname" . }}-prometheus
{{- end -}}

{{- define "danube-core.prometheus.serviceAccountName" -}}
{{- if .Values.prometheus.serviceAccount.create -}}
{{- if .Values.prometheus.serviceAccount.name -}}
{{ .Values.prometheus.serviceAccount.name }}
{{- else -}}
{{ include "danube-core.prometheus.name" . }}
{{- end -}}
{{- else -}}
{{- if .Values.prometheus.serviceAccount.name -}}
{{ .Values.prometheus.serviceAccount.name }}
{{- else -}}
default
{{- end -}}
{{- end -}}
{{- end -}}

{{- define "danube-core.prometheus.config" -}}
{{ include "danube-core.fullname" . }}-prometheus-config
{{- end -}}
