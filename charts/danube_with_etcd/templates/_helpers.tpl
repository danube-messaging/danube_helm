{{- define "broker.name" -}}
{{- $releaseName := .Release.Name -}}
{{- $brokerName := .Values.broker.name -}}
{{- if not $brokerName -}}
{{- $brokerName = "danube-broker" -}}  # Fallback if broker.name is not set
{{- end -}}
{{- printf "%s-%s" $releaseName $brokerName | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "etcd.name" -}}
{{- $releaseName := .Release.Name -}}
{{- $etcdName := .Values.etcd.name -}}
{{- if not $etcdName -}}
{{- $etcdName = "etcd" -}}  # Fallback if etcd.name is not set
{{- end -}}
{{- printf "%s-%s" $releaseName $etcdName | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "etcd.addr" -}}
{{- $etcdName := include "etcd.name" . -}}
{{- $etcdPort := .Values.etcd.service.port | default "2379" -}}
{{ $etcdName }}:{{ $etcdPort }}
{{- end -}}

{{- define "broker.chart" -}}
{{- .Chart.Name }}-{{ .Chart.Version | replace "+" "_" }}
{{- end -}}