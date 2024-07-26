{{- define "etcd.fullname" -}}
{{- printf "%s-etcd" .Release.Name -}}
{{- end -}}

{{- define "broker.fullname" -}}
{{- printf "%s-broker" .Release.Name -}}
{{- end -}}