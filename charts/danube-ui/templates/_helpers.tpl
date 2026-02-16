{{- define "danube-ui.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "danube-ui.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := include "danube-ui.name" . -}}
{{- if contains $name .Release.Name -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{- define "danube-ui.chart" -}}
{{ .Chart.Name }}-{{ .Chart.Version | replace "+" "_" }}
{{- end -}}

{{- define "danube-ui.labels" -}}
helm.sh/chart: {{ include "danube-ui.chart" . }}
app.kubernetes.io/name: {{ include "danube-ui.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end -}}

{{- define "danube-ui.selectorLabels" -}}
app.kubernetes.io/name: {{ include "danube-ui.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{/* Admin server component name */}}
{{- define "danube-ui.admin.name" -}}
{{ include "danube-ui.fullname" . }}-admin
{{- end -}}

{{/* Web UI component name */}}
{{- define "danube-ui.frontend.name" -}}
{{ include "danube-ui.fullname" . }}-frontend
{{- end -}}

{{/* CORS origin: use explicit value or construct from UI service */}}
{{- define "danube-ui.corsOrigin" -}}
{{- if .Values.admin.config.corsAllowOrigin -}}
{{- .Values.admin.config.corsAllowOrigin -}}
{{- else -}}
http://{{ include "danube-ui.frontend.name" . }}:{{ .Values.ui.service.port }}
{{- end -}}
{{- end -}}
