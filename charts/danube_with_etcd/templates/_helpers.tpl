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
{{- $brokerName = "etcd" -}}  # Fallback if etcd.name is not set
{{- end -}}
{{- printf "%s-%s" $releaseName $etcdName | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "broker.chart" -}}
{{- .Chart.Name }}-{{ .Chart.Version | replace "+" "_" }}
{{- end -}}