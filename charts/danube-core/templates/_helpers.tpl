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

{{- define "danube-core.broker.config" -}}
{{ include "danube-core.fullname" . }}-broker-config
{{- end -}}

{{- define "danube-core.etcd.name" -}}
{{ include "danube-core.fullname" . }}-etcd
{{- end -}}

{{- define "danube-core.etcd.headless" -}}
{{ include "danube-core.fullname" . }}-etcd-headless
{{- end -}}

{{- define "danube-core.etcd.address" -}}
{{ include "danube-core.etcd.name" . }}:{{ .Values.etcd.service.port }}
{{- end -}}

{{- define "danube-core.etcd.initialCluster" -}}
{{- $replicas := int .Values.etcd.replicaCount -}}
{{- $domain := .Values.etcd.cluster.domain -}}
{{- $name := include "danube-core.etcd.name" . -}}
{{- $headless := include "danube-core.etcd.headless" . -}}
{{- $peerPort := .Values.etcd.service.peerPort -}}
{{- range $i := until $replicas -}}
{{- if $i }},{{ end -}}
{{- printf "%s-%d=http://%s-%d.%s.%s.svc.%s:%d" $name $i $name $i $headless $.Release.Namespace $domain $peerPort -}}
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
